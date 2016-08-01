/***************************************************************************
 *   Copyright © 2010 Jonathan Thomas <echidnaman@kubuntu.org>             *
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

#include "Category.h"

#include <QtXml/QDomNode>

#include <klocalizedstring.h>
#include <QFile>
#include <QDebug>

Category::Category(QSet<QString>  pluginName, QObject* parent)
        : QObject(parent)
        , m_iconString(QStringLiteral("applications-other"))
        , m_showTechnical(false)
        , m_plugins(std::move(pluginName))
{}

Category::~Category() = default;

void Category::parseData(const QString& path, const QDomNode& data)
{
    for(QDomNode node = data.firstChild(); !node.isNull(); node = node.nextSibling())
    {
        if(!node.isElement()) {
            if(!node.isComment())
                qWarning() << "unknown node found at " << QStringLiteral("%1:%2").arg(path).arg(node.lineNumber());
            continue;
        }
        QDomElement tempElement = node.toElement();

        if (tempElement.tagName() == QLatin1String("Name")) {
            m_name = i18nc("Category", tempElement.text().toUtf8().constData());
        } else if (tempElement.tagName() == QLatin1String("Menu")) {
            m_subCategories << new Category(m_plugins, this);
            m_subCategories.last()->parseData(path, node);
        } else if (tempElement.tagName() == QLatin1String("Image")) {
            m_decoration = QUrl(tempElement.text());
        } else if (tempElement.tagName() == QLatin1String("Addons")) {
            m_isAddons = true;
        } else if (tempElement.tagName() == QLatin1String("Icon") && tempElement.hasChildNodes()) {
            m_iconString = tempElement.text();
        } else if (tempElement.tagName() == QLatin1String("ShowTechnical")) {
            m_showTechnical = true;
        } else if (tempElement.tagName() == QLatin1String("Include")) { //previous muon format
            parseIncludes(tempElement);
        } else if (tempElement.tagName() == QLatin1String("Categories")) { //as provided by appstream
            parseIncludes(tempElement);
        }
    }
}

QVector<QPair<FilterType, QString> > Category::parseIncludes(const QDomNode &data)
{
    QDomNode node = data.firstChild();
    QVector<QPair<FilterType, QString> > filter;
    while(!node.isNull())
    {
        QDomElement tempElement = node.toElement();

        if (tempElement.tagName() == QLatin1String("And")) {
            // Parse children
            m_andFilters.append(parseIncludes(node));
        } else if (tempElement.tagName() == QLatin1String("Or")) {
            m_orFilters.append(parseIncludes(node));
        } else if (tempElement.tagName() == QLatin1String("Not")) {
            m_notFilters.append(parseIncludes(node));
        } else if (tempElement.tagName() == QLatin1String("PkgSection")) {
            filter.append({ PkgSectionFilter, tempElement.text() });
        } else if (tempElement.tagName() == QLatin1String("Category")) {
            filter.append({ CategoryFilter, tempElement.text() });
        } else if (tempElement.tagName() == QLatin1String("PkgWildcard")) {
            filter.append({ PkgWildcardFilter, tempElement.text() });
        } else if (tempElement.tagName() == QLatin1String("PkgName")) {
            filter.append({ PkgNameFilter, tempElement.text() });
        } else {
            qWarning() << "unknown" << tempElement.tagName();
        }
        node = node.nextSibling();
    }

    return filter;
}

QString Category::name() const
{
    return m_name;
}

QString Category::icon() const
{
    return m_iconString;
}

QVector<QPair<FilterType, QString> > Category::andFilters() const
{
    return m_andFilters;
}

QVector<QPair<FilterType, QString> > Category::orFilters() const
{
    return m_orFilters;
}

QVector<QPair<FilterType, QString> > Category::notFilters() const
{
    return m_notFilters;
}

bool Category::shouldShowTechnical() const
{
    return m_showTechnical;
}

QVector<Category *> Category::subCategories() const
{
    return m_subCategories;
}

//TODO: maybe it would be interesting to apply some rules to a said backend...
void Category::addSubcategory(QVector< Category* >& list, Category* newcat)
{
    Q_FOREACH (Category* c, list) {
        if(c->name() == newcat->name()) {
            if(c->icon() != newcat->icon()
                || c->shouldShowTechnical() != newcat->shouldShowTechnical()
                || c->m_andFilters != newcat->m_andFilters
                || c->m_isAddons != newcat->m_isAddons
            )
            {
                qWarning() << "the following categories seem to be the same but they're not entirely"
                    << c->name() << newcat->name() << "--"
                    << c->shouldShowTechnical() << newcat->shouldShowTechnical() << "--"
                    << c->andFilters() << newcat->andFilters() << "--"
                    << c->isAddons() << newcat->isAddons();
                break;
            } else {
                c->m_orFilters += newcat->orFilters();
                c->m_notFilters += newcat->notFilters();
                c->m_plugins.unite(newcat->m_plugins);
                Q_FOREACH (Category* nc, newcat->subCategories()) {
                    nc->setParent(c);
                    addSubcategory(c->m_subCategories, nc);
                }
                delete newcat;
                return;
            }
        }
    }
    list << newcat;
}

bool Category::blacklistPlugins(const QSet<QString>& pluginNames)
{
    for(QVector<Category*>::iterator it = m_subCategories.begin(), itEnd = m_subCategories.end(); it!=itEnd; ) {
        if ((*it)->blacklistPlugins(pluginNames)) {
            delete *it;
            it = m_subCategories.erase(it);
        } else
            ++it;
    }
    m_plugins.subtract(pluginNames);

    return m_plugins.isEmpty();
}

QUrl Category::decoration() const
{
    if (m_decoration.isEmpty()) {
        Category* c = qobject_cast<Category*>(parent());
        return c ? c->decoration() : QUrl();
    } else {
        return m_decoration;
    }
}
