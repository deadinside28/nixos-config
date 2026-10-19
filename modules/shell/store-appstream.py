# Каталог «Магазина» из AppStream удалённых репозиториев Flatpak (Flathub).
# Flatpak держит их локально и обновляет сам:
#   /var/lib/flatpak/appstream/<remote>/x86_64/active/appstream.xml.gz
#   …/active/icons/128x128/<id>.png
# Здесь они сводятся в JSON для оболочки: название, описание и т. п. —
# по-русски, если перевод есть, иначе как в источнике.
#   python3 store-appstream.py ВЫХОД.json КАТАЛОГ_APPSTREAM…
# ВЫХОД.json — лёгкий индекс для витрины и поиска (без описаний и
# скриншотов): его оболочка держит в памяти целиком. Подробности каждого
# приложения — ВЫХОД.json.d/<id>.json, читаются при открытии его страницы.
# КАТАЛОГ — …/appstream/<remote>/<arch>/active; remote берётся из пути.
import gzip
import json
import os
import sys
import xml.etree.ElementTree as ET

LANGS = ("ru_RU", "ru")
XML_LANG = "{http://www.w3.org/XML/1998/namespace}lang"
APP_TYPES = {"desktop-application", "desktop", "console-application"}


def localized(parent, tag):
    """Текст тега на русском, если есть, иначе без языка."""
    best, plain = None, None
    for el in parent.findall(tag):
        lang = el.get(XML_LANG)
        if lang in LANGS and best is None:
            best = el
        elif lang is None and plain is None:
            plain = el
    return best if best is not None else plain


def text(el):
    return " ".join("".join(el.itertext()).split()) if el is not None else ""


def description(comp):
    """<description> в простой текст: абзацы и пункты списков «• …».

    Перевод во Flathub приходит двумя способами: отдельным
    <description xml:lang="ru"> или xml:lang у каждого <p>/<li> внутри
    одного <description>. Во втором случае берутся только русские
    абзацы и пункты, если они есть, иначе исходные."""
    root = localized(comp, "description")
    if root is None:
        return ""
    ru_inside = root.get(XML_LANG) is None and any(el.get(XML_LANG) in LANGS for el in root.iter())

    def wanted(el):
        lang = el.get(XML_LANG)
        return lang in LANGS if ru_inside else lang is None or lang in LANGS

    out = []
    for el in root:
        if el.tag == "p" and wanted(el):
            out.append(text(el))
        elif el.tag in ("ul", "ol"):
            items = el.findall("li")
            ru_items = [li for li in items if li.get(XML_LANG) in LANGS]
            pick = ru_items if ru_inside and ru_items else [li for li in items if li.get(XML_LANG) is None]
            if pick:
                out.append("\n".join("• " + text(li) for li in pick))
    return "\n\n".join(p for p in out if p)


def icon(comp, base):
    """Локальный значок (cached) самого крупного размера, иначе remote."""
    best, best_size, remote = "", 0, ""
    for el in comp.findall("icon"):
        kind = el.get("type")
        if kind == "cached":
            size = int(el.get("width") or el.get("height") or 64)
            path = os.path.join(os.path.abspath(base), "icons", f"{size}x{size}", text(el))
            if size > best_size and os.path.exists(path):
                best, best_size = path, size
        elif kind == "remote" and not remote:
            remote = text(el)
    return best or remote


def screenshots(comp):
    out = []
    for shot in comp.findall("screenshots/screenshot"):
        full, thumb, tw = "", "", 0
        for img in shot.findall("image"):
            if img.get("type") == "source":
                full = text(img)
            elif img.get("type") == "thumbnail":
                w = int(img.get("width") or 0)
                # самая подходящая миниатюра для полосы скриншотов — ~600–800 px
                if not thumb or abs(w - 700) < abs(tw - 700):
                    thumb, tw = text(img), w
        if full or thumb:
            out.append({"full": full or thumb, "thumb": thumb or full, "caption": text(localized(shot, "caption"))})
    return out[:8]


