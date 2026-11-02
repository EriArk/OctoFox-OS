// SPDX-License-Identifier: GPL-3.0-or-later
#include "CuboidArt.h"
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QPainter>
#include <QPainterPath>
#include <QRegularExpression>
#include <cmath>

static void initializeCuboids() { Q_INIT_RESOURCE(cuboid_creatures); }
namespace trainer {
namespace {
const QJsonObject& recipes() {
    static const auto value=[] {
        initializeCuboids(); QFile f(":/cuboids/cuboid-creatures.json");
        if (!f.open(QIODevice::ReadOnly)) return QJsonObject{};
        return QJsonDocument::fromJson(f.readAll()).object()["targets"].toObject();
    }();
    return value;
}
const QStringList actions{"Idle","WalkLeft","WalkRight","WalkUp","WalkDown","Sleep","Normal","Happy","Pain"};
QVariantList durations(const QString& action) {
    if (action=="Idle") return {1200,150,120,900};
    if (action=="Sleep") return {500,500,500,500};
    if (action.startsWith("Walk")) return {120,120,120,120};
    return {};
}
QVariantMap record(const QString& target, const QString& action) {
    const auto times=durations(action); const bool sprite=!times.isEmpty();
    const QString id="cuboid/v1/"+target+'/'+action;
    return {{"id",id},{"url","image://sprite-detail/"+id},{"kind",sprite?"sprite":"portrait"},
        {"action",action},{"label","Cuboid · "+action},{"frames",sprite?4:1},{"frameWidth",sprite?96:160},
        {"durations",times},{"builtin",true},{"fallback",true},{"available",true},
        {"credit","TrainerOS original geometric artwork"},{"source","Built-in symbolic creature"},
        {"license","GPL-3.0-or-later"},{"review","Symbolic representation, not canonical artwork"}};
}
// A tiny orthographic modeller: the same rounded blocks, camera, face and feet
// are redrawn for every action. No independently generated animation frames.
struct Model {
    QPainter& p; double yaw=0, bob=0;
    QPointF project(double x,double y,double z) const {
        const double a=yaw*3.141592653589793/180, xx=x*std::cos(a)-z*std::sin(a), zz=x*std::sin(a)+z*std::cos(a);
        return {48+xx*.88+zz*.48,78-y*.95-zz*.27+xx*.10+bob};
    }
    void face(const QPolygonF& poly,const QColor& color) {
        QPainterPath path; path.addPolygon(poly); path.closeSubpath();
        p.setPen(QPen(color,1.3,Qt::SolidLine,Qt::RoundCap,Qt::RoundJoin));p.setBrush(color);p.drawPath(path);
    }
    void box(double x,double y,double z,double w,double h,double d,QColor c) {
        const auto A=project(x,y,z),B=project(x+w,y,z),C=project(x+w,y+h,z),D=project(x,y+h,z);
        const auto E=project(x,y,z+d),F=project(x+w,y,z+d),G=project(x+w,y+h,z+d),H=project(x,y+h,z+d);
        // Painter ordering of faces follows the actual camera-facing side.
        if(yaw==180) {face({E,F,G,H},c.darker(110));face({A,E,H,D},c.darker(125));}
        else {face({B,F,G,C},c.darker(117));face({A,B,C,D},c);}
        face({D,C,G,H},c.lighter(124));
        p.setBrush(Qt::NoBrush);p.setPen(QPen(QColor(255,255,255,45),.65));p.drawLine(D,C);
    }
};
void creature(QPainter& p,const QJsonObject& r,const QString& action,int frame) {
    const QString shape=r["shape"].toString("cube");
    const QColor body(r["color"].toString("#83beb0")), accent(r["accent"].toString("#edaa89"));
    const int variant=r["variant"].toInt();
    const bool wide=shape=="broad"||shape=="shell", tall=shape=="tall"||shape=="crystal", flying=shape=="wing";
    const double w=(wide?43:tall?25:32)+r["widthOffset"].toInt(),
        h=(wide?22:tall?43:31)+r["heightOffset"].toInt(),
        d=(wide?24:25)+r["depthOffset"].toInt();
    const bool walk=action.startsWith("Walk"), asleep=action=="Sleep";
    const double phase=frame*3.141592653589793/2, step=walk?std::sin(phase)*3:0;
    const double bob=flying?std::sin(phase)*1.5:walk?-std::abs(step)*.45:asleep?std::sin(phase)*.65:0;
    p.save();
    if(action=="WalkLeft") {p.translate(96,0);p.scale(-1,1);}
    // All actions share a fixed 96x96 cell and the same ground baseline.
    Model m{p,action=="WalkUp"?180.0:action=="WalkDown"?-25.0:0.0,bob};
    const double x=-w/2-5,z=-d/2,y=flying?23:8;
    p.setPen(Qt::NoPen);p.setBrush(QColor(40,60,50,23));p.drawEllipse(QRectF(25,78,48,6));
    if(shape=="wing") {
        const double flap=std::sin(phase)*4;
        m.face({m.project(x,y+14,z+8),m.project(x-18,y+30+flap,z+7),m.project(x-24,y+32+flap,z+3),m.project(x-17,y+12,z+3)},body.lighter(112));
        m.face({m.project(x+w,y+14,z+8),m.project(x+w+16,y+28+flap,z+6),m.project(x+w+26,y+32+flap,z+3),m.project(x+w+16,y+10,z+3)},accent);
    }
    // Tail and rear feet sit behind the body, never painted across the face.
    if(shape=="ears"||shape=="fin")m.box(x+w-4,y+3,z+d-4,17,5,5,accent);
    if(wide) {m.box(x+3,3+step,z+d-7,8,9,8,body.darker(128));m.box(x+w-11,3-step,z+d-7,8,9,8,body.darker(128));}
    const double feet=flying?y-7:2;
    m.box(x+4,feet+std::max(0.0,step),z+1,8,10,9,body.darker(135));
    m.box(x+w-12,feet+std::max(0.0,-step),z+1,8,10,9,body.darker(130));
    if(tall)m.box(x-5,y+7,z+9,6,8,7,accent);
    if(shape=="fin")m.box(x-8,y+8,z+6,8,5,12,accent);
    m.box(x,y,z,w,h,d,body);
    if(shape=="ears") {
        for(int i=0;i<2;++i){const double eh=16+(i?0:5);m.box(x+5+i*(w-13),y+h,z+7,5,eh,5,body);m.box(x+5+i*(w-13),y+h+eh-4,z+7,5,4,5,QColor("#6e6049"));}
    } else if(shape=="broad"||shape=="leaf") {
        m.box(x+2,y+h,z+d-6,7,8,4,accent);m.box(x+w-8,y+h+1,z+d-7,9,6,4,accent.lighter(110));
    } else if(tall) {
        m.box(x+5,y+h,z+11,w-6,7,5,accent);m.box(x+10,y+h+7,z+13,w-12,6,4,accent.lighter(115));
        m.box(x+w,y+7,z+9,6,8,7,accent);
    } else if(shape=="shell") {
        m.box(x+7,y+h,z+8,w-12,7,d-7,accent);m.box(x+12,y+h+7,z+12,w-22,4,d-14,accent.lighter(110));
    } else if(shape=="fin") {
        m.box(x+8,y+h,z+12,14,10,4,accent);
    } else if(!flying) m.box(x+w,y+9,z+8,6,10,7,accent);
    if(variant==1&&!tall&&!flying)m.box(x+12,y+h,z+9,8,4,6,accent);
    // Face is omitted for rear-facing walking, not mirrored onto the back.
    if(action!="WalkUp") {
        const auto L=m.project(x+w*.30,y+h*.52,z-.9),R=m.project(x+w*.72,y+h*.52,z-.9);
        p.setPen(QPen(QColor("#354c43"),2.4,Qt::SolidLine,Qt::RoundCap));
        for(auto eye:{L,R}) {
            if(asleep||action=="Pain"||(action=="Idle"&&frame==2))p.drawLine(eye-QPointF(1.8,0),eye+QPointF(1.8,.4));
            else if(action=="Happy") {QPainterPath smile;smile.moveTo(eye+QPointF(-2,1));smile.quadTo(eye+QPointF(0,-3),eye+QPointF(2,1));p.drawPath(smile);}
            else p.drawLine(eye-QPointF(0,1.8),eye+QPointF(0,1.8));
        }
        if(variant==2||action=="Happy") {const auto mouth=(L+R)/2+QPointF(0,7);p.setPen(QPen(QColor("#536155"),1.2,Qt::SolidLine,Qt::RoundCap));p.drawLine(mouth-QPointF(1.5,0),mouth+QPointF(1.5,0));}
    }
    p.restore();
}
}
bool CuboidArt::accepts(const QString& target) {
    static const QRegularExpression valid("^[a-z0-9][a-z0-9-]{0,79}/[a-zA-Z0-9-]{1,40}$");
    return valid.match(target).hasMatch();
}
QVariantMap CuboidArt::illustration(const QString& target,const QString& profile) {
    if(!accepts(target)||!(profile=="pokedexListArt"||profile=="pokedexDetailArt"||profile=="speciesPickerArt"))return {};
    auto row=record(target,"Normal");
    row["url"]="image://sprite-detail/cuboid/v1/"+target+'/'+profile;
    row["status"]="Cuboid creature · symbolic artwork";
    row["sourceName"]="TrainerOS Cuboids";
    return row;
}
QVariantList CuboidArt::choices(const QString& target) {
    if(!accepts(target))return {};
    QVariantList result;for(const auto& action:actions)result.append(record(target,action));return result;
}
QImage CuboidArt::render(const QString& id) {
    const auto parts=id.split('/');
    if(parts.size()!=5||parts[0]!="cuboid"||parts[1]!="v1")return {};
    const auto target=parts[2]+'/'+parts[3], action=parts[4];
    if(!accepts(target))return {};
    const bool art=action=="pokedexListArt"||action=="pokedexDetailArt"||action=="speciesPickerArt";
    if(!art&&!actions.contains(action))return {};
    const auto times=durations(action);const int frames=times.isEmpty()?1:4;
    const QSize cell=action=="pokedexDetailArt"?QSize(480,400):action=="speciesPickerArt"?QSize(72,72):
        action=="pokedexListArt"?QSize(96,96):QSize(frames==1?160:96,frames==1?160:96);
    // Oversampling only the requested sheet gives clean alpha and thin details.
    QImage high(cell.width()*frames*2,cell.height()*2,QImage::Format_ARGB32_Premultiplied);high.fill(Qt::transparent);
    QPainter painter(&high);painter.setRenderHint(QPainter::Antialiasing);
    const auto recipe=recipes()[target].toObject();
    for(int frame=0;frame<frames;++frame){painter.save();painter.translate(frame*cell.width()*2,0);
        const double scale=qMin(cell.width(),cell.height())*2/96.0;
        painter.translate((cell.width()*2-96*scale)/2,0);painter.scale(scale,scale);
        creature(painter,recipe,art?QString("Normal"):action,frame);painter.restore();}
    painter.end();return high.scaled(cell.width()*frames,cell.height(),Qt::IgnoreAspectRatio,Qt::SmoothTransformation);
}
}
