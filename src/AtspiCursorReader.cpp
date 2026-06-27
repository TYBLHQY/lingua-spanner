// ── AT-SPI Cursor Reader — word under cursor ─────────────
// Calls a bundled Python script via QProcess to do the AT-SPI
// D-Bus interaction (Qt's QDBusArgument has read-only issues
// with the a(so) array type used by AT-SPI).
//
// Requirements: python3 + dbus (standard on KDE).

#include "AtspiCursorReader.h"
#include <QProcess>
#include <QCoreApplication>
#include <QFileInfo>
#include <QDebug>

AtspiCursorReader::AtspiCursorReader(QObject *parent)
    : QObject(parent) {}

bool AtspiCursorReader::isAvailable()
{
    QProcess p;
    p.start("pidof", {"at-spi-bus-launcher"});
    p.waitForFinished(1000);
    return p.exitCode() == 0;
}

QString AtspiCursorReader::wordUnderCursor()
{
    // Find the Python script — look relative to the executable path
    // and CWD.  When loaded from the plasmoid package the script is
    // in contents/lib/LinguaSpannerHelper/ next to the .so.
    QString scriptPath;
    QStringList candidates = {
        QStringLiteral("atspi_word_under_cursor.py"),

        // Running from project root
        QStringLiteral("package/contents/lib/LinguaSpannerHelper/"
                       "atspi_word_under_cursor.py"),

        // Running from installed plasmoid
        QStringLiteral(
            "../lib/LinguaSpannerHelper/atspi_word_under_cursor.py"),

        // Absolute project path (dev)
        QStringLiteral(
            "/data/workspace/code-repo/plasma-proj/lingua-spanner/"
            "package/contents/lib/LinguaSpannerHelper/"
            "atspi_word_under_cursor.py"),
    };

    for (const auto &c : candidates) {
        if (QFileInfo::exists(c)) {
            scriptPath = c;
            break;
        }
    }

    if (scriptPath.isEmpty())
        return {};

    QProcess proc;
    proc.start("python3", {scriptPath});
    proc.waitForFinished(12000);  // up to 12s for deep tree traversal

    if (proc.exitCode() != 0)
        return {};

    return QString::fromUtf8(proc.readAllStandardOutput()).trimmed();
}
