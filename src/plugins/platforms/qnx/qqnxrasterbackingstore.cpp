/***************************************************************************
**
** Copyright (C) 2011 - 2012 Research In Motion
** Contact: http://www.qt-project.org/
**
** This file is part of the plugins of the Qt Toolkit.
**
** $QT_BEGIN_LICENSE:LGPL$
** GNU Lesser General Public License Usage
** This file may be used under the terms of the GNU Lesser General Public
** License version 2.1 as published by the Free Software Foundation and
** appearing in the file LICENSE.LGPL included in the packaging of this
** file. Please review the following information to ensure the GNU Lesser
** General Public License version 2.1 requirements will be met:
** http://www.gnu.org/licenses/old-licenses/lgpl-2.1.html.
**
** In addition, as a special exception, Nokia gives you certain additional
** rights. These rights are described in the Nokia Qt LGPL Exception
** version 1.1, included in the file LGPL_EXCEPTION.txt in this package.
**
** GNU General Public License Usage
** Alternatively, this file may be used under the terms of the GNU General
** Public License version 3.0 as published by the Free Software Foundation
** and appearing in the file LICENSE.GPL included in the packaging of this
** file. Please review the following information to ensure the GNU General
** Public License version 3.0 requirements will be met:
** http://www.gnu.org/copyleft/gpl.html.
**
** Other Usage
** Alternatively, this file may be used in accordance with the terms and
** conditions contained in a signed written agreement between you and Nokia.
**
**
**
**
**
**
** $QT_END_LICENSE$
**
****************************************************************************/

#include "qqnxrasterbackingstore.h"
#include "qqnxwindow.h"

#include <QtCore/QDebug>

#include <errno.h>

#ifdef QQNXRASTERBACKINGSTORE_DEBUG
#define qRasterBackingStoreDebug qDebug
#else
#define qRasterBackingStoreDebug QT_NO_QDEBUG_MACRO
#endif

QT_BEGIN_NAMESPACE

QQnxRasterBackingStore::QQnxRasterBackingStore(QWindow *window)
    : QPlatformBackingStore(window),
      m_hasUnflushedPaintOperations(false)
{
    qRasterBackingStoreDebug() << Q_FUNC_INFO << "w =" << window;

    // save platform window associated with widget
    m_platformWindow = static_cast<QQnxWindow*>(window->handle());
}

QQnxRasterBackingStore::~QQnxRasterBackingStore()
{
    qRasterBackingStoreDebug() << Q_FUNC_INFO << "w =" << window();
}

QPaintDevice *QQnxRasterBackingStore::paintDevice()
{
    return m_platformWindow->renderBuffer().image();
}

void QQnxRasterBackingStore::flush(QWindow *window, const QRegion &region, const QPoint &offset)
{
    qRasterBackingStoreDebug() << Q_FUNC_INFO << "w =" << this->window();

    QQnxWindow *targetWindow = 0;
    if (window)
        targetWindow = static_cast<QQnxWindow *>(window->handle());

    if (!targetWindow || targetWindow == m_platformWindow) {

        // visit all pending scroll operations
        for (int i = m_scrollOpList.size() - 1; i >= 0; i--) {

            // do the scroll operation
            ScrollOp &op = m_scrollOpList[i];
            QRegion srcArea = op.totalArea.intersected( op.totalArea.translated(-op.dx, -op.dy) );
            m_platformWindow->scroll(srcArea, op.dx, op.dy);
        }

        // clear all pending scroll operations
        m_scrollOpList.clear();

        // update the display with newly rendered content
        m_platformWindow->post(region);
    } else if (targetWindow) {

        // The contents of the backing store should be flushed to a different window than the
        // window which owns the buffer.
        // This typically happens for child windows, since child windows share a backing store with
        // their top-level window (TLW).
        // Simply copy the buffer over to the child window, to emulate a painting operation, and
        // then post the window.
        //
        // ### Note that because of the design in the QNX QPA plugin, each window has its own buffers,
        // even though they might share a backing store. This is unneeded overhead, but I don't think
        // libscreen allows to have windows without buffers, or does it?

        // We assume that the TLW has been flushed previously and that no changes were made to the
        // backing store inbetween (### does Qt guarantee this?)
        Q_ASSERT(!m_hasUnflushedPaintOperations);

        targetWindow->adjustBufferSize();
        targetWindow->blitFrom(m_platformWindow, offset, region);
        targetWindow->post(region);

    } else {
        qWarning() << Q_FUNC_INFO << "flush() called without a valid window!";
    }

    m_hasUnflushedPaintOperations = false;
}

void QQnxRasterBackingStore::resize(const QSize &size, const QRegion &staticContents)
{
    Q_UNUSED(size);
    Q_UNUSED(staticContents);
    qRasterBackingStoreDebug() << Q_FUNC_INFO << "w =" << window() << ", s =" << size;

    // NOTE: defer resizing window buffers until next paint as
    // resize() can be called multiple times before a paint occurs
}

bool QQnxRasterBackingStore::scroll(const QRegion &area, int dx, int dy)
{
    qRasterBackingStoreDebug() << Q_FUNC_INFO << "w =" << window();

    // calculate entire region affected by scroll operation (src + dst)
    QRegion totalArea = area.translated(dx, dy);
    totalArea += area;
    m_hasUnflushedPaintOperations = true;

    // visit all pending scroll operations
    for (int i = m_scrollOpList.size() - 1; i >= 0; i--) {

        ScrollOp &op = m_scrollOpList[i];
        if (op.totalArea == totalArea) {
            // same area is being scrolled again - update delta
            op.dx += dx;
            op.dy += dy;
            return true;
        } else if (op.totalArea.intersects(totalArea)) {
            // current scroll overlaps previous scroll but is
            // not equal in area - just paint everything
            qWarning("QQNX: pending scroll operations overlap but not equal");
            return false;
        }
    }

    // create new scroll operation
    m_scrollOpList.append( ScrollOp(totalArea, dx, dy) );
    return true;
}

void QQnxRasterBackingStore::beginPaint(const QRegion &region)
{
    Q_UNUSED(region);

    qRasterBackingStoreDebug() << Q_FUNC_INFO << "w =" << window();
    m_hasUnflushedPaintOperations = true;

    m_platformWindow->adjustBufferSize();
}

void QQnxRasterBackingStore::endPaint(const QRegion &region)
{
    Q_UNUSED(region);
    qRasterBackingStoreDebug() << Q_FUNC_INFO << "w =" << window();
}

QT_END_NAMESPACE
