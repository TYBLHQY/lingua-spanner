#include "ProcessHelper.h"

#include <cstdio>
#include <QClipboard>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QProcess>
#include <QStandardPaths>

ProcessHelper::ProcessHelper(QObject *parent)
    : QObject(parent)
{
    // Listen for PRIMARY selection changes and record a timestamp.
    // QML uses this to distinguish fresh selections from stale ones.
    connect(QGuiApplication::clipboard(), &QClipboard::changed,
        this, [this](QClipboard::Mode mode) {
            if (mode == QClipboard::Selection) {
                m_selectionTimestamp = QDateTime::currentMSecsSinceEpoch();
                emit selectionTimestampChanged();
            }
        });
}

ProcessHelper::~ProcessHelper()
{
    cancelCommand();
}

QString ProcessHelper::readPrimarySelection()
{
    QString text = QGuiApplication::clipboard()->text(QClipboard::Selection);
    return text.trimmed();
}

QString ProcessHelper::configFilePath() const
{
    QString dir = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation);
    return dir + QStringLiteral("/linguaspanner/linguaspanner.json");
}

void ProcessHelper::saveConfig(const QString &json)
{
    QString path = configFilePath();
    if (json.isEmpty()) {
        QFile::remove(path);
        return;
    }
    QDir().mkpath(QFileInfo(path).absolutePath());
    QFile file(path);
    if (file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        file.write(json.toUtf8());
        file.close();
    }
}

QString ProcessHelper::loadConfig() const
{
    QFile file(configFilePath());
    if (file.open(QIODevice::ReadOnly)) {
        QByteArray data = file.readAll();
        file.close();
        return QString::fromUtf8(data);
    }
    return QString();
}

QString ProcessHelper::cacheFilePath(const QString &prefix, const QString &suffix) const
{
    QString dir = QStandardPaths::writableLocation(QStandardPaths::GenericCacheLocation);
    QString appDir = dir + QStringLiteral("/linguaspanner");
    QDir().mkpath(appDir);
    return appDir + QStringLiteral("/") + prefix + QStringLiteral("_")
        + QString::number(QDateTime::currentMSecsSinceEpoch()) + suffix;
}

void ProcessHelper::runCommand(const QString &command, const QStringList &args)
{
    if (m_process && m_process->state() != QProcess::NotRunning) {
        emit commandError(QStringLiteral("A command is already running"));
        return;
    }

    if (!m_process)
        m_process = new QProcess(this);

    // Handlers below work on this local pointer, never on m_process: a killed
    // process makes QProcess emit errorOccurred(Crashed) *and* finished(), and
    // whichever handler runs first clears m_process — so a handler that read
    // m_process would dereference null.
    QProcess *proc = m_process;
    m_cancelled = false;

    // Finished (normal exit or crash)
    connect(proc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
        this, [this, proc](int exitCode, QProcess::ExitStatus status) {
            if (proc != m_process)
                return; // already handled by the errorOccurred handler
            QString stdOut = QString::fromUtf8(proc->readAllStandardOutput());
            QString stdErr = QString::fromUtf8(proc->readAllStandardError());
            m_process = nullptr;
            proc->deleteLater();
            if (m_cancelled) {
                m_cancelled = false; // a deliberate cancel is not an error
                return;
            }
            if (status == QProcess::CrashExit) {
                emit commandError(QStringLiteral("Process crashed (exit code %1)").arg(exitCode));
            } else {
                emit commandFinished(exitCode, stdOut.trimmed(), stdErr.trimmed());
            }
        });

    // Failed to start, timed out, etc.
    connect(proc, &QProcess::errorOccurred,
        this, [this, proc, command](QProcess::ProcessError error) {
            if (proc != m_process)
                return; // already handled by the finished handler
            m_process = nullptr;
            proc->deleteLater();
            if (m_cancelled) {
                m_cancelled = false; // a deliberate cancel is not an error
                return;
            }
            QString msg;
            switch (error) {
            case QProcess::FailedToStart:
                msg = command + QStringLiteral(": command not found or failed to start.\nPlease install: pip install edge-tts");
                break;
            case QProcess::Crashed:
                msg = QStringLiteral("Process crashed");
                break;
            case QProcess::Timedout:
                msg = QStringLiteral("Command timed out");
                break;
            default:
                msg = QStringLiteral("Process error: %1").arg(static_cast<int>(error));
                break;
            }
            emit commandError(msg);
        });

    proc->start(command, args);
}

void ProcessHelper::cancelCommand()
{
    if (m_process && m_process->state() != QProcess::NotRunning) {
        m_cancelled = true;
        m_process->kill();
        m_process->waitForFinished(3000);
    }
}

bool ProcessHelper::fileExists(const QString &filePath) const
{
    return QFileInfo::exists(filePath);
}

bool ProcessHelper::removeFile(const QString &filePath)
{
    return QFile::remove(filePath);
}

void ProcessHelper::cleanTtsCache(const QString &cacheDir, int maxFiles)
{
    QDir dir(cacheDir);
    if (!dir.exists()) return;

    auto files = dir.entryInfoList(QDir::Files, QDir::Time | QDir::Reversed);
    if (files.size() <= maxFiles) return;

    for (int i = 0; i < files.size() - maxFiles; ++i)
        QFile::remove(files.at(i).absoluteFilePath());
}

QString ProcessHelper::cacheDir(const QString &subdir) const
{
    QString dir = QStandardPaths::writableLocation(QStandardPaths::GenericCacheLocation);
    QString fullDir = dir + QStringLiteral("/linguaspanner/") + subdir;
    QDir().mkpath(fullDir);
    return fullDir;
}
