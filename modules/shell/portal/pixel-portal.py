"""pixel-portal — backend xdg-desktop-portal FileChooser с диалогом оболочки.

Приложение (GTK4, Qt, Flatpak, Chrome…) просит у xdg-desktop-portal
выбрать файл, портал передаёт запрос сюда (org.freedesktop.impl.portal.
FileChooser), а диалог рисует Pixel Shell — окно в стиле «Файлов».

Связь с оболочкой: запрос уходит JSON-строкой через
`pixel-shell filechooser request <json>`, ответ оболочка атомарно пишет в
файл reply (путь — в запросе), служба его ждёт. Отмену запроса
приложением (Request.Close) служба передаёт оболочке.

Если оболочка не отвечает (не запущена, перезапускается), запрос
целиком передаётся штатному бэкенду GTK (org.freedesktop.impl.portal.
desktop.gtk) — диалог выбора файлов не ломается никогда.

Права на файлы для Flatpak выдаёт сам xdg-desktop-portal (document
portal) по возвращённым URI — здесь ничего для этого делать не нужно.
"""

import asyncio
import json
import os
import shutil
import sys
import uuid
from urllib.parse import quote, unquote, urlparse

try:
    from dbus_next import BusType, Variant
    from dbus_next.aio import MessageBus
    from dbus_next.service import ServiceInterface, method
except ImportError:  # для тестов чистых функций без D-Bus
    ServiceInterface = object

    def method(*_a, **_k):
        return lambda f: f

BUS_NAME = "org.freedesktop.impl.portal.desktop.pixel"
OBJECT_PATH = "/org/freedesktop/portal/desktop"
GTK_NAME = "org.freedesktop.impl.portal.desktop.gtk"
IFACE = "org.freedesktop.impl.portal.FileChooser"
RUNTIME = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "pixel-portal")
SHELL = os.environ.get("PIXEL_SHELL", "pixel-shell")


# --- Чистые функции (проверяются modules/shell/portal/test_portal.py) -------

def unwrap(v):
    """Variant → значение (рекурсивно)."""
    v = getattr(v, "value", v)
    if isinstance(v, list):
        return [unwrap(x) for x in v]
    if isinstance(v, tuple):
        return tuple(unwrap(x) for x in v)
    if isinstance(v, dict):
        return {k: unwrap(x) for k, x in v.items()}
    return v


def bytes_path(v):
    """ay (путь, завершённый нулём) → str."""
    if v is None:
        return ""
    if isinstance(v, (bytes, bytearray)):
        return bytes(v).rstrip(b"\0").decode("utf-8", "replace")
    return str(v)


def to_uri(path):
    return "file://" + quote(path)


def from_uri(uri):
    u = urlparse(uri)
    return unquote(u.path) if u.scheme == "file" else ""


def make_request(kind, rid, reply, title, options):
    """Опции портала → запрос оболочке (только JSON-совместимые значения)."""
    o = {k: unwrap(v) for k, v in (options or {}).items()}
    filters = [
        {"name": name, "patterns": [{"mime": t == 1, "pattern": p} for t, p in rules]}
        for name, rules in o.get("filters", [])
    ]
    cur = o.get("current_filter")
    req = {
        "id": rid,
        "reply": reply,
        "kind": kind,  # open | save | saveFiles
        "title": title,
        "acceptLabel": o.get("accept_label", ""),
        "multiple": bool(o.get("multiple", False)),
        "directory": bool(o.get("directory", False)),
        "filters": filters,
        "currentFilter": cur[0] if cur else "",
        "choices": [
            {"id": cid, "label": label, "options": [list(x) for x in opts], "selected": sel}
            for cid, label, opts, sel in o.get("choices", [])
        ],
        "currentName": o.get("current_name", ""),
        "currentFolder": bytes_path(o.get("current_folder")),
        "currentFile": bytes_path(o.get("current_file")),
        "files": [bytes_path(f) for f in o.get("files", [])],
    }
    return req


def make_results(req, reply, filters_raw):
    """Ответ оболочки → (response, results) для портала, без Variant."""
    if not reply or reply.get("response", 2) != 0:
        return (1 if reply and reply.get("response") == 1 else 2), {}
    res = {"uris": [to_uri(p) for p in reply.get("paths", []) if p.startswith("/")]}
    if reply.get("choices"):
        res["choices"] = [list(x) for x in reply["choices"]]
    name = reply.get("filter")
    if name:
        for f in filters_raw or []:
            if f[0] == name:
                res["current_filter"] = f
                break
    return 0, res


