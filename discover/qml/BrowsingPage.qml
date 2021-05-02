/*
 *   SPDX-FileCopyrightText: 2015 Aleix Pol Gonzalez <aleixpol@blue-systems.com>
 *
 *   SPDX-License-Identifier: LGPL-2.0-or-later
 */

import QtQuick 2.15
import QtGraphicalEffects 1.12
import QtQuick.Controls 2.4
import QtQuick.Layouts 1.1
import QtQml.Models 2.15
import org.kde.discover 2.0
import org.kde.discover.app 1.0
import "navigation.js" as Navigation
import org.kde.kirigami 2.14 as Kirigami

DiscoverPage
{
    id: page
    title: i18n("Featured")
    leftPadding: 0
    rightPadding: 0
    topPadding: 0
    bottomPadding: 0

    actions.main: searchAction

    readonly property bool isHome: true

    function searchFor(text) {
        if (text.length === 0)
            return;
        Navigation.openCategory(null, "")
    }

    ColumnLayout {
        anchors.centerIn: parent
        opacity: 0.5

        visible: featureCategory.count === 0 && featureCategory.model.isFetching

        Kirigami.Heading {
            level: 2
            Layout.alignment: Qt.AlignCenter
            text: i18n("Loading…")
        }
        BusyIndicator {
            id: indicator
            Layout.alignment: Qt.AlignCenter
            Layout.preferredWidth: Kirigami.Units.gridUnit * 4
            Layout.preferredHeight: Kirigami.Units.gridUnit * 4
        }
    }

    Kirigami.PlaceholderMessage {
        anchors.centerIn: parent
        width: parent.width - (Kirigami.Units.largeSpacing * 4)

        visible: featureCategory.count === 0 && !featureCategory.model.isFetching

        icon.name: "network-disconnect"
        text: i18n("Unable to load applications")
        explanation: i18n("Please verify Internet connectivity")
    }

    signal clearSearch()

    readonly property bool compact: page.width < 550 || !applicationWindow().wideScreen

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

    FeaturedModel {
        id: featuredModel
    }

    ListView {
        id: featureCategory
        model: featuredModel

        header: Control {
            width: featureCategory.width
            height: Kirigami.Units.gridUnit * 10
            topPadding: Kirigami.Units.largeSpacing * 2
            contentItem: PathView {
                id: pathView
                readonly property bool itemIsWide: pathView.width / 3 > Kirigami.Units.gridUnit * 14
                /// Item width on small scren: only show one item fully and partially the left and right item
                // (Kirigami.Units.gridUnit * 2 for each item)
                readonly property int itemWidthSmall: width - smallExternalMargins * 2

                /// Item width on large screen: e.g. 3 item always displayed
                readonly property int itemWidthLarge: pathView.width / 3

                readonly property int smallExternalMargins: width > Kirigami.Units.gridUnit * 25 ? Kirigami.Units.gridUnit * 4 : Kirigami.Units.gridUnit * 2
                pathItemCount: itemIsWide ? 5 : 3
                model: ListModel {
                    ListElement {
                        name: "Kate"
                        description: "Get an Edge in Editing"
                        gradientStart: "#00d2ff";
                        gradientEnd: "#3a47d5";
                    }
                    ListElement {
                        name: "KDevelop"
                        gradientStart: "#01d486";
                        gradientEnd: "#3daee8";
                    }
                    ListElement {
                        name: "KDenlive"
                        gradientStart: "#E93A9A";
                        gradientEnd: "#EF973C";
                        colorName: "green"
                    }
                    ListElement {
                        name: "Krita"
                        colorName: "yellow"
                        gradientStart: "#00d2ff";
                        gradientEnd: "#3a47d5";
                    }
                    ListElement {
                        colorName: "orange"
                        gradientStart: "#00d2ff";
                        gradientEnd: "#3a47d5";
                    }
                }
                preferredHighlightBegin: 0.5
                preferredHighlightEnd: 0.5
                highlightRangeMode: PathView.StrictlyEnforceRange
                delegate: Rectangle {
                    width: (pathView.itemIsWide ? pathView.itemWidthLarge : pathView.itemWidthSmall) - Kirigami.Units.gridUnit * 2
                    x: Kirigami.Units.gridUnit
                    height: PathView.view.height
                    color: model.colorName
                    radius: Kirigami.Units.largeSpacing
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: model.gradientStart}
                        GradientStop { position: 1.0; color: model.gradientEnd}
                    }
                    Kirigami.Heading {
                        anchors.centerIn: parent
                        text: name
                    }
                }
                path: Path {
                    startX: pathView.itemIsWide ? (-pathView.width / 3) : (-pathView.itemWidthSmall + pathView.smallExternalMargins)
                    startY: pathView.height/2
                    PathLine {
                        x: pathView.width / 2
                        y: pathView.height / 2
                    }
                    PathLine {
                        x: pathView.itemIsWide ? pathView.width * 4 / 3 : (pathView.width + pathView.itemWidthSmall - pathView.smallExternalMargins)
                        y: pathView.height / 2
                    }
                }
            }
        }

        delegate: ColumnLayout {
            width: featureCategory.width

            HoverHandler {
                id: hoverHandler
            }
            Kirigami.Heading {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.gridUnit
                Layout.leftMargin: Kirigami.Units.gridUnit
                text: categoryName + " " + apps.currentIndex + " " + apps.currentItem.text
            }
            Kirigami.CardsListView {
                id: apps
                orientation: ListView.Horizontal
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 5
                Component.onCompleted: apps.leftMargin = Kirigami.Units.largeSpacing * 2
                snapMode: ListView.SnapToItem
                highlightRangeMode: ListView.ApplyRange
                highlightFollowsCurrentItem: true
                keyNavigationWraps: true
                activeFocusOnTab: true
                currentIndex: 0
                readonly property int delegateWidth: Kirigami.Units.gridUnit * 13
                readonly property int itemPerRow: Math.floor(width / Kirigami.Units.gridUnit / 13)
                readonly property int delegateAdditionaWidth: ((width - Kirigami.Units.largeSpacing * 2) % delegateWidth) / itemPerRow - spacing

                // On desktop otherwise it stealh the whell events
                interactive: Kirigami.Settings.isMobile

                RoundButton {
                    anchors {
                        left: parent.left
                        leftMargin: Kirigami.Units.largeSpacing
                        verticalCenter: parent.verticalCenter
                    }
                    width: Kirigami.Units.gridUnit * 2
                    height: width
                    icon.name: "arrow-left"
                    activeFocusOnTab: false
                    visible: hoverHandler.hovered && apps.currentIndex > 0
                    Keys.forwardTo: apps
                    onClicked: {
                        if (apps.currentIndex >= apps.itemPerRow) {
                            apps.currentIndex -= apps.itemPerRow;
                        } else {
                            apps.currentIndex = 0;
                        }
                    }
                }

                RoundButton {
                    anchors {
                        right: parent.right
                        rightMargin: Kirigami.Units.largeSpacing
                        verticalCenter: parent.verticalCenter
                    }
                    activeFocusOnTab: false
                    width: Kirigami.Units.gridUnit * 2
                    height: width
                    icon.name: "arrow-right"
                    visible: hoverHandler.hovered && apps.currentIndex + apps.itemPerRow < apps.count
                    Keys.forwardTo: apps
                    onClicked: if (apps.currentIndex + apps.itemPerRow <= apps.count) {
                        apps.currentIndex += apps.itemPerRow;
                    } else {
                        apps.currentIndex = apps.count - 1;
                    }
                }

                model: DelegateModel {
                    model: featuredModel
                    rootIndex: modelIndex(index)
                    delegate: MiniApplicationDelegate {
                        implicitHeight: Kirigami.Units.gridUnit * 5
                        implicitWidth: apps.delegateWidth + apps.delegateAdditionaWidth
                        application: applicationObject
                    }
                }
            }
        }
    }
}
