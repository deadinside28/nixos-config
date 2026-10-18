// pixel-quickshare — служба Quick Share для Pixel Shell на rqs_lib
// (open-quickshare): приём и отправка в общей сети, по BLE и с переходом на
// Wi-Fi Direct / точку доступа, если их поддерживает телефон.
//
// Оболочка говорит со службой через $XDG_RUNTIME_DIR/pixel-quickshare.sock:
// по строке JSON на сообщение. Команды:
//   {"cmd":"visibility","value":"visible"|"hidden"|"temporary"}
//   {"cmd":"discover","on":true|false}
//   {"cmd":"send","device":"<id>","files":["/путь", ...]}
//   {"cmd":"accept"|"decline"|"cancel","id":"<id>"}
//   {"cmd":"state"}
// События: hello (имя, видимость), device, device-gone, transfer, error.
//
// Согласие на входящую передачу спрашивается уведомлением с кнопками
// «Принять» / «Отклонить» (notify-send), поэтому работает и без окна
// оболочки. Закрытое уведомление — отказ.
//
// Лицензия: GPL-3.0-or-later, как у rqs_lib.

#[macro_use]
extern crate log;

use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::time::Duration;

use rqs_lib::channel::{ChannelMessage, Message, MessageClient, TransferAction, TransferKind};
use rqs_lib::hdl::info::TransferPayload;
use rqs_lib::{EndpointInfo, OutboundPayload, RQS, SendInfo, Visibility};
use serde::Deserialize;
use serde_json::{Value, json};
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::net::{UnixListener, UnixStream};
use tokio::process::Command;
use tokio::sync::{Mutex, broadcast, mpsc};
use tracing_subscriber::EnvFilter;

// Через столько «на время» снова становится «скрыто» (как в rqs_lib)
const TEMPORARY: Duration = Duration::from_secs(60);

#[derive(Deserialize)]
#[serde(tag = "cmd", rename_all = "lowercase")]
enum Cmd {
    Visibility { value: String },
    Discover { on: bool },
    Send { device: String, files: Vec<String> },
    Accept { id: String },
    Decline { id: String },
    Cancel { id: String },
    State,
}

#[derive(Default, Clone)]
struct Transfer {
    outbound: bool,
    state: String,
    device: String,
    pin: Option<String>,
    kind: String,
    files: Vec<String>,
    text: Option<String>,
    total: u64,
    done: u64,
    dest: Option<String>,
    saved: Vec<String>,
}

impl Transfer {
    fn json(&self, id: &str) -> Value {
        json!({
            "ev": "transfer", "id": id,
            "direction": if self.outbound { "out" } else { "in" },
            "state": self.state, "device": self.device, "pin": self.pin,
            "kind": self.kind, "files": self.files, "text": self.text,
            "total": self.total, "done": self.done,
            "dest": self.dest, "saved": self.saved,
        })
    }

    fn finished(&self) -> bool {
        matches!(
            self.state.as_str(),
            "Finished" | "Rejected" | "Cancelled" | "Disconnected"
        )
    }
}

struct State {
    visibility: &'static str,
    devices: HashMap<String, EndpointInfo>,
    transfers: HashMap<String, Transfer>,
    // уведомления согласия, которые ещё висят: закрыть, если передача
    // закончилась раньше ответа
    consent: HashMap<String, tokio::sync::oneshot::Sender<()>>,
    discovering: usize,
}

struct Service {
    rqs: Mutex<RQS>,
    lib: broadcast::Sender<ChannelMessage>,
    send: mpsc::Sender<SendInfo>,
    events: broadcast::Sender<String>,
    state: Mutex<State>,
    state_file: PathBuf,
}

fn device_json(d: &EndpointInfo) -> Value {
    json!({
        "ev": "device", "id": d.id,
        "name": d.name.clone().unwrap_or_else(|| d.id.clone()),
        "type": match d.rtype.clone().map(|t| t as u8) {
            Some(1) => "phone", Some(2) => "tablet", Some(3) => "laptop", _ => "unknown",
        },
        "ble": d.ip.is_none() && d.ble_addr.is_some(),
    })
}

fn parse_visibility(v: &str) -> Option<(Visibility, &'static str)> {
    match v {
        "visible" => Some((Visibility::Visible, "visible")),
        "hidden" => Some((Visibility::Invisible, "hidden")),
        "temporary" => Some((Visibility::Temporarily, "temporary")),
        _ => None,
    }
}

impl Service {
    fn emit(&self, v: Value) {
        let _ = self.events.send(v.to_string());
    }

