/*
 *   SPDX-FileCopyrightText: 2013 Lukas Appelhans <l.appelhans@gmx.de>
 *   SPDX-FileCopyrightText: 2015 Aleix Pol Gonzalez <aleixpol@blue-systems.com>
 *
 *   SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 */

#include "PackageKitNotifier.h"

#include <KConfigGroup>
#include <KDesktopFile>
#include <KLocalizedString>
#include <KNotification>
#include <PackageKit/Daemon>
#include <PackageKit/Offline>
#include <QDBusInterface>
#include <QDebug>
#include <QFile>
#include <QFileSystemWatcher>
#include <QProcess>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QTextStream>
#include <QTimer>

#include <AppStreamQt/pool.h>
#include <AppStreamQt/release.h>
#include <appstream/AppStreamIntegration.h>

#include "libdiscover_backend_debug.h"
#include "pk-offline-private.h"

using namespace std::chrono_literals;

PackageKitNotifier::PackageKitNotifier(QObject *parent)
    : BackendNotifierModule(parent)
    , m_securityUpdates(0)
    , m_normalUpdates(0)
    , m_hasDistUpgrade(false)
    , m_appdata(new AppStream::Pool)
{
    connect(PackageKit::Daemon::global(), &PackageKit::Daemon::updatesChanged, this, &PackageKitNotifier::recheckSystemUpdateNeeded);
    connect(PackageKit::Daemon::global(), &PackageKit::Daemon::transactionListChanged, this, &PackageKitNotifier::transactionListChanged);
    connect(PackageKit::Daemon::global(), &PackageKit::Daemon::restartScheduled, this, &PackageKitNotifier::nowNeedsReboot);
    connect(PackageKit::Daemon::global()->offline(), &PackageKit::Offline::changed, this, [this] {
        if (auto offline = PackageKit::Daemon::global()->offline(); offline->updateTriggered() || offline->upgradeTriggered())
            nowNeedsReboot();
    });

    m_appdata->load();

    // Check if there's packages after 5'
    QTimer::singleShot(5min, this, &PackageKitNotifier::refreshDatabase);

    QTimer *regularCheck = new QTimer(this);
    connect(regularCheck, &QTimer::timeout, this, &PackageKitNotifier::refreshDatabase);

    const QString aptconfig = QStandardPaths::findExecutable(QStringLiteral("apt-config"));
    if (!aptconfig.isEmpty()) {
        checkAptVariable(aptconfig, QLatin1String("Apt::Periodic::Update-Package-Lists"), [regularCheck](const QStringView &value) {
            bool ok;
            const int days = value.toInt(&ok);
            if (!ok || days == 0) {
                regularCheck->setInterval(24h); // refresh at least once every day
                regularCheck->start();
                if (!value.isEmpty())
                    qWarning() << "couldn't understand value for timer:" << value;
            }

            // if the setting is not empty, refresh will be carried out by unattended-upgrade
            // https://wiki.debian.org/UnattendedUpgrades
        });
    } else {
        regularCheck->setInterval(24h); // refresh at least once every day
        regularCheck->start();
    }

    QTimer::singleShot(3s, this, &PackageKitNotifier::checkOfflineUpdates);

    m_recheckTimer = new QTimer(this);
    m_recheckTimer->setInterval(200);
    m_recheckTimer->setSingleShot(true);
    connect(m_recheckTimer, &QTimer::timeout, this, &PackageKitNotifier::recheckSystemUpdate);

    QFileSystemWatcher *watcher = new QFileSystemWatcher(this);
    watcher->addPath(QStringLiteral(PK_OFFLINE_ACTION_FILENAME));
    connect(watcher, &QFileSystemWatcher::fileChanged, this, &PackageKitNotifier::nowNeedsReboot);

    QTimer::singleShot(100, this, [this]() {
        if (QFile::exists(QStringLiteral(PK_OFFLINE_ACTION_FILENAME)))
            nowNeedsReboot();
    });
}

PackageKitNotifier::~PackageKitNotifier()
{
}

