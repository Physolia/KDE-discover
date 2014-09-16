/***************************************************************************
 *   Copyright © 2012 Aleix Pol Gonzalez <aleixpol@blue-systems.com>       *
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

import QtQuick 2.1
import QtQuick.Controls 1.1
import org.kde.plasma.extras 2.0
import org.kde.muon 1.0

Item
{
    id: page
    property alias model: reviewsView.model
    property real actualWidth: width-Math.pow(width/70, 2)
    property real proposedMargins: (width-actualWidth)/2
    
    ScrollView {
        anchors.fill: parent
        ListView {
            id: reviewsView

            clip: true
            visible: count>0
            spacing: 5

            delegate: ReviewDelegate {
                x: page.proposedMargins
                width: page.actualWidth
                onMarkUseful: reviewsModel.markUseful(index, useful)
            }
        }
    }
}
