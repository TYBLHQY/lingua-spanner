#include "ProcessHelper.h"

#include <cstdio>
#include <QElapsedTimer>
#include <QDateTime>
#include <QTimer>

ProcessHelper::ProcessHelper(QObject *parent)
    : QObject(parent)
{
}

static void debugLog(const char *msg)
{
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

void ProcessHelper::readSelectionAsync(int timeoutMs)
{
    // Kill any in-flight process from a previous call
    if (m_currentProcess) {
        m_currentProcess->kill();
        m_currentProcess->deleteLater();
        m_currentProcess = nullptr;
    }

    qint64 startMs = QDateTime::currentMSecsSinceEpoch();

    auto *process = new QProcess(this);
    m_currentProcess = process;

    // Connect finished handler
    connect(process, &QProcess::finished, this, [this, process, startMs](int exitCode, QProcess::ExitStatus status) {
        if (process != m_currentProcess)
            return; // stale — a newer call superseded this one
        m_currentProcess = nullptr;

        qint64 elapsed = QDateTime::currentMSecsSinceEpoch() - startMs;

        if (status == QProcess::CrashExit || exitCode != 0) {
            qDebug() << "xclip cost" << elapsed << "ms — FAILED";
            emit selectionError(QStringLiteral("xclip failed (exit=%1)").arg(exitCode));
        } else {
            QString text = QString::fromUtf8(process->readAllStandardOutput()).trimmed();
            qDebug() << "xclip cost" << elapsed << "ms — len=" << text.length();
            emit selectionReady(text);
        }

        process->deleteLater();
    });

    // Connect error handler
    connect(process, &QProcess::errorOccurred, this, [this, process, startMs](QProcess::ProcessError err) {
        if (process != m_currentProcess)
            return; // stale
        m_currentProcess = nullptr;

        qint64 elapsed = QDateTime::currentMSecsSinceEpoch() - startMs;
        qDebug() << "xclip cost" << elapsed << "ms — ERROR" << err;
        emit selectionError(QStringLiteral("xclip error: %1").arg(err));

        process->deleteLater();
    });

    // Timeout timer
    QTimer::singleShot(timeoutMs, this, [this, process, timeoutMs]() {
        if (process != m_currentProcess)
            return; // stale
        m_currentProcess = nullptr;

        debugLog("TIMEOUT — killing xclip");
        process->kill();
        emit selectionError(QStringLiteral("xclip timed out after %1ms").arg(timeoutMs));

        process->deleteLater();
    });

    debugLog(QString("ASYNC START xclip -selection primary timeout=%1").arg(timeoutMs).toLatin1());
    process->start("xclip", {"-o", "-selection", "primary"});
}
