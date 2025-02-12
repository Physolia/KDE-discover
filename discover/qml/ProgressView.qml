import QtQuick 2.1
import QtQuick.Controls 2.1
import QtQuick.Layouts 1.1
import org.kde.discover 2.0
import org.kde.kirigami 2.14 as Kirigami

ItemDelegate {
    id: listItem

    contentItem: ColumnLayout {
        Label {
            id: label
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.iconSizes.smallMedium + (LayoutMirroring.enabled ? listItem.rightPadding : listItem.leftPadding)
            Layout.rightMargin: Layout.leftMargin
            text: TransactionModel.count ? i18n("Tasks (%1%)", TransactionModel.progress) : i18n("Tasks")
        }
        ProgressBar {
            Layout.fillWidth: true
            value: TransactionModel.progress / 100
        }
    }
    visible: TransactionModel.count > 0

    property Kirigami.OverlaySheet sheetObject: null
    onClicked: {
        if (!sheetObject) {
            sheetObject = sheet.createObject()
        }

        if (!sheetObject.visible) {
            sheetObject.open()
        }
    }

    readonly property var v3: Component {
        id: sheet
        Kirigami.OverlaySheet {
            parent: applicationWindow().overlay

            title: i18n("Tasks")

            onVisibleChanged: if(!visible) {
                sheetObject.destroy(100)
            }

            ListView {
                id: tasksView
                spacing: 0
                implicitWidth: Kirigami.Units.gridUnit * 30

                Component {
                    id: listenerComp
                    TransactionListener {}
                }
                model: TransactionModel

                Connections {
                    target: TransactionModel
                    function onRowsRemoved() {
                        if (TransactionModel.count === 0) {
                            sheetObject.close();
                        }
                    }
                }

                delegate: ItemDelegate {
                    id: del

                    readonly property QtObject listener: listenerComp.createObject(del,
                        (model.transaction.resource
                            ? { resource: model.transaction.resource }
                            : { transaction: model.transaction }))

                    width: tasksView.width

                    // Don't need a highlight or hover effects as it can make the
                    // progress bar a bit hard to see
                    highlighted: false
                    hoverEnabled: false
                    down: false

                    contentItem: ColumnLayout {
                        RowLayout {
                            Layout.fillWidth: true

                            Kirigami.Icon {
                                Layout.fillHeight: true
                                Layout.minimumWidth: height
                                source: model.transaction.icon
                            }

                            Label {
                                Layout.alignment: Qt.AlignVCenter
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                text: listener.isActive && model.transaction.remainingTime > 0 ? i18nc("TransactioName - TransactionStatus: speed, remaining time", "%1 - %2: %3, %4 remaining", model.transaction.name, listener.statusText, model.transaction.downloadSpeedString, model.transaction.remainingTime) :
                                      listener.isActive && model.transaction.downloadSpeed > 0 ? i18nc("TransactioName - TransactionStatus: speed", "%1 - %2: %3", model.transaction.name, listener.statusText, model.transaction.downloadSpeedString) :
                                                                             listener.isActive ? i18nc("TransactioName - TransactionStatus", "%1 - %2", model.transaction.name, listener.statusText)
                                                                                               : model.transaction.name
                            }
                            ToolButton {
                                icon.name: "dialog-cancel"
                                text: i18n("Cancel")
                                visible: listener.isCancellable
                                onClicked: listener.cancel()
                            }
                            ToolButton {
                                icon.name: "system-run"
                                visible: model.application !== undefined && model.application.isInstalled && !listener.isActive && model.application.canExecute
                                onClicked: {
                                    model.application.invokeApplication()
                                    model.remove(index)
                                }
                            }
                        }
                        ProgressBar {
                            Layout.fillWidth: true
                            visible: listener.isActive
                            value: listener.progress / 100
                        }
                    }
                }
            }
        }
    }
}
