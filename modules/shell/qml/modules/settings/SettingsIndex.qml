pragma Singleton

// Разделы настроек и поисковый индекс по пунктам внутри них.
import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property var pages: [
        {
            page: "network",
            file: "NetworkPage",
            icon: "wifi",
            title: "Сеть и интернет",
            subtitle: "Wi‑Fi, Ethernet, VPN",
            accent: 0,
            keywords: "wifi вайфай интернет ethernet кабель сеть пароль точка доступа vpn dns"
        },
        {
            page: "bluetooth",
            file: "BluetoothPage",
            icon: "bluetooth",
            title: "Подключённые устройства",
            subtitle: "Bluetooth, наушники, геймпады",
            accent: 1,
            keywords: "bluetooth блютуз наушники геймпад мышь клавиатура сопряжение"
        },
        {
            page: "display",
            file: "DisplayPage",
            icon: "desktop_windows",
            title: "Экран",
            subtitle: "Разрешение, частота, масштаб, ночной режим",
            accent: 2,
            keywords: "монитор разрешение частота герц hz масштаб scale vrr freesync ночной режим яркость расположение"
        },
        {
            page: "sound",
            file: "SoundPage",
            icon: "volume_up",
            title: "Звук",
            subtitle: "Громкость, устройства, микшер приложений",
            accent: 3,
            keywords: "звук громкость динамики наушники микрофон выход вход приложения микшер"
        },
        {
            page: "style",
            file: "StylePage",
            icon: "palette",
            title: "Обои и стиль",
            subtitle: "Цвета, шрифт, тёмная тема, значки",
            accent: 4,
            keywords: "обои фон цвет палитра тема тёмная светлая material you иконки значки matugen шрифт font жирный размер текста google sans wallpaper engine живые"
        },
        {
            page: "desktop",
            file: "DesktopPage",
            icon: "space_dashboard",
            title: "Рабочий стол и окна",
            subtitle: "Панель задач, отступы, скругления, анимации",
            accent: 5,
            keywords: "панель задач таскбар положение сверху снизу слева справа монитор экран раскладка часы дата воркспейсы окна отступы скругление рамка размытие прозрачность анимации трей"
        },
        {
            page: "notifications",
            file: "NotificationsPage",
            icon: "notifications",
            title: "Уведомления",
            subtitle: "Не беспокоить, всплывающие окна",
            accent: 0,
            keywords: "уведомления не беспокоить dnd всплывающие история"
        },
        {
            page: "apps",
            file: "AppsPage",
            icon: "apps",
            title: "Приложения",
            subtitle: "По умолчанию, автозапуск, закреплённые",
            accent: 1,
            keywords: "приложения по умолчанию браузер файловый менеджер терминал автозапуск закреплённые"
        },
        {
            page: "input",
            file: "InputPage",
            icon: "keyboard",
            title: "Клавиатура и мышь",
            subtitle: "Раскладки, повтор, чувствительность, сочетания",
            accent: 2,
            keywords: "клавиатура раскладка язык мышь чувствительность ускорение прокрутка повтор горячие клавиши сочетания бинды"
        },
        {
            page: "power",
            file: "PowerPage",
            icon: "battery_charging_full",
            title: "Питание и блокировка",
            subtitle: "Блокировка, сон, отключение экрана",
            accent: 3,
            keywords: "питание сон блокировка экран гаснет простой батарея выключение"
        },
        {
            page: "system",
            file: "SystemPage",
            icon: "deployed_code",
            title: "Система",
            subtitle: "NixOS: пакеты, службы, обновление",
            accent: 4,
            keywords: "система nixos пакеты flatpak службы docker steam игры часовой пояс язык время обновление пересборка rebuild откат поколения очистка сборка мусора"
        },
        {
            page: "about",
            file: "AboutPage",
            icon: "info",
            title: "О системе",
            subtitle: "Компьютер, версия, железо",
            accent: 5,
            keywords: "о системе версия процессор видеокарта память ядро имя компьютера"
        }
    ]

    function search(q) {
        const query = q.trim().toLowerCase();
        if (!query)
            return [];
        const words = query.split(/\s+/);
        return pages.map(p => {
            const hay = (p.title + " " + p.subtitle + " " + p.keywords).toLowerCase();
            const score = words.every(w => hay.includes(w)) ? (p.title.toLowerCase().includes(query) ? 2 : 1) : 0;
            return {
                p,
                score
            };
        }).filter(x => x.score > 0).sort((a, b) => b.score - a.score).map(x => x.p);
    }
}
