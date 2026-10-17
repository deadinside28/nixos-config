// Закреплённые и запущенные приложения. Окна берём из wlr-foreign-toplevel
// (ToplevelManager), к .desktop их привязываем по app_id.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.services

Item {
    id: root
    required property var bar

    implicitWidth: row.implicitWidth
    implicitHeight: 48

    readonly property var toplevels: ToplevelManager.toplevels.values

    readonly property var items: {
        // byId() — вызов функции, на него привязка не подписывается;
        // ссылка на Apps.all пересчитает список, когда .desktop загрузятся.
        if (Apps.all.length === 0)
            return [];
        const result = [];
        const seen = {};
        const keyFor = t => {
            const e = Apps.forWindow(t.appId);
            return e ? e.id : "window:" + t.appId;
        };
        const groups = {};
        for (const t of toplevels) {
            const k = keyFor(t);
            (groups[k] = groups[k] ?? []).push(t);
        }
        for (const id of Settings.data.pinnedApps) {
            const e = Apps.byId(id);
            if (!e || seen[e.id])
                continue;
            seen[e.id] = true;
            result.push({
                key: e.id,
                entry: e,
                pinned: true,
                windows: groups[e.id] ?? []
            });
        }
        for (const k of Object.keys(groups)) {
            if (seen[k])
                continue;
            seen[k] = true;
            const e = k.startsWith("window:") ? null : Apps.byId(k);
            result.push({
                key: k,
                entry: e,
                pinned: false,
                windows: groups[k],
                appId: groups[k][0].appId
            });
        }
        return result;
    }

    RowLayout {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        Repeater {
            model: ScriptModel {
                values: root.items
                objectProp: "key"
            }

            AppButton {
                required property var modelData
                item: modelData
                bar: root.bar
            }
        }
    }
}
