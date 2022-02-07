/*
 *   SPDX-FileCopyrightText: 2015 Aleix Pol Gonzalez <aleixpol@blue-systems.com>
 *   SPDX-FileCopyrightText: 2021 Felipe Kinoshita <kinofhek@gmail.com>
 *
 *   SPDX-License-Identifier: LGPL-2.0-or-later
 */

import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtGraphicalEffects 1.12
import QtQuick.Layouts 1.15
import QtQml.Models 2.15
import org.kde.discover 2.0
import org.kde.discover.app 1.0
import "navigation.js" as Navigation
import org.kde.kirigami 2.19 as Kirigami

DiscoverPage {
    id: page
    title: i18n("Featured")
    objectName: "featured"

    actions.main: window.wideScreen ? searchAction : null

    readonly property bool isHome: true

    function searchFor(text) {
        if (text.length === 0)
            return;
        Navigation.openCategory(null, "")
    }

    FeaturedModel {
        id: featuredModel
    }

    component FeaturedDelegate: QQC2.AbstractButton {
        id: control

        hoverEnabled: true

        background: Kirigami.ShadowedRectangle {
            implicitWidth: Kirigami.Units.gridUnit * 15
            implicitHeight: featuredCategory.headerItem.height - (Kirigami.Units.largeSpacing * 4)
            color: {
                if (control.down || control.highlighted) {
                    return Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.3);
                } else if (control.hovered) {
                    return Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.25);
                } else {
                    return Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.2);
                }
            }
            border.width: 1
            border.color: {
                if (control.down || control.highlighted) {
                    return Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.9);
                } else if (parent.hovered) {
                    return Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.85);
                } else {
                    return Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.8);
                }
            }
            radius: 3

            shadow {
                size: Kirigami.Units.largeSpacing
                color: Qt.rgba(0, 0, 0, 0.2)
                yOffset: 2
            }
        }

        contentItem: ColumnLayout {
            spacing: 0

            Kirigami.Icon {
                Layout.preferredWidth: Kirigami.Units.iconSizes.huge
                Layout.preferredHeight: Kirigami.Units.iconSizes.huge
                Layout.topMargin: Kirigami.Units.largeSpacing * 2
                Layout.alignment: Qt.AlignCenter
                source: model.applicationObject.icon
            }

            Kirigami.Heading {
                Layout.alignment: Qt.AlignCenter
                text: model.applicationObject.name
            }

            Item {
                Layout.fillHeight: true
            }

            QQC2.Label {
                id: label
                Layout.fillWidth: true
                width: control.width
                Layout.alignment: Qt.AlignLeft | Qt.AlignBottom
                Layout.leftMargin: Kirigami.Units.largeSpacing * 2
                Layout.rightMargin: Kirigami.Units.largeSpacing * 2
                text: model.applicationObject.comment
                elide: Text.ElideRight
                horizontalAlignment: Qt.AlignLeft
                maximumLineCount: 2
                wrapMode: Text.WrapAnywhere
            }

            QQC2.Label {
                Layout.alignment: Qt.AlignLeft | Qt.AlignBottom
                Layout.topMargin: Kirigami.Units.largeSpacing
                Layout.bottomMargin: Kirigami.Units.largeSpacing * 2
                Layout.leftMargin: Kirigami.Units.largeSpacing * 2
                text: model.applicationObject.categoryDisplay
                elide: Text.ElideRight
                opacity: 0.5
            }
        }

        onClicked: Navigation.openApplication(model.applicationObject)
    }

    component CategoryDelegate: ColumnLayout {
        id: control

        spacing: Kirigami.Units.largeSpacing

        Kirigami.Heading {
            Layout.alignment: Qt.AlignLeft | Qt.AlignTop
            Layout.topMargin: Kirigami.Units.gridUnit * 2
            Layout.leftMargin: Kirigami.Units.largeSpacing
            text: categoryName
        }
        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignLeft | Qt.AlignTop
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing

            columns: window.wideScreen ? 3 : 1
            rows: window.wideScreen ? 3 : 9

            rowSpacing: Kirigami.Units.largeSpacing
            columnSpacing: Kirigami.Units.largeSpacing

            Repeater {
                model: DelegateModel {
                    model: featuredModel
                    rootIndex: modelIndex(index)
                    delegate: Kirigami.AbstractCard {
                        id: delegateArea
                        showClickFeedback: true

                        Layout.minimumWidth: Kirigami.Units.gridUnit * 15

                        contentItem: Item {
                            implicitHeight: Kirigami.Units.gridUnit * 3

                            Kirigami.Icon {
                                id: resourceIcon
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                width: Kirigami.Units.iconSizes.large
                                height: width
                                source: model.applicationObject.icon
                            }

                            RowLayout {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.right: parent.right
                                anchors.left: resourceIcon.right
                                anchors.leftMargin: Kirigami.Units.largeSpacing

                                ColumnLayout {
                                    spacing: 0

                                    Kirigami.Heading {
                                        Layout.fillWidth: true
                                        text: model.applicationObject.name
                                        level: 2
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                    }

                                    RowLayout {
                                        Rating {
                                            Layout.alignment: Qt.AlignVCenter
                                            rating: model.applicationObject.rating ? model.applicationObject.rating.sortableRating : 0
                                            starSize: Kirigami.Units.largeSpacing * 1.5
                                        }
                                        QQC2.Label {
                                            Layout.alignment: Qt.AlignVCenter
                                            text: model.applicationObject.rating ? i18np("%1 rating", "%1 ratings", model.applicationObject.rating.ratingCount) : i18n("No ratings yet")
                                            visible: model.applicationObject.rating || model.applicationObject.backend.reviewsBackend.isResourceSupported(model.applicationObject)
                                            opacity: 0.5
                                            elide: Text.ElideRight
                                        }
                                    }

                                    QQC2.Label {
                                        Layout.fillWidth: true
                                        Layout.topMargin: Kirigami.Units.smallSpacing
                                        text: model.applicationObject.comment
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                        textFormat: Text.PlainText
                                    }
                                }

                                QQC2.Button {
                                    TransactionListener {
                                        id: listener
                                    }

                                    Layout.alignment: Qt.AlignRight
                                    Layout.leftMargin: Kirigami.Units.largeSpacing
                                    icon.name: model.applicationObject.isInstalled ? "edit-delete" : "download"
                                    onClicked: {
                                        if (!listener.isActive) {
                                            if(application.isInstalled)
                                                ResourcesModel.removeApplication(application);
                                            else
                                                ResourcesModel.installApplication(application);
                                        } else {
                                            console.warn("trying to un/install but resource still active", model.applicationObject.name)
                                        }
                                    }
                                }
                            }
                        }

                        onClicked: Navigation.openApplication(model.applicationObject)
                    }
                }
            }
        }
        QQC2.Button {
            Layout.alignment: Qt.AlignLeft | Qt.AlignTop
            Layout.leftMargin: Kirigami.Units.largeSpacing
            text: i18n("See More…")
//             onClicked: Navigation.openCategory(model.applicationObject.category, "")
        }
    }

    signal clearSearch()

    ListView {
        id: featuredCategory
        anchors.fill: parent

        header: QQC2.Control {
            width: featuredCategory.width
            height: Kirigami.Units.gridUnit * 15
            contentItem: ListView {
                width: featuredCategory.width
                interactive: contentWidth > width
                orientation: ListView.Horizontal
                currentIndex: -1
                snapMode: ListView.SnapToItem
                model: featuredModel.specialApps
                spacing: Kirigami.Units.largeSpacing
                delegate: FeaturedDelegate {
                    width: Kirigami.Units.gridUnit * 15
                }
            }
        }

        model: featuredModel
        delegate: CategoryDelegate {
            width: featuredCategory.width > 1000 ? 1000 : featuredCategory.width
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Kirigami.PlaceholderMessage {
            anchors.centerIn: parent
            visible: featuredCategory.count === 0 && featuredCategory.model.isFetching
            text: i18n("Loading")
            QQC2.BusyIndicator {
                Layout.alignment: Qt.AlignHCenter
                running: visible
                opacity: 0.5
            }
        }

        Loader {
            active: featuredCategory.count === 0 && !featuredCategory.model.isFetching
            anchors.centerIn: parent
            width: parent.width - (Kirigami.Units.largeSpacing * 4)
            sourceComponent: Kirigami.PlaceholderMessage {
                readonly property var helpfulError: appsRep.model.currentApplicationBackend.explainDysfunction()
                icon.name: helpfulError.iconName
                text: i18n("Unable to load applications")
                explanation: helpfulError.errorMessage

                Repeater {
                    model: helpfulError.actions
                    delegate: QQC2.Button {
                        Layout.alignment: Qt.AlignHCenter
                        action: ConvertDiscoverAction {
                            action: modelData
                        }
                    }
                }
            }
        }
    }

    footer: ColumnLayout {
        spacing: 0

        Kirigami.Separator {
            Layout.fillWidth: true
            visible: Kirigami.Settings.isMobile && inlineMessage.visible
        }

        Kirigami.InlineMessage {
            id: inlineMessage
            icon.name: updateAction.icon.name
            showCloseButton: true
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.largeSpacing * 2
            text: i18n("Updates are available")
            visible: Kirigami.Settings.isMobile && ResourcesModel.updatesCount > 0
            actions: Kirigami.Action {
                icon.name: "go-next"
                text: i18nc("Short for 'show updates'", "Show")
                onTriggered: updateAction.trigger()
            }
        }
    }
}