    async fn hello(&self) -> Value {
        let st = self.state.lock().await;
        json!({
            "ev": "hello",
            "name": self.rqs.lock().await.get_device_name(),
            "visibility": st.visibility,
            "discovering": st.discovering > 0,
        })
    }

    async fn set_visibility(self: &Arc<Self>, value: &str) -> anyhow::Result<()> {
        let (vis, name) =
            parse_visibility(value).ok_or_else(|| anyhow::anyhow!("видимость: {value}"))?;
        self.rqs.lock().await.change_visibility(vis);
        self.state.lock().await.visibility = name;
        // «на время» не запоминается: после перезапуска — прежнее
        if vis != Visibility::Temporarily {
            if let Some(dir) = self.state_file.parent() {
                let _ = tokio::fs::create_dir_all(dir).await;
            }
            let _ = tokio::fs::write(&self.state_file, name).await;
        } else {
            let me = self.clone();
            tokio::spawn(async move {
                tokio::time::sleep(TEMPORARY).await;
                let mut st = me.state.lock().await;
                if st.visibility == "temporary" {
                    me.rqs.lock().await.change_visibility(Visibility::Invisible);
                    st.visibility = "hidden";
                    drop(st);
                    let hello = me.hello().await;
                    me.emit(hello);
                }
            });
        }
        let hello = self.hello().await;
        self.emit(hello);
        Ok(())
    }

    async fn discover(self: &Arc<Self>, on: bool) -> anyhow::Result<()> {
        let mut st = self.state.lock().await;
        if on {
            st.discovering += 1;
            if st.discovering > 1 {
                return Ok(());
            }
            let (tx, mut rx) = broadcast::channel::<EndpointInfo>(32);
            self.rqs.lock().await.discovery(tx)?;
            let me = self.clone();
            tokio::spawn(async move {
                while let Ok(d) = rx.recv().await {
                    let mut st = me.state.lock().await;
                    if st.discovering == 0 {
                        break;
                    }
                    if d.present == Some(false) {
                        st.devices.remove(&d.id);
                        me.emit(json!({"ev": "device-gone", "id": d.id}));
                    } else {
                        me.emit(device_json(&d));
                        st.devices.insert(d.id.clone(), d);
                    }
                }
            });
        } else if st.discovering > 0 {
            st.discovering -= 1;
            if st.discovering == 0 {
                self.rqs.lock().await.stop_discovery();
                st.devices.clear();
            }
        }
        Ok(())
    }

    async fn send(&self, device: &str, files: Vec<String>) -> anyhow::Result<()> {
        let d = self
            .state
            .lock()
            .await
            .devices
            .get(device)
            .cloned()
            .ok_or_else(|| anyhow::anyhow!("устройство пропало из списка"))?;
        for f in &files {
            if !Path::new(f).is_file() {
                anyhow::bail!("не файл: {f}");
            }
        }
        let ble = d.ip.is_none() && d.ble_addr.is_some();
        let addr = match (&d.ip, &d.port) {
            (Some(ip), Some(port)) => format!("{ip}:{port}"),
            _ if ble => String::new(),
            _ => anyhow::bail!("у устройства нет адреса"),
        };
        let name = d.name.clone().unwrap_or_else(|| d.id.clone());
        self.state.lock().await.transfers.insert(
            d.id.clone(),
            Transfer {
                outbound: true,
                state: "Initial".into(),
                device: name.clone(),
                kind: "files".into(),
                files: files.iter().map(|f| base(f)).collect(),
                ..Default::default()
            },
        );
        self.send
            .send(SendInfo {
                id: d.id.clone(),
                name,
                addr,
                ob: OutboundPayload::Files(files),
                ble,
            })
            .await?;
        Ok(())
    }

    fn action(&self, id: &str, action: TransferAction) {
        let _ = self.lib.send(ChannelMessage {
            id: id.to_string(),
            msg: Message::Lib { action },
        });
    }

    async fn handle(self: &Arc<Self>, cmd: Cmd, discovering: &mut bool) -> anyhow::Result<()> {
        match cmd {
            Cmd::Visibility { value } => self.set_visibility(&value).await?,
            Cmd::Discover { on } => {
                if on != *discovering {
                    *discovering = on;
                    self.discover(on).await?;
                }
            }
            Cmd::Send { device, files } => self.send(&device, files).await?,
            Cmd::Accept { id } => self.answer(&id, true).await,
            Cmd::Decline { id } => self.answer(&id, false).await,
            Cmd::Cancel { id } => self.action(&id, TransferAction::TransferCancel),
            Cmd::State => {}
        }
        Ok(())
    }