# --- D-Bus ----------------------------------------------------------------------

def to_variants(results):
    out = {}
    if "uris" in results:
        out["uris"] = Variant("as", results["uris"])
    if "choices" in results:
        out["choices"] = Variant("a(ss)", [list(x) for x in results["choices"]])
    if "current_filter" in results:
        f = results["current_filter"]
        out["current_filter"] = Variant("(sa(us))", [f[0], [list(x) for x in f[1]]])
    return out


class Request(ServiceInterface):
    """org.freedesktop.impl.portal.Request на handle запроса."""

    def __init__(self, on_close):
        super().__init__("org.freedesktop.impl.portal.Request")
        self.on_close = on_close

    @method()
    def Close(self):
        self.on_close()


class FileChooser(ServiceInterface):
    def __init__(self, bus):
        super().__init__(IFACE)
        self.bus = bus

    async def shell_call(self, *args):
        exe = shutil.which(SHELL) or SHELL
        proc = await asyncio.create_subprocess_exec(
            exe, *args, stdout=asyncio.subprocess.DEVNULL, stderr=asyncio.subprocess.DEVNULL
        )
        try:
            return await asyncio.wait_for(proc.wait(), 5) == 0
        except asyncio.TimeoutError:
            proc.kill()
            return False

    async def via_gtk(self, member, signature, body):
        """Передать запрос штатному бэкенду GTK."""
        from dbus_next import Message, MessageType

        reply = await self.bus.call(Message(
            destination=GTK_NAME, path=OBJECT_PATH, interface=IFACE,
            member=member, signature=signature, body=body,
        ))
        if reply.message_type == MessageType.ERROR:
            return [2, {}]
        return reply.body

    async def run(self, member, kind, handle, app_id, parent, title, options, signature, body):
        rid = uuid.uuid4().hex
        os.makedirs(RUNTIME, mode=0o700, exist_ok=True)
        reply_path = os.path.join(RUNTIME, rid + ".json")
        req = make_request(kind, rid, reply_path, title, options)
        req["appId"] = app_id
        closed = asyncio.Event()

        def on_close():
            closed.set()
            asyncio.ensure_future(self.shell_call("filechooser", "cancel", rid))

        request = Request(on_close)
        self.bus.export(handle, request)
        try:
            if not await self.shell_call("filechooser", "request", json.dumps(req, ensure_ascii=False)):
                return await self.via_gtk(member, signature, body)
            reply = None
            while not closed.is_set():
                if os.path.exists(reply_path):
                    with open(reply_path, encoding="utf-8") as f:
                        reply = json.load(f)
                    break
                await asyncio.sleep(0.1)
            response, results = make_results(req, reply, unwrap(options.get("filters")) if options else [])
            return [response, to_variants(results)]
        finally:
            self.bus.unexport(handle, request)
            try:
                os.unlink(reply_path)
            except FileNotFoundError:
                pass

    @method()
    async def OpenFile(self, handle: "o", app_id: "s", parent_window: "s", title: "s", options: "a{sv}") -> "ua{sv}":
        return await self.run("OpenFile", "open", handle, app_id, parent_window, title, options,
                              "osssa{sv}", [handle, app_id, parent_window, title, options])

    @method()
    async def SaveFile(self, handle: "o", app_id: "s", parent_window: "s", title: "s", options: "a{sv}") -> "ua{sv}":
        return await self.run("SaveFile", "save", handle, app_id, parent_window, title, options,
                              "osssa{sv}", [handle, app_id, parent_window, title, options])

    @method()
    async def SaveFiles(self, handle: "o", app_id: "s", parent_window: "s", title: "s", options: "a{sv}") -> "ua{sv}":
        return await self.run("SaveFiles", "saveFiles", handle, app_id, parent_window, title, options,
                              "osssa{sv}", [handle, app_id, parent_window, title, options])


async def main():
    bus = await MessageBus(bus_type=BusType.SESSION).connect()
    bus.export(OBJECT_PATH, FileChooser(bus))
    await bus.request_name(BUS_NAME)
    try:
        await bus.wait_for_disconnect()
    except (EOFError, ConnectionError):
        pass  # сеанс закончился — шина ушла, выходим тихо


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        sys.exit(0)
