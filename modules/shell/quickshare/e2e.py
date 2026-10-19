#!/usr/bin/env python3
# Сквозная проверка pixel-quickshare: две службы в разных сетевых
# пространствах (veth между ними), одна видима и принимает, другая находит
# её через mDNS и отправляет файл. Запуск от root:
#   python3 e2e.py <pixel-quickshare> <ip>
# Нужны: ip (iproute2), права на netns. В песочнице Nix не работает.
import json, os, socket, subprocess, sys, tempfile, time

bin_, ip = sys.argv[1], sys.argv[2]
root = tempfile.mkdtemp(prefix="qs-e2e-")


def sh(*a):
    subprocess.run(a, check=True)


def netns():
    for n in ("qsa", "qsb"):
        subprocess.run([ip, "netns", "del", n], stderr=subprocess.DEVNULL)
        sh(ip, "netns", "add", n)
    sh(ip, "link", "add", "qsva", "type", "veth", "peer", "name", "qsvb")
    for n, dev, addr in (("qsa", "qsva", "10.78.0.1"), ("qsb", "qsvb", "10.78.0.2")):
        sh(ip, "link", "set", dev, "netns", n)
        sh(ip, "-n", n, "addr", "add", addr + "/24", "dev", dev)
        sh(ip, "-n", n, "link", "set", "lo", "up")
        sh(ip, "-n", n, "link", "set", dev, "up", "multicast", "on")
        sh(ip, "-n", n, "route", "add", "224.0.0.0/4", "dev", dev)


def start(ns, name, port):
    home = os.path.join(root, ns)
    env = dict(os.environ, HOME=home, XDG_RUNTIME_DIR=home + "/run",
               XDG_STATE_HOME=home + "/state", XDG_DOWNLOAD_DIR=home + "/dl",
               PATH=os.path.join(root, "nobin"))  # без notify-send: отвечает клиент
    os.makedirs(home + "/run")
    os.makedirs(home + "/dl")
    os.makedirs(home + "/.config", exist_ok=True)
    with open(home + "/.config/user-dirs.dirs", "w") as f:
        f.write('XDG_DOWNLOAD_DIR="$HOME/dl"\n')
    log = open(home + ".log", "w")
    p = subprocess.Popen([ip, "netns", "exec", ns, bin_, "--port", str(port), "--name", name],
                         env=env, stdout=log, stderr=log)
    sock = home + "/run/pixel-quickshare.sock"
    for _ in range(100):
        if os.path.exists(sock):
            break
        time.sleep(0.1)
    return p, sock


class Client:
    def __init__(self, path):
        self.s = socket.socket(socket.AF_UNIX)
        self.s.connect(path)
        self.f = self.s.makefile("r")

    def cmd(self, **kw):
        self.s.sendall((json.dumps(kw) + "\n").encode())

    def until(self, pred, timeout):
        self.s.settimeout(timeout)
        end = time.time() + timeout
        while time.time() < end:
            line = self.f.readline()
            if not line:
                break
            ev = json.loads(line)
            print("  ", ev, flush=True)
            if pred(ev):
                return ev
        raise SystemExit(f"не дождались события за {timeout} с")


def main():
    netns()
    procs = []
    try:
        pa, sa = start("qsa", "Приёмник", 47381)
        pb, sb = start("qsb", "Отправитель", 47382)
        procs = [pa, pb]
        a, b = Client(sa), Client(sb)
        a.cmd(cmd="visibility", value="visible")
        a.until(lambda e: e.get("ev") == "hello" and e["visibility"] == "visible", 5)

        payload = os.path.join(root, "привет мир.txt")
        with open(payload, "w") as f:
            f.write("Quick Share из Pixel\n" * 1000)

        b.cmd(cmd="discover", on=True)
        dev = b.until(lambda e: e.get("ev") == "device" and e["name"] == "Приёмник", 30)
        b.cmd(cmd="send", device=dev["id"], files=[payload])

        req = a.until(lambda e: e.get("ev") == "transfer" and e["state"] == "WaitingForUserConsent", 30)
        assert req["device"] == "Отправитель", req
        assert req["files"] == ["привет мир.txt"], req
        assert req["pin"], req
        a.cmd(cmd="accept", id=req["id"])
        done = a.until(lambda e: e.get("ev") == "transfer" and e["state"] in ("Finished", "Disconnected", "Rejected", "Cancelled"), 30)
        assert done["state"] == "Finished", done
        b.until(lambda e: e.get("ev") == "transfer" and e["state"] == "Finished", 30)
        got = os.path.join(root, "qsa/dl/привет мир.txt")
        assert open(got).read() == open(payload).read(), "содержимое не совпало"

        # отказ доходит до отправителя
        b.cmd(cmd="send", device=dev["id"], files=[payload])
        req = a.until(lambda e: e.get("ev") == "transfer" and e["state"] == "WaitingForUserConsent", 30)
        a.cmd(cmd="decline", id=req["id"])
        a.until(lambda e: e.get("ev") == "transfer" and e["id"] == req["id"] and e["state"] == "Rejected", 30)
        # приёмник закрывает соединение сразу после отказа: отправитель видит
        # отказ или обрыв, в зависимости от того, что прочитал первым
        b.until(lambda e: e.get("ev") == "transfer" and e["state"] in ("Rejected", "Disconnected"), 30)
        assert not os.path.exists(os.path.join(root, "qsa/dl/привет мир (1).txt"))
        # доверенное устройство — приём без вопроса
        a.cmd(cmd="trust", name="Отправитель", on=True)
        a.until(lambda e: e.get("ev") == "hello" and "Отправитель" in e.get("trusted", []), 5)
        b.cmd(cmd="send", device=dev["id"], files=[payload])
        a.until(lambda e: e.get("ev") == "transfer" and e["state"] == "Finished", 30)
        assert open(os.path.join(root, "qsa/state/pixel-quickshare/trusted")).read() == "Отправитель"
        print("OK: передача, согласие, отказ, доверенное устройство")
    finally:
        for p in procs:
            p.terminate()
        for p in procs:
            try:
                p.wait(10)
            except subprocess.TimeoutExpired:
                p.kill()
        for n in ("qsa", "qsb"):
            subprocess.run([ip, "netns", "del", n], stderr=subprocess.DEVNULL)


main()
