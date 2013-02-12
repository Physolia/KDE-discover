/***************************************************************************
 *   Copyright © 2011 Jonathan Thomas <echidnaman@kubuntu.org>             *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or         *
 *   modify it under the terms of the GNU General Public License as        *
 *   published by the Free Software Foundation; either version 2 of        *
 *   the License or (at your option) version 3 or any later version        *
 *   accepted by the membership of KDE e.V. (or its successor approved     *
 *   by the membership of KDE e.V.), which shall act as a proxy            *
 *   defined in Section 14 of version 3 of the license.                    *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License for more details.                          *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   along with this program.  If not, see <http://www.gnu.org/licenses/>. *
 ***************************************************************************/

#include "ProgressWidget.h"

// Qt includes
#include <QtCore/QParallelAnimationGroup>
#include <QtCore/QPropertyAnimation>
#include <QtCore/QStringBuilder>
#include <QDebug>
#include <QtGui/QLabel>
#include <QtGui/QProgressBar>
#include <QtGui/QPushButton>
#include <QtGui/QVBoxLayout>

// KDE includes
#include <KGlobal>
#include <KIcon>
#include <KLocale>
#include <KMessageBox>

#include <resources/AbstractBackendUpdater.h>
#include <resources/ResourcesUpdatesModel.h>

ProgressWidget::ProgressWidget(QWidget *parent)
    : QWidget(parent)
    , m_updater(nullptr)
    , m_lastRealProgress(0)
    , m_show(false)
{
    QVBoxLayout *mainLayout = new QVBoxLayout(this);
    mainLayout->setMargin(0);

    m_headerLabel = new QLabel(this);
    m_progressBar = new QProgressBar(this);

    QWidget *widget = new QWidget(this);
    QHBoxLayout *layout = new QHBoxLayout(widget);
    widget->setLayout(layout);

    m_cancelButton = new QPushButton(widget);
    m_cancelButton->setText(i18nc("@action:button Cancels the download", "Cancel"));
    m_cancelButton->setIcon(KIcon("dialog-cancel"));

    layout->addWidget(m_progressBar);
    layout->addWidget(m_cancelButton);

    m_detailsLabel = new QLabel(this);

    mainLayout->addWidget(m_headerLabel);
    mainLayout->addWidget(widget);
    mainLayout->addWidget(m_detailsLabel);

    setLayout(mainLayout);

    int finalHeight = sizeHint().height() + 20;

    QPropertyAnimation *anim1 = new QPropertyAnimation(this, "maximumHeight", this);
    anim1->setDuration(500);
    anim1->setEasingCurve(QEasingCurve::OutQuart);
    anim1->setStartValue(0);
    anim1->setEndValue(finalHeight);

    QPropertyAnimation *anim2 = new QPropertyAnimation(this, "minimumHeight", this);
    anim2->setDuration(500);
    anim2->setEasingCurve(QEasingCurve::OutQuart);
    anim2->setStartValue(0);
    anim2->setEndValue(finalHeight);

    m_expandWidget = new QParallelAnimationGroup(this);
    m_expandWidget->addAnimation(anim1);
    m_expandWidget->addAnimation(anim2);
}

void ProgressWidget::setTransaction(ResourcesUpdatesModel* updates)
{
    m_updater = updates;

    // Connect the transaction all up to our slots
    connect(m_updater, SIGNAL(progressChanged()),
            this, SLOT(updateProgress()));
    connect(m_updater, SIGNAL(downloadSpeedChanged()),
            this, SLOT(downloadSpeedChanged()));
    connect(m_updater, SIGNAL(etaChanged()), SLOT(etaChanged()));
    connect(m_updater, SIGNAL(cancelableChanged()), SLOT(cancelChanged()));
    connect(m_updater, SIGNAL(statusMessageChanged(QString)),
            m_headerLabel, SLOT(setText(QString)));
    connect(m_updater, SIGNAL(statusDetailChanged(QString)),
            m_detailsLabel, SLOT(setText(QString)));
    connect(m_updater, SIGNAL(progressingChanged()),
            SLOT(updateIsProgressing()));

//     m_headerLabel->setText(m_updater->statusMessage());
//     m_detailsLabel->setText(m_updater->statusDetail());
    
    cancelChanged();
    connect(m_cancelButton, SIGNAL(clicked()), m_updater, SLOT(cancel()));
}

void ProgressWidget::updateIsProgressing()
{
    m_progressBar->setMaximum(m_updater->isProgressing() ? 100 : 0);
}

void ProgressWidget::updateProgress()
{
    qreal progress = m_updater->progress();
    if (progress > 100 || progress<0) {
        m_progressBar->setMaximum(0);
    } else if (progress > m_lastRealProgress) {
        m_progressBar->setMaximum(100);
        m_progressBar->setValue(progress);
        m_lastRealProgress = progress;
    }
}

void ProgressWidget::downloadSpeedChanged()
{
    quint64 speed = m_updater->downloadSpeed();
    QString downloadSpeed = i18nc("@label Download rate", "Download rate: %1/s",
                              KGlobal::locale()->formatByteSize(speed));
    m_detailsLabel->setText(downloadSpeed);
}

void ProgressWidget::etaChanged()
{
    m_detailsLabel->setText(m_updater->remainingTime());
}

void ProgressWidget::show()
{
    QWidget::show();

    if (!m_show) {
        m_show = true;
        // Disconnect from previous animatedHide(), else we'll hide once we finish showing
        disconnect(m_expandWidget, SIGNAL(finished()), this, SLOT(hide()));
        m_expandWidget->setDirection(QAbstractAnimation::Forward);
        m_expandWidget->start();
    }
}

void ProgressWidget::animatedHide()
{
    m_show = false;

    m_expandWidget->setDirection(QAbstractAnimation::Backward);
    m_expandWidget->start();
    connect(m_expandWidget, SIGNAL(finished()), this, SLOT(hide()));
    connect(m_expandWidget, SIGNAL(finished()), m_cancelButton, SLOT(show()));
}

void ProgressWidget::cancelChanged()
{
    m_cancelButton->setEnabled(m_updater->isCancelable());
}