void PackageKitNotifier::checkOfflineUpdates()
{
    if (!QFile::exists(QStringLiteral(PK_OFFLINE_RESULTS_FILENAME))) {
        return;
    }
    qCDebug(LIBDISCOVER_BACKEND_LOG) << "found offline update results at " << PK_OFFLINE_RESULTS_FILENAME;

    KDesktopFile file(QStringLiteral(PK_OFFLINE_RESULTS_FILENAME));
    KConfigGroup group(&file, PK_OFFLINE_RESULTS_GROUP);

    const bool success = group.readEntry("Success", false);
    const QString packagesJoined = group.readEntry("Packages");
    const auto packages = QStringView(packagesJoined).split(QLatin1Char(','));
    const bool isMobile = QByteArrayList{"1", "true"}.contains(qgetenv("QT_QUICK_CONTROLS_MOBILE"));
    const QString errorCode = group.readEntry("ErrorCode");
    static QSet<QString> allowedAlreadyInstalled = {
        QStringLiteral("package-already-installed"),
        QStringLiteral("all-packages-already-installed"),
    };
    if (!success && !allowedAlreadyInstalled.contains(errorCode)) {
        const QString errorDetails = group.readEntry("ErrorDetails");

        auto *notification = new KNotification(QStringLiteral("OfflineUpdateFailed"), KNotification::Persistent);
        notification->setIconName(QStringLiteral("dialog-error"));
        notification->setTitle(i18n("Failed Offline Update"));
        notification->setText(i18np("Failed to update %1 package\n%2", "Failed to update %1 packages\n%2", packages.count(), errorDetails));
        notification->setComponentName(QStringLiteral("discoverabstractnotifier"));

        auto openDiscoverAction = notification->addAction(i18nc("@action:button", "Open Discover"));
        connect(openDiscoverAction, &KNotificationAction::activated, this, [] {
            QProcess::startDetached(QStringLiteral("plasma-discover"), QStringList());
        });

        auto repairAction = notification->addAction(i18nc("@action:button", "Repair System"));
        connect(repairAction, &KNotificationAction::activated, this, [this] {
            qInfo() << "Repairing system";
            auto trans = PackageKit::Daemon::global()->repairSystem();
            KNotification::event(QStringLiteral("OfflineUpdateRepairStarted"),
                                 i18n("Repairing failed offline update"),
                                 {},
                                 KNotification::CloseOnTimeout,
                                 QStringLiteral("discoverabstractnotifier"));

            connect(trans, &PackageKit::Transaction::errorCode, this, [](PackageKit::Transaction::Error /*error*/, const QString &details) {
                KNotification::event(QStringLiteral("OfflineUpdateRepairFailed"),
                                     i18n("Repair Failed"),
                                     xi18nc("@info", "%1<nl/>Please report this error to your distribution.", details),
                                     KNotification::Persistent,
                                     QStringLiteral("discoverabstractnotifier"));
            });
            connect(trans, &PackageKit::Transaction::finished, this, [](PackageKit::Transaction::Exit status, uint runtime) {
                qInfo() << "repair finished!" << status << runtime;
                if (status == PackageKit::Transaction::ExitSuccess) {
                    PackageKit::Daemon::global()->offline()->clearResults();

                    KNotification::event(QStringLiteral("OfflineUpdateRepairSuccessful"),
                                         i18n("Repaired Successfully"),
                                         {},
                                         KNotification::CloseOnTimeout,
                                         QStringLiteral("discoverabstractnotifier"));
                }
            });

            // No matter what happened, clean up the results file if it still exists
            // because at this point, there's nothing anyone can do with it
            if (QFile::exists(QStringLiteral(PK_OFFLINE_RESULTS_FILENAME))) {
                qCDebug(LIBDISCOVER_BACKEND_LOG) << "Removed offline results file";
                PackageKit::Daemon::global()->offline()->clearResults();
            }
        });

        notification->sendEvent();
    } else {
        // Apparently on mobile, people are accustomed to seeing notifications
        // indicating success when a system update succeeded
        if (isMobile) {
            KNotification *notification = new KNotification(QStringLiteral("OfflineUpdateSuccessful"));
            notification->setIconName(QStringLiteral("system-software-update"));
            notification->setTitle(i18n("Offline Updates"));
            notification->setText(i18np("Successfully updated %1 package", "Successfully updated %1 packages", packages.count()));
            notification->setComponentName(QStringLiteral("discoverabstractnotifier"));

            auto openDiscoverAction = notification->addAction(i18nc("@action:button", "Open Discover"));
            connect(openDiscoverAction, &KNotificationAction::activated, this, []() {
                QProcess::startDetached(QStringLiteral("plasma-discover"), QStringList());
            });

            notification->sendEvent();
        }
        PackageKit::Daemon::global()->offline()->clearResults();
    }
}

