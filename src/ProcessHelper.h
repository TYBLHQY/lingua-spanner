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
};

#endif // PROCESHELPER_H
