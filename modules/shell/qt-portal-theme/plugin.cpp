// Тема Qt «hyprland»: просто тема gtk3.
//
// Зачем: с QT_QPA_PLATFORMTHEME=gtk3 Qt рисует GTK-диалог выбора файлов у
// себя в процессе, и портал (а с ним свой диалог оболочки) не участвует.
// Тема xdgdesktopportal отдаёт диалоги порталу, а всё остальное (палитру,
// шрифт, значки) берёт у «базовой» темы, которую ищет по имени рабочего
// стола из XDG_CURRENT_DESKTOP — у нас это «hyprland». Такой темы в Qt нет,
// и базовой становилась голая generic: без значков и цветов GTK.
// Этот плагин и есть тема «hyprland»: он возвращает gtk3. Итог —
// оформление GTK, а файловые диалоги через портал.
#include <qpa/qplatformthemeplugin.h>
#include <qpa/qplatformthemefactory_p.h>

class PixelHyprlandThemePlugin : public QPlatformThemePlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QPlatformThemeFactoryInterface_iid FILE "hyprland.json")

public:
    QPlatformTheme *create(const QString &key, const QStringList &params) override
    {
        Q_UNUSED(key);
        Q_UNUSED(params);
        return QPlatformThemeFactory::create(QStringLiteral("gtk3"));
    }
};

#include "plugin.moc"
