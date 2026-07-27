// Process Helper — QClipboard PRIMARY selection
// Reads PRIMARY selection via QClipboard, no external xclip needed.
// Tracks selection change timestamps for freshness checks.

#ifndef PROCESSHELPER_H
#define PROCESSHELPER_H

#include <QObject>
#include <QtQml>

class QProcess;

class ProcessHelper : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    /// Timestamp (ms since epoch) of the last PRIMARY selection change.
    Q_PROPERTY(qint64 selectionTimestamp READ selectionTimestamp NOTIFY selectionTimestampChanged)

public:
    explicit ProcessHelper(QObject *parent = nullptr);
    ~ProcessHelper() override;

    /// Read PRIMARY selection text synchronously via QClipboard.
    Q_INVOKABLE QString readPrimarySelection();

    /// Last PRIMARY selection change timestamp (ms since epoch).
    qint64 selectionTimestamp() const { return m_selectionTimestamp; }

    // Process execution
    /// Run a command asynchronously via QProcess.
    /// Fires commandFinished or commandError signals.
    Q_INVOKABLE void runCommand(const QString &command, const QStringList &args);

    /// Cancel a currently running command.
    Q_INVOKABLE void cancelCommand();

    /// Generate a temporary file path in the cache directory.
    Q_INVOKABLE QString cacheFilePath(const QString &prefix, const QString &suffix) const;

    /// Check if a file exists on disk.
    Q_INVOKABLE bool fileExists(const QString &filePath) const;

    /// Remove a file from disk. Returns true if successful.
    Q_INVOKABLE bool removeFile(const QString &filePath);

    /// Remove oldest files from a cache directory until at most maxFiles remain.
    Q_INVOKABLE void cleanTtsCache(const QString &cacheDir, int maxFiles);

    /// Ensure a cache sub-directory exists and return its absolute path.
    Q_INVOKABLE QString cacheDir(const QString &subdir) const;

    // Config persistence (JSON to ~/.config/linguaspanner/linguaspanner.json)
    /// Write entire config JSON object string to file. Empty string deletes the file.
    Q_INVOKABLE void saveConfig(const QString &json);

    /// Read entire config JSON object string from file. Returns empty string if no file.
    Q_INVOKABLE QString loadConfig() const;

signals:
    /// Emitted when PRIMARY selection owner changes.
    void selectionTimestampChanged();

    /// Emitted after runCommand completes.
    void commandFinished(int exitCode, QString stdOut, QString stdErr);

    /// Emitted when QProcess fails or runCommand is rejected.
    void commandError(QString errorMessage);

private:
    QString configFilePath() const;
    qint64 m_selectionTimestamp = 0;
    QProcess *m_process = nullptr;
};

#endif // PROCESHELPER_H
