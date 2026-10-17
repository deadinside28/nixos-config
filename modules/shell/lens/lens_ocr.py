"""Распознавание и перевод текста на снимке экрана для «Обвести и найти».

Как у Pixel и у live-text: сначала нейросеть-детектор (PaddleOCR через
RapidOCR/ONNX) находит строки текста — она не путает значки, аватарки и
колонки, — потом каждая строка отдельно распознаётся tesseract с нужными
языками (на аккуратно вырезанной строке он точен), соседние строки
собираются в абзацы, абзацы переводятся (Google, POST, порциями) и
выводятся с цветом фона и текста оригинала.

  lens_ocr.py text <картинка> <языки tesseract>
  lens_ocr.py translate <картинка> <языки tesseract> <язык перевода>
  lens_ocr.py string <язык перевода> <текст>

translate печатает TSV: x y w h высота_строки фон цвет_текста перевод.
Абзацы, которые уже на нужном языке (перевод совпал с оригиналом), не
выводятся — поверх них нечего рисовать.
"""

import json
import os
import re
import subprocess
import sys
import tempfile
import urllib.parse
import urllib.request

import cv2
import numpy as np
from rapidocr_onnxruntime import RapidOCR

TESSDATA = os.environ.get("PIXEL_LENS_TESSDATA", "")
CACHE_DIR = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "pixel-lens")
LETTER = re.compile(r"[^\W\d_]", re.UNICODE)


