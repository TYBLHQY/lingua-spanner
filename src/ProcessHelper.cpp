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
#include <QProcess>
#include <QSqlError>
#include <QSqlQuery>
#include <QSqlRecord>
#include <QStandardPaths>
#include <QFileInfo>

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
    // Drop legacy results table (replaced by translations below)
    q.exec(QStringLiteral("DROP TABLE IF EXISTS results"));
    q.exec(QStringLiteral(
        "CREATE TABLE IF NOT EXISTS translations ("
        "  id            TEXT    PRIMARY KEY,"
        "  input_text    TEXT    NOT NULL,"
        "  cleaned_input TEXT    NOT NULL DEFAULT '',"
        "  engine        TEXT    NOT NULL,"
        "  source_lang   TEXT    NOT NULL DEFAULT '',"
        "  target_lang   TEXT    NOT NULL DEFAULT '',"
        "  result_json   TEXT    NOT NULL DEFAULT '{}',"
        "  created_at    TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S','now'))"
        ")"
    ));

    // Migrate existing databases: INTEGER id → TEXT (UUID)
    // SQLite can't ALTER COLUMN type, so rename → recreate → copy → drop.
    {
        QSqlQuery pragmaId(m_db);
        pragmaId.exec(QStringLiteral("PRAGMA table_info(translations)"));
        bool idIsInteger = false;
        while (pragmaId.next()) {
            if (pragmaId.value(1).toString() == QLatin1String("id")
                && pragmaId.value(2).toString().contains(QLatin1String("INTEGER"))) {
                idIsInteger = true;
                break;
            }
        }
        if (idIsInteger) {
            q.exec(QStringLiteral("ALTER TABLE translations RENAME TO translations_old"));
            q.exec(QStringLiteral(
                "CREATE TABLE translations ("
                "  id            TEXT    PRIMARY KEY,"
                "  input_text    TEXT    NOT NULL,"
                "  cleaned_input TEXT    NOT NULL DEFAULT '',"
                "  engine        TEXT    NOT NULL,"
                "  source_lang   TEXT    NOT NULL DEFAULT '',"
                "  target_lang   TEXT    NOT NULL DEFAULT '',"
                "  result_json   TEXT    NOT NULL DEFAULT '{}',"
                "  created_at    TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%S','now'))"
                ")"
            ));
            q.exec(QStringLiteral(
                "INSERT INTO translations(id, input_text, cleaned_input, engine, source_lang, target_lang, result_json, created_at) "
                "SELECT CAST(id AS TEXT), input_text, cleaned_input, engine, source_lang, target_lang, result_json, created_at "
                "FROM translations_old"
            ));
            q.exec(QStringLiteral("DROP TABLE translations_old"));
        }
    }

    // Migrate existing databases that lack the cleaned_input column
    QSqlQuery pragma(q);
    pragma.exec(QStringLiteral("PRAGMA table_info(translations)"));
    bool hasCleanedInput = false;
    while (pragma.next()) {
        if (pragma.value(1).toString() == QLatin1String("cleaned_input")) {
            hasCleanedInput = true;
            break;
        }
    }
    if (!hasCleanedInput) {
        q.exec(QStringLiteral("ALTER TABLE translations ADD COLUMN cleaned_input TEXT NOT NULL DEFAULT ''"));
    }
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

    // Finished (normal exit or crash)
    connect(m_process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
        this, [this](int exitCode, QProcess::ExitStatus status) {
            QString stdOut = QString::fromUtf8(m_process->readAllStandardOutput());
            QString stdErr = QString::fromUtf8(m_process->readAllStandardError());
            if (status == QProcess::CrashExit) {
                emit commandError(QStringLiteral("Process crashed (exit code %1)").arg(exitCode));
            } else {
                emit commandFinished(exitCode, stdOut.trimmed(), stdErr.trimmed());
            }
            m_process->deleteLater();
            m_process = nullptr;
        });

    // Failed to start, timed out, etc.
    connect(m_process, &QProcess::errorOccurred,
        this, [this, command](QProcess::ProcessError error) {
            QString msg;
            switch (error) {
            case QProcess::FailedToStart:
                msg = command + QStringLiteral(": command not found or failed to start.\nPlease install: pip install edge-tts");
                break;
            case QProcess::Timedout:
                msg = QStringLiteral("Command timed out");
                break;
            default:
                msg = QStringLiteral("Process error: %1").arg(static_cast<int>(error));
                break;
            }
            emit commandError(msg);
            m_process->deleteLater();
            m_process = nullptr;
        });

    m_process->start(command, args);
}

void ProcessHelper::cancelCommand()
{
    if (m_process && m_process->state() != QProcess::NotRunning) {
        m_process->kill();
        m_process->waitForFinished(3000);
    }
}

bool ProcessHelper::fileExists(const QString &filePath) const
{
    return QFileInfo::exists(filePath);
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
