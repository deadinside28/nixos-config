/* Проверка патчей: стандартные диалоги Wine уходят в портал FileChooser.
 * Пишет результат в C:\pixel-result.txt (UTF-8): "open <ok> <путь>",
 * "save <ok> <путь>". Сборка: x86_64-w64-mingw32-gcc -municode dialogs.c -lcomdlg32 */
#include <windows.h>
#include <commdlg.h>
#include <stdio.h>

static void put(FILE *f, const char *what, BOOL ok, const WCHAR *path)
{
    char utf8[8192];
    WideCharToMultiByte(CP_UTF8, 0, path, -1, utf8, sizeof(utf8), NULL, NULL);
    fprintf(f, "%s %d %s\n", what, ok, utf8);
}

int wmain(void)
{
    WCHAR open[4096] = L"", save[4096] = L"отчёт.txt";
    OPENFILENAMEW o = {0}, s = {0};
    FILE *f = _wfopen(L"C:\\pixel-result.txt", L"wb");
    BOOL ok;

    o.lStructSize = sizeof(o);
    o.lpstrFile = open;
    o.nMaxFile = ARRAYSIZE(open);
    o.lpstrFilter = L"Текст\0*.txt\0Все файлы\0*.*\0";
    o.Flags = OFN_EXPLORER | OFN_FILEMUSTEXIST;
    ok = GetOpenFileNameW(&o);
    put(f, "open", ok, open);

    s.lStructSize = sizeof(s);
    s.lpstrFile = save;
    s.nMaxFile = ARRAYSIZE(save);
    s.lpstrFilter = L"Текст\0*.txt\0";
    s.Flags = OFN_EXPLORER | OFN_OVERWRITEPROMPT;
    ok = GetSaveFileNameW(&s);
    put(f, "save", ok, save);

    fclose(f);
    return 0;
}
