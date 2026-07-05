// Process Helper — QClipboard PRIMARY selection + SQLite
// Reads PRIMARY selection via QClipboard, no external xclip needed.
// Tracks selection change timestamps for freshness checks.
// Provides SQLite CRUD for query result persistence.

#ifndef PROCESSHELPER_H
#define PROCESSHELPER_H

#include <QObject>
#include <QtQml>

#include <QSqlDatabase>

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

    // SQLite
    /// Open/create ~/.config/linguaspanner/linguaspanner.db and ensure schema.
    Q_INVOKABLE void initDb();

    /// Execute a SQL statement with optional JSON array of positional params.
    /// Returns JSON array of row objects for SELECT; empty string otherwise.
    Q_INVOKABLE QString exec(const QString &sql, const QString &jsonParams = "[]");

    /// Close the database connection.
    Q_INVOKABLE void closeDb();

    // Process execution
    /// Run a command asynchronously via QProcess.
    /// Fires commandFinished or commandError signals.
    Q_INVOKABLE void runCommand(const QString &command, const QStringList &args);

    /// Cancel a currently running command.
    Q_INVOKABLE void cancelCommand();

    /// Generate a temporary file path in the cache directory.
    Q_INVOKABLE QString cacheFilePath(const QString &prefix, const QString &suffix) const;

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
    QString dbFilePath() const;
    QString configFilePath() const;
    qint64 m_selectionTimestamp = 0;
    QSqlDatabase m_db;
    QProcess *m_process = nullptr;
};

#endif // PROCESHELPER_H
