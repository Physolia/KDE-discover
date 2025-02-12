/*
 *   SPDX-FileCopyrightText: 2012 Aleix Pol Gonzalez <aleixpol@blue-systems.com>
 *   SPDX-FileCopyrightText: 2021 Carl Schwan <carlschwan@kde.org>
 *   SPDX-FileCopyrightText: 2023 ivan tkachenko <me@ratijas.tk>
 *
 *   SPDX-License-Identifier: LGPL-2.0-or-later
 */

import QtQuick 2.1
import QtQuick.Controls 2.1
import QtQuick.Layouts 1.1
import QtQuick.Window 2.1
import "navigation.js" as Navigation
import org.kde.kirigami 2.6 as Kirigami

BasicAbstractCard {
    showClickFeedback: true

    // Don't let RowLayout affect parent GridLayout's decisions, or else it
    // would resize cells proportionally to their label text length.
    implicitWidth: 0

    content: RowLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.largeSpacing

        Kirigami.Icon {
            Layout.alignment: Qt.AlignVCenter
            Layout.margins: Kirigami.Units.largeSpacing
            implicitWidth: Kirigami.Units.iconSizes.huge
            implicitHeight: Kirigami.Units.iconSizes.huge
            source: model.application.icon
            animated: false
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Kirigami.Heading {
                id: head
                level: 2
                type: Kirigami.Heading.Type.Primary
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignBottom
                wrapMode: Text.WordWrap
                maximumLineCount: 2

                text: model.application.name
            }

            Label {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                maximumLineCount: head.lineCount === 1 ? 3 : 2
                opacity: 0.6
                wrapMode: Text.WordWrap

                text: model.application.comment
            }
        }
    }

    onClicked: Navigation.openApplication(model.application)
}
