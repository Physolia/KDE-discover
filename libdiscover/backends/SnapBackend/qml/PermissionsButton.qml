/*
 *   Copyright (C) 2018 Aleix Pol Gonzalez <aleixpol@blue-systems.com>
 *
 *   This program is free software; you can redistribute it and/or modify
 *   it under the terms of the GNU Library/Lesser General Public License
 *   version 2, or (at your option) any later version, as published by the
 *   Free Software Foundation
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU General Public License for more details
 *
 *   You should have received a copy of the GNU Library/Lesser General Public
 *   License along with this program; if not, write to the
 *   Free Software Foundation, Inc.,
 *   51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

import QtQuick 2.1
import QtQuick.Controls 2.1
import org.kde.kirigami 2.1 as Kirigami

Button
{
    id: root
    text: i18n("Configure permissions...")

    onClicked: overlay.open()
    visible: resource.isInstalled && view.count > 0

    DiscoverPopup {
        id: overlay

        ListView {
            id: view
            anchors.fill: parent
            header: Kirigami.ItemViewHeader {
                text: i18n ("Permissions for %1", resource.name)
            }
            model: resource.plugs(root)
            delegate: CheckDelegate {
                id: delegate
                width: parent.width
                text: model.display
                checked: model.checked
                onClicked: {
                    model.checked = delegate.checked
                }
            }
        }
    }
}
