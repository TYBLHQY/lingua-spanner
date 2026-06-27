#include "ProcessHelper.h"

ProcessHelper::ProcessHelper(QObject *parent)
    : QObject(parent)
{
}

QString ProcessHelper::readProcessOutput(const QString &program,
                                         const QStringList &args,
                                         int timeoutMs)
{
    QProcess proc;
    proc.start(program, args);

    if (!proc.waitForFinished(timeoutMs)) {
        proc.kill();
        proc.waitForFinished(1000);
        return {};
    }

    if (proc.exitCode() != 0) {
        return {};
    }

    return QString::fromUtf8(proc.readAllStandardOutput()).trimmed();
}
