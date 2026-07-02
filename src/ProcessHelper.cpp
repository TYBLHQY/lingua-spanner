#include "ProcessHelper.h"

#include <cstdio>
#include <QClipboard>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSqlError>
#include <QSqlQuery>
#include <QSqlRecord>
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
    if (m_db.isOpen())
        m_db.close();
}

QString ProcessHelper::readPrimarySelection()
{
    QString text = QGuiApplication::clipboard()->text(QClipboard::Selection);
    return text.trimmed();
}

QString ProcessHelper::dbFilePath() const
{
    QString dir = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation);
    return dir + QStringLiteral("/linguaspanner/linguaspanner.db");
}

void ProcessHelper::initDb()
{
    QString path = dbFilePath();
    QDir().mkpath(QFileInfo(path).absolutePath());

    if (m_db.isOpen()) {
        // Already open — ensure we're pointing at the right file
        if (m_db.databaseName() == path)
            return;
        m_db.close();
    }

    m_db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"),
        QStringLiteral("linguaspanner_%1").arg(reinterpret_cast<quintptr>(this), 0, 16));
    m_db.setDatabaseName(path);

    if (!m_db.open()) {
        qWarning("ProcessHelper: failed to open DB: %s", qPrintable(m_db.lastError().text()));
        return;
    }

    // Enable WAL mode + foreign keys
    QSqlQuery q(m_db);
    q.exec(QStringLiteral("PRAGMA journal_mode=WAL"));
    q.exec(QStringLiteral("PRAGMA foreign_keys=ON"));

    // Schema — idempotent
    q.exec(QStringLiteral(
        "CREATE TABLE IF NOT EXISTS results ("
        "  id         INTEGER PRIMARY KEY AUTOINCREMENT,"
        "  engine     TEXT    NOT NULL,"
        "  input_text TEXT    NOT NULL,"
        "  result     TEXT    NOT NULL,"
        "  created_at TEXT    NOT NULL DEFAULT (datetime('now','localtime'))"
        ")"
    ));
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

void ProcessHelper::closeDb()
{
    if (m_db.isOpen()) {
        m_db.close();
        m_db = QSqlDatabase();
    }
}

QString ProcessHelper::exec(const QString &sql, const QString &jsonParams)
{
    if (!m_db.isOpen()) {
        qWarning("ProcessHelper::exec: DB not open. Call initDb() first.");
        return QString();
    }

    QSqlQuery q(m_db);
    if (!q.prepare(sql)) {
        qWarning("ProcessHelper::exec: prepare failed: %s", qPrintable(q.lastError().text()));
        return QString();
    }

    // Bind positional parameters from JSON array
    QJsonArray params = QJsonDocument::fromJson(jsonParams.toUtf8()).array();
    for (int i = 0; i < params.size(); ++i) {
        const QJsonValue &v = params.at(i);
        if (v.isString())
            q.bindValue(i, v.toString());
        else if (v.isDouble())
            q.bindValue(i, v.toDouble());
        else if (v.isBool())
            q.bindValue(i, v.toBool() ? 1 : 0);
        else if (v.isNull())
            q.bindValue(i, QVariant(QMetaType::fromType<QVariant>()));
        else
            q.bindValue(i, v.toVariant());
    }

    if (!q.exec()) {
        qWarning("ProcessHelper::exec: exec failed: %s", qPrintable(q.lastError().text()));
        return QString();
    }

    // SELECT → JSON array of row objects
    if (!q.isSelect())
        return QStringLiteral("[]");

    QJsonArray rows;
    while (q.next()) {
        QJsonObject row;
        for (int i = 0; i < q.record().count(); ++i) {
            QString name = q.record().fieldName(i);
            QVariant val = q.value(i);
            if (val.isNull())
                row[name] = QJsonValue::Null;
            else if (val.metaType().id() == QMetaType::Int || val.metaType().id() == QMetaType::LongLong)
                row[name] = val.toLongLong();
            else if (val.metaType().id() == QMetaType::Double)
                row[name] = val.toDouble();
            else
                row[name] = val.toString();
        }
        rows.append(row);
    }

    return QString::fromUtf8(QJsonDocument(rows).toJson(QJsonDocument::Compact));
}
