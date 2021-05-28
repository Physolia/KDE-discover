/*
 *   SPDX-FileCopyrightText: 2015 Aleix Pol Gonzalez <aleixpol@blue-systems.com>
 *   SPDX-FileCopyrightText: 2021 Carl Schwan <carlschwan@kde.org>
 *
 *   SPDX-License-Identifier: LGPL-2.0-or-later
 */

import QtQuick 2.15
import QtQuick.Controls 2.4
import QtQuick.Layouts 1.1
import QtQml.Models 2.15
import org.kde.discover 2.0
import org.kde.discover.app 1.0
import "navigation.js" as Navigation
import org.kde.kirigami 2.14 as Kirigami

DiscoverPage {
    id: page
    title: i18n("Featured")
    leftPadding: 0
    rightPadding: 0
    topPadding: 0
    bottomPadding: Kirigami.Units.largeSpacing * 2

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
        onIsFetchingChanged: if (!isFetching) {
            slidesTimer.start();
        }
    }

    ListView {
        id: featureCategory
        model: featuredModel

        header: Control {
            width: featureCategory.width
            height: Kirigami.Units.gridUnit * 12
            topPadding: Kirigami.Units.largeSpacing * 2
            contentItem:  Carousel {
                model: featuredModel.specialApps
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
                text: categoryName
            }
            Kirigami.CardsListView {
                id: apps

                readonly property int delegateWidth: Kirigami.Units.gridUnit * 15
                readonly property int itemPerRowBase: Math.floor(width / delegateWidth)
                readonly property int delegateAdditionalWidth: (((width - Kirigami.Units.largeSpacing * 2 + Kirigami.Units.smallSpacing) % delegateWidth) / itemPerRowBase - spacing) - (!window.wideScreen ? Kirigami.Units.gridUnit * 2 : 0)
                readonly property int itemPerRow: Math.floor(width / (delegateWidth + delegateAdditionalWidth))
                property int oldItemPerRow: null
                onItemPerRowChanged: {
                    if (oldItemPerRow === null) {
                        oldItemPerRow = itemPerRow;
                        return;
                    }
                    if (oldItemPerRow > itemPerRow) {
                        // HACK this is needed because otherwise we get some nasty behaviors from the
                        // ListView. (e.g SnapToItem not working, last item empty, ...)
                        currentIndex = 0;
                    } else {
                        // HACK use a timer so that all the animation don't happen at the same (very glitchy)
                        changeToIndexTimer.changeToIndex = Math.min(apps.count - itemPerRow, currentIndex)
                        changeToIndexTimer.restart();
                    }
                    oldItemPerRow = itemPerRow;
                }

                Timer {
                    id: changeToIndexTimer
                    interval: 600
                    property int changeToIndex: -1
                    onTriggered: apps.currentIndex = changeToIndex
                }

                orientation: ListView.Horizontal
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 5
                leftMargin: Kirigami.Units.largeSpacing * 2
                snapMode: ListView.SnapToItem
                highlightFollowsCurrentItem: true
                keyNavigationWraps: true
                activeFocusOnTab: true
                preferredHighlightBegin: Kirigami.Units.largeSpacing * 2
                preferredHighlightEnd: featureCategory.width - Kirigami.Units.largeSpacing * 2
                highlightRangeMode: ListView.ApplyRange
                currentIndex: 0

                // Otherwise, on deskop the list view steal the vertical wheel events
                interactive: Kirigami.Settings.hasTransientTouchInput

                // HACK: needed otherwise the listview doesn't move
                onCurrentIndexChanged: {
                    anim.running = false;

                    const pos = apps.contentX;
                    positionViewAtIndex(currentIndex, ListView.SnapPosition);
                    const destPos = apps.contentX;
                    anim.from = pos;
                    anim.to = destPos;
                    anim.running = true;
                }
                NumberAnimation { id: anim; target: apps; property: "contentX"; duration: 500 }

                RoundButton {
                    anchors {
                        left: parent.left
                        leftMargin: Kirigami.Units.largeSpacing
                        verticalCenter: parent.verticalCenter
                    }
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
                    icon.name: "arrow-right"
                    visible: hoverHandler.hovered && apps.currentIndex + apps.itemPerRow < apps.count
                    Keys.forwardTo: apps
                    onClicked: {
                        if (apps.currentIndex + apps.itemPerRow <= apps.count) {
                            apps.currentIndex += apps.itemPerRow;
                        } else {
                            apps.currentIndex = apps.count - 1;
                        }
                    }
                }

                model: DelegateModel {
                    model: featuredModel
                    rootIndex: modelIndex(index)
                    delegate: MiniApplicationDelegate {
                        implicitHeight: Kirigami.Units.gridUnit * 5
                        implicitWidth: apps.delegateWidth + apps.delegateAdditionalWidth
                        onClicked: Navigation.openApplication(model.applicationObject, true)
                    }
                }
            }
        }
    }
}
