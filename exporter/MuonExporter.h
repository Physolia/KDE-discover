/*
 *   Copyright (C) 2012 Aleix Pol Gonzalez <aleixpol@blue-systems.com>
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

#ifndef MUONEXPORTER_H
#define MUONEXPORTER_H

#include <QUrl>
#include <QSet>
#include <QTimer>

class AbstractResource;

class MuonExporter : public QObject
{
    Q_OBJECT
    public:
        explicit MuonExporter();
        ~MuonExporter() override;

        void setExportPath(const QUrl& url);

    public Q_SLOTS:
        void fetchResources();
        void exportResources(const QVector<AbstractResource*>& resources);

    Q_SIGNALS:
        void exportDone();

    private:
        QUrl m_path;
        const QSet<QByteArray> m_exculdedProperties;
};

#endif // MUONEXPORTER_H
