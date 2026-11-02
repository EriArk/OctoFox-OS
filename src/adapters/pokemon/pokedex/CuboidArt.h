// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include <QImage>
#include <QVariantList>

namespace trainer {
// Original, symbolic creatures. Exact catalogue keys select a visual recipe only;
// neither resemblance nor this mapping grants semantic/save authority.
class CuboidArt {
public:
    static QVariantMap illustration(const QString& target, const QString& profile);
    static QVariantList choices(const QString& target);
    static QImage render(const QString& id);
    static bool accepts(const QString& target);
};
}