void PackageKitNotifier::recheckSystemUpdateNeeded()
{
    static bool first = true;
    if (first) {
        // PKQt will Q_EMIT these signals when it starts (bug?) and would trigger the system recheck before we've ever checked at all
        connect(PackageKit::Daemon::global(), &PackageKit::Daemon::networkStateChanged, this, &PackageKitNotifier::recheckSystemUpdateNeeded);
        connect(PackageKit::Daemon::global(), &PackageKit::Daemon::isRunningChanged, this, &PackageKitNotifier::recheckSystemUpdateNeeded);
        first = false;
    }

    if (auto offline = PackageKit::Daemon::global()->offline(); offline->updateTriggered() || offline->upgradeTriggered())
        return;

    m_recheckTimer->start();
}

void PackageKitNotifier::recheckSystemUpdate()
{
    if (PackageKit::Daemon::global()->isRunning() && !PackageKit::Daemon::global()->offline()->upgradeTriggered()) {
        PackageKit::Daemon::getUpdates();
    }
}

void PackageKitNotifier::setupGetUpdatesTransaction(PackageKit::Transaction *trans)
{
    qCDebug(LIBDISCOVER_BACKEND_LOG) << "using..." << trans << trans->tid().path();

    trans->setProperty("normalUpdates", 0);
    trans->setProperty("securityUpdates", 0);
    connect(trans, &PackageKit::Transaction::package, this, &PackageKitNotifier::package);
    connect(trans, &PackageKit::Transaction::finished, this, &PackageKitNotifier::finished);
}

void PackageKitNotifier::package(PackageKit::Transaction::Info info, const QString & /*packageID*/, const QString & /*summary*/)
{
    PackageKit::Transaction *trans = qobject_cast<PackageKit::Transaction *>(sender());

    switch (info) {
    case PackageKit::Transaction::InfoBlocked:
        break; // skip, we ignore blocked updates
    case PackageKit::Transaction::InfoSecurity:
        trans->setProperty("securityUpdates", trans->property("securityUpdates").toInt() + 1);
        break;
    default:
        trans->setProperty("normalUpdates", trans->property("normalUpdates").toInt() + 1);
        break;
    }
}

void PackageKitNotifier::finished(PackageKit::Transaction::Exit /*exit*/, uint)
{
    const PackageKit::Transaction *trans = qobject_cast<PackageKit::Transaction *>(sender());

    const uint normalUpdates = trans->property("normalUpdates").toInt();
    const uint securityUpdates = trans->property("securityUpdates").toInt();
    const bool changed = normalUpdates != m_normalUpdates || securityUpdates != m_securityUpdates;

    m_normalUpdates = normalUpdates;
    m_securityUpdates = securityUpdates;

    if (changed) {
        Q_EMIT foundUpdates();
    }
}

bool PackageKitNotifier::hasUpdates()
{
    return m_normalUpdates > 0 || m_hasDistUpgrade;
}

bool PackageKitNotifier::hasSecurityUpdates()
{
    return m_securityUpdates > 0;
}

void PackageKitNotifier::checkDistroUpgrade()
{
    auto nextRelease = AppStreamIntegration::global()->getDistroUpgrade(m_appdata.get());
    if (nextRelease) {
        m_hasDistUpgrade = true;
        const QString &fullName = QStringLiteral("%1 %2").arg(AppStreamIntegration::global()->osRelease()->name(), nextRelease->version());
        auto a = new UpgradeAction(nextRelease->version(), fullName, this);
        connect(a, &UpgradeAction::triggered, this, [a](const QString &) {
            Q_EMIT a->showDiscoverUpdates();
        });
        Q_EMIT foundUpgradeAction(a);
    }
}