    async fn answer(&self, id: &str, accept: bool) {
        // ответили из оболочки — уведомление больше не нужно
        if let Some(close) = self.state.lock().await.consent.remove(id) {
            let _ = close.send(());
        }
        self.action(
            id,
            if accept {
                TransferAction::ConsentAccept
            } else {
                TransferAction::ConsentDecline
            },
        );
    }

    // Обновить передачу по сообщению rqs_lib
    async fn update(self: &Arc<Self>, id: &str, mc: &MessageClient) {
        let mut st = self.state.lock().await;
        let t = st.transfers.entry(id.to_string()).or_default();
        let before = t.state.clone();
        t.outbound = mc.kind == TransferKind::Outbound;
        if let Some(s) = &mc.state {
            t.state = format!("{s:?}");
        }
        if let Some(md) = &mc.metadata {
            if let Some(src) = &md.source {
                t.device = src.name.clone();
            }
            if md.pin_code.is_some() {
                t.pin = md.pin_code.clone();
            }
            if md.total_bytes > 0 {
                t.total = md.total_bytes;
                t.done = md.ack_bytes;
            }
            if md.destination.is_some() {
                t.dest = md.destination.clone();
            }
            if let Some(saved) = &md.saved_paths {
                t.saved = saved.clone();
            }
            if let Some(p) = &md.payload {
                match p {
                    TransferPayload::Files(f) => {
                        t.kind = "files".into();
                        t.files = f.iter().map(|f| base(f)).collect();
                    }
                    TransferPayload::Text(s) => {
                        t.kind = "text".into();
                        t.text = Some(s.clone());
                    }
                    TransferPayload::Url(s) => {
                        t.kind = "url".into();
                        t.text = Some(s.clone());
                    }
                    TransferPayload::Wifi { ssid, .. } => {
                        t.kind = "wifi".into();
                        t.text = Some(ssid.clone());
                    }
                }
            } else if let Some(p) = &md.payload_preview {
                t.text.get_or_insert_with(|| p.clone());
            }
        }
        let t = t.clone();
        self.emit(t.json(id));
        if t.state == before {
            return;
        }
        if !t.outbound && t.state == "WaitingForUserConsent" {
            let (close, closed) = tokio::sync::oneshot::channel();
            st.consent.insert(id.to_string(), close);
            let me = self.clone();
            let id = id.to_string();
            tokio::spawn(async move { me.ask_consent(id, t, closed).await });
        } else if t.finished() {
            if let Some(close) = st.consent.remove(id) {
                let _ = close.send(());
            }
            st.transfers.remove(id);
            drop(st);
            self.report(&t).await;
        }
    }

    // Уведомление с «Принять / Отклонить»
    async fn ask_consent(
        self: Arc<Self>,
        id: String,
        t: Transfer,
        closed: tokio::sync::oneshot::Receiver<()>,
    ) {
        let what = match t.kind.as_str() {
            "files" if t.files.len() == 1 => format!("файл «{}»", t.files[0]),
            "files" => format!("файлы: {}", t.files.len()),
            "url" => "ссылку".into(),
            "wifi" => "сеть Wi-Fi".into(),
            _ => "текст".into(),
        };
        let mut body = format!("Хочет отправить {what}.");
        if let Some(pin) = &t.pin {
            body.push_str(&format!("\nКод: {pin} — должен совпадать с кодом на телефоне."));
        }
        let child = Command::new("notify-send")
            .args([
                "--app-name=Quick Share",
                "--icon=phone-symbolic",
                "--urgency=critical",
                "--wait",
                "--action=accept=Принять",
                "--action=decline=Отклонить",
                &format!("{} — Quick Share", t.device),
                &body,
            ])
            .stdout(std::process::Stdio::piped())
            .kill_on_drop(true)
            .spawn();
        let Ok(child) = child else {
            warn!("notify-send не запустился: ответ ждём от оболочки");
            return;
        };
        tokio::select! {
            out = child.wait_with_output() => {
                if self.state.lock().await.consent.remove(&id).is_none() {
                    return; // уже ответили или передача закончилась
                }
                let accept = out
                    .map(|o| String::from_utf8_lossy(&o.stdout).trim() == "accept")
                    .unwrap_or(false);
                self.action(&id, if accept {
                    TransferAction::ConsentAccept
                } else {
                    TransferAction::ConsentDecline
                });
            }
            _ = closed => {} // kill_on_drop закроет notify-send
        }
    }

