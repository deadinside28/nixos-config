"""Проверка pixel-portal на настоящей шине (dbus-run-session):

  dbus-run-session -- python3 test_portal.py pixel-portal.py

- OpenFile: запрос доходит до «оболочки» (заглушка), её ответ
  возвращается приложению URI-ами, фильтр — как в запросе;
- отмена в диалоге — response 1;
- оболочка не отвечает — запрос уходит заглушке бэкенда GTK;
- чистые функции: пути в URI и обратно, ay-пути.
"""

import asyncio
import importlib.util
import json
import os
import stat
import subprocess
import sys
import tempfile

from dbus_next import BusType, Variant
from dbus_next.aio import MessageBus
from dbus_next.service import ServiceInterface, method

portal_file = os.path.abspath(sys.argv[1])
spec = importlib.util.spec_from_file_location("pixel_portal", portal_file)
P = importlib.util.module_from_spec(spec)
spec.loader.exec_module(P)

passed = failed = 0


def check(name, ok):
    global passed, failed
    if ok:
        passed += 1
    else:
        failed += 1
        print("FAIL: " + name, file=sys.stderr)


# --- чистые функции ---
check("путь с пробелом и кириллицей → URI и обратно", P.from_uri(P.to_uri("/home/u/Мои файлы/a b.txt")) == "/home/u/Мои файлы/a b.txt")
check("ay с нулём на конце", P.bytes_path(b"/tmp/x\0") == "/tmp/x")
req = P.make_request("save", "id", "/r", "T", {"current_name": "a.txt", "filters": [["Текст", [[0, "*.txt"], [1, "text/plain"]]]]})
check("запрос: имя и фильтры", req["currentName"] == "a.txt" and req["filters"][0]["patterns"][1] == {"mime": True, "pattern": "text/plain"})
check("отмена — 1, без ответа — 2", P.make_results(req, {"response": 1}, [])[0] == 1 and P.make_results(req, None, [])[0] == 2)

# --- на шине ---
work = tempfile.mkdtemp()
os.environ["XDG_RUNTIME_DIR"] = work
mode_file = os.path.join(work, "mode")
fake_shell = os.path.join(work, "pixel-shell")
# Заглушка оболочки: на request пишет ответ в reply (как QML), режим — из файла
with open(fake_shell, "w") as f:
    f.write(f"""#!{sys.executable}
import json, sys, os
mode = open({mode_file!r}).read().strip()
if sys.argv[1:3] == ["filechooser", "request"]:
    if mode == "down":
        sys.exit(1)
    req = json.loads(sys.argv[3])
    open({os.path.join(work, "last-request")!r}, "w").write(sys.argv[3])
    reply = {{"response": 1}} if mode == "cancel" else {{"response": 0, "paths": ["/tmp/Мой файл.txt"], "filter": "Текст"}}
    tmp = req["reply"] + ".tmp"
    open(tmp, "w").write(json.dumps(reply))
    os.rename(tmp, req["reply"])
""")
os.chmod(fake_shell, stat.S_IRWXU)
os.environ["PIXEL_SHELL"] = fake_shell


class FakeGtk(ServiceInterface):
    def __init__(self):
        super().__init__(P.IFACE)
        self.calls = 0

    @method()
    def OpenFile(self, handle: "o", app_id: "s", parent_window: "s", title: "s", options: "a{sv}") -> "ua{sv}":
        self.calls += 1
        return [0, {"uris": Variant("as", ["file:///from/gtk"])}]


async def main():
    # Портал — отдельным процессом, как в системе
    portal = subprocess.Popen([sys.executable, portal_file], env=os.environ)
    bus = await MessageBus(bus_type=BusType.SESSION).connect()
    gtk = FakeGtk()
    gbus = await MessageBus(bus_type=BusType.SESSION).connect()
    gbus.export(P.OBJECT_PATH, gtk)
    await gbus.request_name(P.GTK_NAME)
    for _ in range(50):
        reply = await bus.call(__import__("dbus_next").Message(destination="org.freedesktop.DBus", path="/org/freedesktop/DBus", interface="org.freedesktop.DBus", member="NameHasOwner", signature="s", body=[P.BUS_NAME]))
        if reply.body[0]:
            break
        await asyncio.sleep(0.1)
    intro = await bus.introspect(P.BUS_NAME, P.OBJECT_PATH)
    fc = bus.get_proxy_object(P.BUS_NAME, P.OBJECT_PATH, intro).get_interface(P.IFACE)
    filters = [["Текст", [[0, "*.txt"]]], ["Всё", [[0, "*"]]]]
    opts = {"filters": Variant("a(sa(us))", filters), "multiple": Variant("b", True)}

    open(mode_file, "w").write("ok")
    resp, res = await fc.call_open_file("/org/freedesktop/portal/desktop/request/1_1/t1", "org.test", "", "Открыть", opts)
    check("OpenFile: успех", resp == 0)
    check("OpenFile: URI с кодированием", res["uris"].value == [P.to_uri("/tmp/Мой файл.txt")])
    check("OpenFile: выбранный фильтр из запроса", res["current_filter"].value[0] == "Текст")
    sent = json.load(open(os.path.join(work, "last-request")))
    check("оболочка получила запрос с фильтрами и multiple", sent["multiple"] and sent["filters"][0]["name"] == "Текст" and sent["appId"] == "org.test")

    open(mode_file, "w").write("cancel")
    resp, res = await fc.call_save_file("/org/freedesktop/portal/desktop/request/1_1/t2", "org.test", "", "Сохранить", {"current_name": Variant("s", "a.txt")})
    check("SaveFile: отмена — 1", resp == 1 and not res)

    open(mode_file, "w").write("down")
    resp, res = await fc.call_open_file("/org/freedesktop/portal/desktop/request/1_1/t3", "org.test", "", "Открыть", {})
    check("оболочка не отвечает → бэкенд GTK", gtk.calls == 1 and resp == 0 and res["uris"].value == ["file:///from/gtk"])
    check("ответы не остаются в runtime", not [f for f in os.listdir(os.path.join(work, "pixel-portal")) if f.endswith(".json")])
    portal.terminate()


asyncio.run(main())
print(f"pixel-portal: {passed} проверок пройдено, {failed} провалено")
sys.exit(1 if failed else 0)
