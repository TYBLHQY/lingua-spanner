// ── Process Helper — QClipboard PRIMARY selection for QML ──
// Reads PRIMARY selection via QClipboard, no external xclip needed.
// Tracks selection change timestamps for freshness checks.

#ifndef PROCESHELPER_H
#define PROCESHELPER_H

#include <QObject>
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

    /// Read PRIMARY selection text synchronously via QClipboard.
    /// Returns empty string if no selection or selection empty.
    Q_INVOKABLE QString readPrimarySelection();

    /// Last PRIMARY selection change timestamp (ms since epoch).
    qint64 selectionTimestamp() const { return m_selectionTimestamp; }

signals:
    /// Emitted when PRIMARY selection owner changes.
    void selectionTimestampChanged();

private:
    qint64 m_selectionTimestamp = 0;
};

#endif // PROCESHELPER_H
