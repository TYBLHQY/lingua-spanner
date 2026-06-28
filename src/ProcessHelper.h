// ── Process Helper — lightweight xclip wrapper for QML ───
// Exposes QProcess as a Q_INVOKABLE singleton for reading
// system clipboard / PRIMARY selection from QML.
// Also tracks PRIMARY selection change timestamps via
// QClipboard::changed to detect stale selections.

#ifndef PROCESHELPER_H
#define PROCESHELPER_H

#include <QObject>
#include <QStringList>
#include <QProcess>
#include <QtQml>

class ProcessHelper : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    /// Timestamp (ms since epoch) of the last PRIMARY selection change.
    /// Compared with Date.now() in QML to determine freshness.
    Q_PROPERTY(qint64 selectionTimestamp READ selectionTimestamp NOTIFY selectionTimestampChanged)

public:
    explicit ProcessHelper(QObject *parent = nullptr);
    ~ProcessHelper() override = default;

    /// Run a command synchronously and return stdout as QString.
    /// On failure (non-zero exit / timeout) returns an empty string.
    Q_INVOKABLE QString readProcessOutput(const QString &program,
                                          const QStringList &args,
                                          int timeoutMs = 3000);

    /// Run xclip -selection primary asynchronously.
    /// Results arrive via selectionReady / selectionError signals.
    Q_INVOKABLE void readSelectionAsync(int timeoutMs = 3000);

    /// Last PRIMARY selection change timestamp (ms since epoch).
    qint64 selectionTimestamp() const { return m_selectionTimestamp; }

signals:
    /// Emitted when xclip completes successfully.
    void selectionReady(const QString &text);
    /// Emitted when xclip fails or times out.
    void selectionError(const QString &error);
    /// Emitted when PRIMARY selection owner changes.
    void selectionTimestampChanged();

private:
    QProcess *m_currentProcess = nullptr;
    qint64 m_selectionTimestamp = 0;
};

#endif // PROCESHELPER_H
