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
            page: "quickshare",
            file: "QuickSharePage",
            icon: "share",
            title: "Quick Share",
            subtitle: "Обмен файлами с телефоном",
            accent: 5,
            keywords: "quick share nearby share обмен файлами телефон android отправить принять видимость доверенные устройства аккаунт google"
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
            page: "quicksettings",
            file: "QuickSettingsPage",
            icon: "toggle_on",
            title: "Быстрые настройки",
            subtitle: "Плитки шторки и их порядок",
            accent: 3,
            keywords: "шторка быстрые настройки плитки тайлы порядок плеер яркость"
        },
        {
            page: "notifications",
            file: "NotificationsPage",
            icon: "notifications",
            title: "Уведомления",
            subtitle: "Не беспокоить, где показывать, скриншоты",
            accent: 0,
            keywords: "уведомления не беспокоить dnd всплывающие история положение угол монитор скриншот запись"
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
            // Не страница: открывает окно «Магазина» (Ui.goSettings)
            page: "store",
            file: "AppsPage",
            icon: "storefront",
            title: "Магазин приложений",
            subtitle: "Nixpkgs, Chaotic-Nyx и Flatpak — откроется отдельным окном",
            accent: 1,
            keywords: "магазин установить приложение программа пакет flatpak nixpkgs nyx chaotic обновления удалить каталог store"
        },
        {
            page: "storage",
            file: "StoragePage",
            icon: "hard_drive",
            title: "Память",
            subtitle: "Чем занят диск, кеш и данные приложений",
            accent: 3,
            keywords: "память диск место хранилище кеш данные сбросить очистить удалить приложение размер flatpak nix поколения корзина"
        },
        {
            page: "menu",
            file: "MenuPage",
            icon: "grid_view",
            title: "Меню приложений",
            subtitle: "Папки, названия, значки, скрытие, параметры запуска",
            accent: 1,
            keywords: "меню лаунчер приложения папки название значок скрыть ключевые слова аргументы переменные окружения рабочая папка терминал своя команда сетка сортировка источник flatpak nix appimage"
        },
        {
            page: "windows",
            file: "WindowsPage",
            icon: "view_quilt",
            title: "Окна и тайлинг",
            subtitle: "Раскладка окон, фокус, правила для приложений",
            accent: 4,
            keywords: "окна тайлинг раскладка лента мозаика dwindle master scrolling колонки фокус правила плавающее размер стол монитор hyprland"
        },
        {
            page: "input",
            file: "InputPage",
            icon: "keyboard",
            title: "Клавиатура и мышь",
            subtitle: "Раскладки, мышь, горячие клавиши",
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
