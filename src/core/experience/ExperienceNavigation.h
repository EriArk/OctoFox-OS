#pragma once
#include "core/model/Models.h"
#include <QHash>
#include <QVariantMap>

namespace trainer {
// Trusted view keys resolve through a compiled presenter; never save authority.
struct ExperienceScreen {
    QString id, label, view, icon;
    QString group, groupLabel;
    QString artwork; // Optional trusted module illustration; icon remains the fallback.
    bool operator==(const ExperienceScreen&) const = default;
};
struct ExperienceSurface {
    QString label, icon;
    QList<ExperienceScreen> screens;
    bool operator==(const ExperienceSurface&) const = default;
};
struct ExperienceDescriptor {
    QString id;
    int version = 2;
    QString homeView;
    ExperienceSurface adapter;
    bool operator==(const ExperienceDescriptor&) const = default;
};
const ExperienceDescriptor& genericExperienceDescriptor();
class ExperienceNavigation {
public:
    bool select(const QString& owner, const QString& adventure,
                const ExperienceDescriptor&, int registrationRevision = 0);
    const ExperienceDescriptor& descriptor() const { return descriptor_; }
    QString adventure() const { return adventure_; }
    QString owner() const { return owner_; }
    quint64 generation() const { return generation_; }
    bool current(const QString& owner, const QString& adventure, quint64 generation) const;
    bool hasAdapter() const { return !descriptor_.adapter.screens.isEmpty(); }
    QStringList screenIds() const;
    QStringList groupIds() const;
    QStringList groupLabels() const;
    QString group() const;
    QStringList groupScreens() const;
    bool showGroup(const QString& group);
    QString screen() const;
    QString view() const;
    int index() const;
    bool show(const QString& screen);
    QJsonObject navigation() const;
    void rememberNavigation(const QJsonObject&);
    QJsonObject state() const;
    void restore(const QJsonObject&);
    // Read-only migration of retired v1 slots, never live routing.
    QString legacyScreen(int oldSlot) const;
    void clear();
    static bool valid(const ExperienceDescriptor&);
private:
    QString key() const;
    ExperienceDescriptor descriptor_ = genericExperienceDescriptor();
    QString owner_, adventure_;
    int registrationRevision_ = 0;
    quint64 generation_ = 0;
    QHash<QString, QJsonObject> states_;
};
}