    // Итог передачи: уведомление, текст — в буфер обмена
    async fn report(&self, t: &Transfer) {
        let mut args: Vec<String> = vec!["--app-name=Quick Share".into()];
        let (title, body) = match (t.outbound, t.state.as_str(), t.kind.as_str()) {
            (true, "Finished", _) => ("Отправлено".to_string(), t.device.clone()),
            (true, "Rejected", _) => ("Отклонено".into(), format!("{} отклонил передачу", t.device)),
            (_, "Cancelled", _) => ("Передача отменена".into(), t.device.clone()),
            (_, "Disconnected", _) => ("Передача прервана".into(), t.device.clone()),
            (false, "Finished", "files") => {
                if t.dest.is_some() {
                    args.push("--action=open=Открыть папку".into());
                    args.push("--wait".into());
                }
                (
                    format!("Получено от {}", t.device),
                    t.saved
                        .iter()
                        .map(|p| base(p))
                        .collect::<Vec<_>>()
                        .join(", "),
                )
            }
            (false, "Finished", "text") | (false, "Finished", "url") => {
                let text = t.text.clone().unwrap_or_default();
                let copied = copy(&text).await;
                if t.kind == "url" {
                    args.push("--action=open=Открыть".into());
                    args.push("--wait".into());
                }
                (
                    format!("{} от {}", if t.kind == "url" { "Ссылка" } else { "Текст" }, t.device),
                    if copied { format!("{text}\n(скопировано)") } else { text },
                )
            }
            (false, "Finished", "wifi") => (
                format!("Сеть Wi-Fi от {}", t.device),
                format!("«{}» — подключение не выполняется автоматически", t.text.clone().unwrap_or_default()),
            ),
            _ => return,
        };
        args.push(title);
        args.push(body);
        let open = match t.kind.as_str() {
            "url" => t.text.clone(),
            _ => t.dest.clone(),
        };
        tokio::spawn(async move {
            let out = Command::new("notify-send").args(&args).output().await;
            if let (Ok(o), Some(target)) = (out, open) {
                if String::from_utf8_lossy(&o.stdout).trim() == "open" {
                    let _ = Command::new("xdg-open").arg(target).spawn();
                }
            }
        });
    }
}

fn base(p: &str) -> String {
    Path::new(p)
        .file_name()
        .map(|n| n.to_string_lossy().into_owned())
        .unwrap_or_else(|| p.to_string())
}

async fn copy(text: &str) -> bool {
    let Ok(mut child) = Command::new("wl-copy")
        .stdin(std::process::Stdio::piped())
        .spawn()
    else {
        return false;
    };
    if let Some(mut stdin) = child.stdin.take() {
        let _ = stdin.write_all(text.as_bytes()).await;
    }
    child.wait().await.map(|s| s.success()).unwrap_or(false)
}

async fn client(svc: Arc<Service>, stream: UnixStream) {
    let (rd, mut wr) = stream.into_split();
    let mut lines = BufReader::new(rd).lines();
    let mut events = svc.events.subscribe();
    let mut discovering = false;

    let mut snapshot = vec![svc.hello().await];
    {
        let st = svc.state.lock().await;
        snapshot.extend(st.devices.values().map(device_json));
        snapshot.extend(st.transfers.iter().map(|(id, t)| t.json(id)));
    }
    for v in snapshot {
        if wr.write_all(format!("{v}\n").as_bytes()).await.is_err() {
            return;
        }
    }

    loop {
        tokio::select! {
            line = lines.next_line() => {
                let Ok(Some(line)) = line else { break };
                if line.trim().is_empty() {
                    continue;
                }
                let res = match serde_json::from_str::<Cmd>(&line) {
                    Ok(Cmd::State) => {
                        let hello = svc.hello().await;
                        wr.write_all(format!("{hello}\n").as_bytes()).await.ok();
                        Ok(())
                    }
                    Ok(cmd) => svc.handle(cmd, &mut discovering).await,
                    Err(e) => Err(e.into()),
                };
                if let Err(e) = res {
                    let v = json!({"ev": "error", "message": e.to_string()});
                    if wr.write_all(format!("{v}\n").as_bytes()).await.is_err() {
                        break;
                    }
                }
            }
            ev = events.recv() => match ev {
                Ok(ev) => {
                    if wr.write_all(format!("{ev}\n").as_bytes()).await.is_err() {
                        break;
                    }
                }
                Err(broadcast::error::RecvError::Lagged(_)) => continue,
                Err(_) => break,
            }
        }
    }
    // клиент ушёл (оболочка перезапустилась) — его поиск больше не нужен
    if discovering {
        let _ = svc.discover(false).await;
    }
}

