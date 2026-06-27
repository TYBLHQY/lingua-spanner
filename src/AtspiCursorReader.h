#ifndef ATSPICURSORREADER_H
#define ATSPICURSORREADER_H

#include <QObject>
#include <QString>
#include <QtQml>

class AtspiCursorReader : public QObject
{
    Q_OBJECT
    QML_ELEMENT

public:
    explicit AtspiCursorReader(QObject *parent = nullptr);
    ~AtspiCursorReader() override = default;

    Q_INVOKABLE QString wordUnderCursor();
    Q_INVOKABLE bool isAvailable();
};

#endif