def detect(img):
    """Рамки строк текста: [(x, y, w, h)]."""
    engine = RapidOCR()
    res, _ = engine(img, use_det=True, use_cls=False, use_rec=False)
    boxes = []
    for quad in res or []:
        pts = np.array(quad, dtype=np.float32)
        x, y = pts.min(axis=0)
        x2, y2 = pts.max(axis=0)
        w, h = x2 - x, y2 - y
        if w < 6 or h < 6:
            continue
        boxes.append((int(x), int(y), int(w), int(h)))
    # сверху вниз, слева направо
    boxes.sort(key=lambda b: (b[1] // 8, b[0]))
    return boxes


def prepare(img, box):
    """Вырезать строку, сделать тёмный текст на светлом и подтянуть кегль."""
    x, y, w, h = box
    pad = max(2, h // 6)
    H, W = img.shape[:2]
    crop = img[max(0, y - pad):min(H, y + h + pad), max(0, x - pad):min(W, x + w + pad)]
    gray = cv2.cvtColor(crop, cv2.COLOR_BGR2GRAY)
    # светлый текст на тёмном (тёмные темы) — перевернуть
    border = np.concatenate([gray[0], gray[-1], gray[:, 0], gray[:, -1]])
    if np.median(border) < 128:
        gray = 255 - gray
    # tesseract лучше всего читает строки высотой около 40 px
    if gray.shape[0] < 40:
        k = 40 / gray.shape[0]
        gray = cv2.resize(gray, None, fx=k, fy=k, interpolation=cv2.INTER_CUBIC)
    return gray


def recognize(img, boxes, langs):
    """Текст каждой строки — один запуск tesseract на все строки сразу."""
    if not boxes:
        return []
    with tempfile.TemporaryDirectory() as tmp:
        files = []
        for i, b in enumerate(boxes):
            f = os.path.join(tmp, f"{i:04d}.png")
            cv2.imwrite(f, prepare(img, b))
            files.append(f)
        # строки делим на несколько частей и распознаём параллельно
        n = max(1, min(4, os.cpu_count() or 1, len(files) // 8 or 1))
        parts = [files[i::n] for i in range(n)]
        procs = []
        for k, part in enumerate(parts):
            lst = os.path.join(tmp, f"list{k}.txt")
            with open(lst, "w") as fh:
                fh.write("\n".join(part) + "\n")
            cmd = ["tesseract", lst, "stdout", "-l", langs, "--psm", "7"]
            if TESSDATA:
                cmd[1:1] = ["--tessdata-dir", TESSDATA]
            env = dict(os.environ, OMP_THREAD_LIMIT="1")
            procs.append(subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, env=env))
        results = {}
        for k, pr in enumerate(procs):
            pages = pr.communicate()[0].split("\f")
            for j, f in enumerate(parts[k]):
                results[f] = pages[j] if j < len(pages) else ""
    return [results[f].strip().replace("\n", " ") for f in files]



def useful(text):
    # хотя бы две буквы — иначе это значок, цифры или время
    return len(LETTER.findall(text)) >= 2


def paragraphs(lines):
    """Склеить перенесённый текст в абзацы: следующая строка под предыдущей,
    тот же левый край и кегль, а предыдущая — длинная и почти во всю ширину
    блока (её перенесли). Короткие строки интерфейса (списки каналов, имена,
    кнопки) остаются отдельными — перевод списка одним предложением даёт кашу."""
    paras = []
    for (x, y, w, h), text in lines:
        for p in reversed(paras[-6:]):
            gap = y - (p["y"] + p["h"])
            wrapped = p["lastw"] > 18 * p["lh"] and p["lastw"] >= 0.8 * p["w"]
            if wrapped and abs(x - p["x"]) < 0.8 * h and -0.3 * h <= gap < 0.8 * h and abs(h - p["lh"]) < 0.35 * h:
                x2 = max(p["x"] + p["w"], x + w)
                p["w"] = x2 - p["x"]
                p["h"] = y + h - p["y"]
                p["text"] += " " + text
                p["lastw"] = w
                break
        else:
            paras.append({"x": x, "y": y, "w": w, "h": h, "lh": h, "lastw": w, "text": text})
    return paras


def colors(img, p):
    """Фон — медиана рамки вокруг абзаца; текст — пиксели, сильнее всего
    отличающиеся от фона."""
    H, W = img.shape[:2]
    x, y, w, h = p["x"], p["y"], p["w"], p["h"]
    x1, y1 = max(0, x - 3), max(0, y - 3)
    x2, y2 = min(W - 1, x + w + 3), min(H - 1, y + h + 3)
    ring = np.concatenate([img[y1, x1:x2], img[y2, x1:x2], img[y1:y2, x1], img[y1:y2, x2]])
    bg = np.median(ring, axis=0)
    inner = img[y:y + h, x:x + w].reshape(-1, 3).astype(np.float32)
    if len(inner) == 0:
        fg = 255 - bg
    else:
        d = np.linalg.norm(inner - bg, axis=1)
        top = inner[d >= np.percentile(d, 92)]
        fg = np.median(top, axis=0) if len(top) else 255 - bg
        # слишком близко к фону (сглаживание) — контрастный
        if np.linalg.norm(fg - bg) < 60:
            fg = np.array([20, 20, 24]) if bg.mean() > 128 else np.array([240, 240, 244])

    def hexc(c):  # BGR → RRGGBB
        return "%02x%02x%02x" % (int(c[2]), int(c[1]), int(c[0]))

    return hexc(bg), hexc(fg)


def load_cache(to):
    try:
        with open(os.path.join(CACHE_DIR, f"cache-{to}.json")) as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return {}


def save_cache(to, cache):
    os.makedirs(CACHE_DIR, exist_ok=True)
    items = list(cache.items())[-3000:]
    with open(os.path.join(CACHE_DIR, f"cache-{to}.json"), "w") as fh:
        json.dump(dict(items), fh, ensure_ascii=False)


def google(texts, to):
    """Перевести список строк одним-несколькими POST-запросами (порции до
    ~4500 символов, по строке на абзац; Google сохраняет переводы строк)."""
    out = []
    chunk, size = [], 0
    batches = []
    for t in texts:
        if chunk and size + len(t) > 4500:
            batches.append(chunk)
            chunk, size = [], 0
        chunk.append(t)
        size += len(t) + 1
    if chunk:
        batches.append(chunk)
    for batch in batches:
        q = "\n".join(batch)
        data = urllib.parse.urlencode({"q": q}).encode()
        url = "https://translate.googleapis.com/translate_a/single?" + urllib.parse.urlencode(
            {"client": "gtx", "sl": "auto", "tl": to, "dt": "t"})
        req = urllib.request.Request(url, data=data, headers={"User-Agent": "Mozilla/5.0"})
        try:
            with urllib.request.urlopen(req, timeout=15) as r:
                res = json.loads(r.read().decode())
            full = "".join(seg[0] for seg in res[0] if seg and seg[0])
            parts = full.split("\n")
        except Exception:  # нет сети — оставим оригинал
            parts = []
        if len(parts) != len(batch):
            # строки разъехались — по одной (медленнее, но надёжно)
            parts = []
            for t in batch:
                try:
                    url1 = url + "&" + urllib.parse.urlencode({"q": t})
                    with urllib.request.urlopen(urllib.request.Request(url1, headers={"User-Agent": "Mozilla/5.0"}), timeout=10) as r:
                        res = json.loads(r.read().decode())
                    parts.append("".join(seg[0] for seg in res[0] if seg and seg[0]).replace("\n", " "))
                except Exception:
                    parts.append("")
        out.extend(parts)
    return out


def translate(texts, to):
    if os.environ.get("PIXEL_LENS_FAKE"):  # проверка без сети
        return [t[::-1] for t in texts]
    cache = load_cache(to)
    miss = [t for t in dict.fromkeys(texts) if t not in cache]
    if miss:
        for src, tr in zip(miss, google(miss, to)):
            if tr.strip():
                cache[src] = tr.strip()
        save_cache(to, cache)
    return [cache.get(t, "") for t in texts]


def norm(s):
    return re.sub(r"\W+", "", s.lower())


def main():
    if sys.argv[1] == "string":
        lines = [ln for ln in sys.argv[3].split("\n")]
        print("\n".join(t or s for t, s in zip(translate(lines, sys.argv[2]), lines)))
        return
    mode, path, langs = sys.argv[1], sys.argv[2], sys.argv[3]
    img = cv2.imread(path, cv2.IMREAD_COLOR)
    if img is None:
        sys.exit(1)
    boxes = detect(img)
    texts = recognize(img, boxes, langs)
    lines = [(b, t) for b, t in zip(boxes, texts) if useful(t)]
    if mode == "text":
        print("\n".join(t for _, t in lines))
        return
    to = sys.argv[4]
    paras = paragraphs(lines)
    trs = translate([p["text"] for p in paras], to)
    for p, tr in zip(paras, trs):
        # уже на нужном языке или перевести не удалось — не рисуем
        if not tr or norm(tr) == norm(p["text"]):
            continue
        bg, fg = colors(img, p)
        print("\t".join(map(str, [p["x"], p["y"], p["w"], p["h"], p["lh"], bg, fg, tr.replace("\t", " ")])))


if __name__ == "__main__":
    main()