fn runtime_dir() -> PathBuf {
    std::env::var_os("XDG_RUNTIME_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(std::env::temp_dir)
}

// pixel-quickshare ctl '<json>' — команда службе из скрипта
async fn ctl(cmd: &str) -> anyhow::Result<()> {
    serde_json::from_str::<Value>(cmd)?;
    let mut s = UnixStream::connect(runtime_dir().join("pixel-quickshare.sock")).await?;
    s.write_all(format!("{cmd}\n").as_bytes()).await?;
    let (rd, _wr) = s.into_split();
    let mut lines = BufReader::new(rd).lines();
    // снимок состояния и ответ на команду, затем выход
    while let Ok(Ok(Some(line))) =
        tokio::time::timeout(Duration::from_millis(500), lines.next_line()).await
    {
        println!("{line}");
    }
    Ok(())
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let args: Vec<String> = std::env::args().skip(1).collect();
    if args.first().map(String::as_str) == Some("ctl") {
        return ctl(args.get(1).map(String::as_str).unwrap_or(r#"{"cmd":"state"}"#)).await;
    }

    tracing_subscriber::fmt()
        .without_time() // время пишет journald
        .with_ansi(std::io::IsTerminal::is_terminal(&std::io::stderr()))
        .with_env_filter(if std::env::var("RUST_LOG").is_ok() {
            EnvFilter::builder().from_env_lossy()
        } else {
            EnvFilter::builder().parse_lossy(
                "info,mdns_sd=error,polling=error,neli=error,bluez_async=error,btleplug=error",
            )
        })
        .init();

    let mut port = None;
    let mut name = None;
    let mut it = args.iter();
    while let Some(a) = it.next() {
        match a.as_str() {
            "--port" => port = it.next().and_then(|p| p.parse().ok()),
            "--name" => name = it.next().cloned(),
            other => anyhow::bail!("неизвестный аргумент: {other}"),
        }
    }

    let state_file = std::env::var_os("XDG_STATE_HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from(std::env::var("HOME").unwrap_or_default()).join(".local/state"))
        .join("pixel-quickshare/visibility");
    let saved = std::fs::read_to_string(&state_file).unwrap_or_default();
    let (vis, vis_name) = match saved.trim() {
        "visible" => (Visibility::Visible, "visible"),
        _ => (Visibility::Invisible, "hidden"),
    };

    // Папка загрузок — по XDG (как у rqs_lib без своей папки)
    let mut rqs = RQS::new(vis, port, None, name);
    let (send, _ble) = rqs.run().await?;
    info!(
        "Quick Share: «{}», порт {:?}, видимость {vis_name}",
        rqs.get_device_name(),
        rqs.port_number
    );

    let (events, _) = broadcast::channel(256);
    let svc = Arc::new(Service {
        lib: rqs.message_sender.clone(),
        rqs: Mutex::new(rqs),
        send,
        events,
        state: Mutex::new(State {
            visibility: vis_name,
            devices: HashMap::new(),
            transfers: HashMap::new(),
            consent: HashMap::new(),
            discovering: 0,
        }),
        state_file,
    });

    let mut lib_rx = svc.lib.subscribe();
    let me = svc.clone();
    tokio::spawn(async move {
        loop {
            match lib_rx.recv().await {
                Ok(cm) => {
                    if let Message::Client(mc) = &cm.msg {
                        me.update(&cm.id, mc).await;
                    }
                }
                Err(broadcast::error::RecvError::Lagged(_)) => continue,
                Err(_) => break,
            }
        }
    });

    let sock = runtime_dir().join("pixel-quickshare.sock");
    let _ = std::fs::remove_file(&sock);
    let listener = UnixListener::bind(&sock)?;

    let mut term = tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate())?;
    loop {
        tokio::select! {
            conn = listener.accept() => {
                if let Ok((stream, _)) = conn {
                    tokio::spawn(client(svc.clone(), stream));
                }
            }
            _ = term.recv() => break,
            _ = tokio::signal::ctrl_c() => break,
        }
    }

    info!("Остановка");
    let _ = std::fs::remove_file(&sock);
    // остановка mDNS и BLE может зависнуть — ограничить по времени
    let _ = tokio::time::timeout(Duration::from_secs(8), svc.rqs.lock().await.stop()).await;
    std::process::exit(0);
}
