// ── Process Helper — lightweight xclip wrapper for QML ───
// Exposes QProcess as a Q_INVOKABLE singleton for reading
// system clipboard / PRIMARY selection from QML.

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

signals:
    /// Emitted when xclip completes successfully.
    void selectionReady(const QString &text);
    /// Emitted when xclip fails or times out.
    void selectionError(const QString &error);

private:
    QProcess *m_currentProcess = nullptr;
};

#endif // PROCESHELPER_H