def developer(comp):
    dev = comp.find("developer")
    if dev is not None:
        return text(localized(dev, "name"))
    return text(localized(comp, "developer_name"))


def component(comp, remote, base):
    if comp.get("type") not in APP_TYPES:
        return None
    app_id = text(comp.find("id"))
    if not app_id:
        return None
    if app_id.endswith(".desktop"):
        app_id = app_id[: -len(".desktop")]
    releases = comp.findall("releases/release")
    newest = max(releases, key=lambda r: int(r.get("timestamp") or 0), default=None)
    custom = {v.get("key"): text(v) for v in comp.findall("custom/value")}
    url = ""
    for u in comp.findall("url"):
        if u.get("type") == "homepage":
            url = text(u)
            break
    return {
        "id": app_id,
        "remote": remote,
        "name": text(localized(comp, "name")) or app_id.split(".")[-1],
        "summary": text(localized(comp, "summary")),
        "description": description(comp),
        "categories": [text(c) for c in comp.findall("categories/category")],
        "keywords": [text(k) for k in comp.findall("keywords/keyword") if k.get(XML_LANG) in (None, *LANGS)],
        "developer": developer(comp),
        "license": text(comp.find("project_license")),
        "icon": icon(comp, base),
        "screenshots": screenshots(comp),
        "version": newest.get("version", "") if newest is not None else "",
        "released": int(newest.get("timestamp") or 0) if newest is not None else 0,
        "homepage": url,
        "verified": custom.get("flathub::verification::verified") == "true",
    }


def load(base):
    for name in ("appstream.xml.gz", "appstream.xml"):
        path = os.path.join(base, name)
        if os.path.exists(path):
            opener = gzip.open if name.endswith(".gz") else open
            with opener(path, "rb") as f:
                return ET.parse(f).getroot()
    return None


def main():
    out_path, bases = sys.argv[1], sys.argv[2:]
    apps, seen = [], set()
    for base in bases:
        root = load(base)
        if root is None:
            continue
        # …/appstream/<remote>/<arch>/active
        remote = os.path.basename(os.path.dirname(os.path.dirname(os.path.normpath(base))))
        for comp in root.findall("component"):
            app = component(comp, remote, base)
            if app and app["id"] not in seen:
                seen.add(app["id"])
                apps.append(app)
    # что нужно витрине, карточкам и поиску; остальное — в подробностях
    light = ("id", "remote", "name", "summary", "developer", "categories", "keywords", "icon", "version", "released", "verified")
    details_dir = out_path + ".d"
    tmp_dir = details_dir + ".tmp"
    if os.path.isdir(tmp_dir):
        for f in os.listdir(tmp_dir):
            os.remove(os.path.join(tmp_dir, f))
    else:
        os.makedirs(tmp_dir)
    for app in apps:
        with open(os.path.join(tmp_dir, app["id"] + ".json"), "w", encoding="utf-8") as f:
            json.dump(app, f, ensure_ascii=False, separators=(",", ":"))
    tmp = out_path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        # первый скриншот — для баннера на главной
        index = [dict({k: a[k] for k in light}, shot=a["screenshots"][0]["thumb"] if a["screenshots"] else "") for a in apps]
        json.dump({"apps": index}, f, ensure_ascii=False, separators=(",", ":"))
    # сначала подробности, потом индекс: индекс не ссылается на то, чего нет
    old_dir = details_dir + ".old"
    if os.path.isdir(details_dir):
        os.replace(details_dir, old_dir)
    os.replace(tmp_dir, details_dir)
    os.replace(tmp, out_path)
    if os.path.isdir(old_dir):
        for f in os.listdir(old_dir):
            os.remove(os.path.join(old_dir, f))
        os.rmdir(old_dir)
    print(len(apps))


main()