void PackageKitNotifier::refreshDatabase()
{
    if (auto offline = PackageKit::Daemon::global()->offline();
        offline->updatePrepared() || offline->upgradePrepared() || offline->updateTriggered() || offline->upgradeTriggered()) {
        return;
    }

    for (const auto &t : m_transactions) {
        auto role = t->role();
        if (role == PackageKit::Transaction::RoleUpdatePackages || role == PackageKit::Transaction::RoleUpgradeSystem) {
            return;
        }
    }

    if (!m_refresher) {
        m_refresher = PackageKit::Daemon::refreshCache(false);
        // Limit the cache-age so that we actually download new caches if necessary
        m_refresher->setHints(QStringLiteral("cache-age=300" /* 5 minutes */));
        connect(m_refresher.data(), &PackageKit::Transaction::finished, this, &PackageKitNotifier::recheckSystemUpdateNeeded);
    }

    if (PackageKit::Daemon::roles() & PackageKit::Transaction::RoleUpgradeSystem) {
        checkDistroUpgrade();
    }
}

QProcess *PackageKitNotifier::checkAptVariable(const QString &aptconfig, const QLatin1String &varname, const std::function<void(const QStringView &val)> &func)
{
    QProcess *process = new QProcess;
    process->start(aptconfig, {QStringLiteral("dump")});
    connect(process, &QProcess::finished, this, [func, process, varname](int code) {
        if (code != 0)
            return;

        QRegularExpression rx(QLatin1Char('^') + varname + QStringLiteral(" \"(.*?)\";?$"), QRegularExpression::CaseInsensitiveOption);
        QTextStream stream(process);
        QString line;
        while (stream.readLineInto(&line)) {
            const auto match = rx.match(line);
            if (match.hasMatch()) {
                func(match.capturedView(1));
                return;
            }
        }
        func({});
    });
    connect(process, &QProcess::finished, process, &QObject::deleteLater);
    return process;
}

void PackageKitNotifier::transactionListChanged(const QStringList &tids)
{
    if (auto offline = PackageKit::Daemon::global()->offline(); offline->updateTriggered() || offline->upgradeTriggered())
        return;

    for (const auto &tid : tids) {
        if (m_transactions.contains(tid))
            continue;

        auto t = new PackageKit::Transaction(QDBusObjectPath(tid));

        connect(t, &PackageKit::Transaction::roleChanged, this, [this, t]() {
            if (t->role() == PackageKit::Transaction::RoleGetUpdates) {
                setupGetUpdatesTransaction(t);
            }
        });
        connect(t, &PackageKit::Transaction::requireRestart, this, &PackageKitNotifier::onRequireRestart);
        connect(t, &PackageKit::Transaction::finished, this, [this, t]() {
            auto restart = t->property("requireRestart");
            if (!restart.isNull()) {
                auto restartEvent = PackageKit::Transaction::Restart(restart.toInt());
                if (restartEvent >= PackageKit::Transaction::RestartSession) {
                    nowNeedsReboot();
                }
            }
            m_transactions.remove(t->tid().path());
            t->deleteLater();
        });
        m_transactions.insert(tid, t);
    }
}

void PackageKitNotifier::nowNeedsReboot()
{
    if (!m_needsReboot) {
        m_needsReboot = true;
        Q_EMIT needsRebootChanged();
    }
}

void PackageKitNotifier::onRequireRestart(PackageKit::Transaction::Restart type, const QString &packageID)
{
    PackageKit::Transaction *t = qobject_cast<PackageKit::Transaction *>(sender());
    t->setProperty("requireRestart", qMax<int>(t->property("requireRestart").toInt(), type));
    qCDebug(LIBDISCOVER_BACKEND_LOG) << "RESTART" << type << "is required for package" << packageID;
}
