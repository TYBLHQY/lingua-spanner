#include "ProcessHelper.h"

#include <cstdio>
#include <QElapsedTimer>
#include <QFileInfo>
#include <QDateTime>

ProcessHelper::ProcessHelper(QObject *parent)
    : QObject(parent)
{
}

static void debugLog(const char *msg)
{
    // Write directly to stderr so it always reaches journalctl
    QByteArray ts = QDateTime::currentDateTime().toString("hh:mm:ss.zzz").toLatin1();
    fprintf(stderr, "[ProcessHelper] %s %s\n", ts.constData(), msg);
    fflush(stderr);
}

QString ProcessHelper::readProcessOutput(const QString &program,
                                         const QStringList &args,
                                         int timeoutMs)
{
    QElapsedTimer timer;
    timer.start();

    // Build command line for logging
    QString cmdLine = program;
    for (const auto &a : args)
        cmdLine += " '" + a + "'";
    debugLog(QString("START %1 timeout=%2").arg(cmdLine).arg(timeoutMs).toLatin1());

    QProcess proc;
    proc.start(program, args);

    if (!proc.waitForFinished(timeoutMs)) {
        debugLog(QString("TIMEOUT after %1ms cmd=%2")
                 .arg(timer.elapsed()).arg(cmdLine).toLatin1());
        proc.kill();
        proc.waitForFinished(1000);
        return {};
    }

    if (proc.exitCode() != 0) {
        debugLog(QString("FAILED exit=%1 elapsed=%2ms stderr=%3")
                 .arg(proc.exitCode())
                 .arg(timer.elapsed())
                 .arg(QString::fromUtf8(proc.readAllStandardError()).trimmed())
                 .toLatin1());
        return {};
    }

    QString result = QString::fromUtf8(proc.readAllStandardOutput()).trimmed();
    QString preview = result.length() > 80
        ? result.left(80) + "..."
        : result;
    debugLog(QString("DONE elapsed=%1ms len=%2 out='%3'")
             .arg(timer.elapsed())
             .arg(result.length())
             .arg(preview)
             .toLatin1());
    return result;
}

void ProcessHelper::log(const QString &msg)
{
    debugLog(msg.toLatin1());
}
