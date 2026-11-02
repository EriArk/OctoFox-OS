// SPDX-License-Identifier: GPL-3.0-or-later
#include "AvatarScene.h"
#include <QQuick3DGeometry>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QFile>
#include <QSaveFile>
#include <QDir>
#include <QStandardPaths>
#include <QCryptographicHash>
#include <QMatrix4x4>
#include <QQuaternion>
#include <QColor>
#include <QSet>
#include <QtEndian>
#include <algorithm>
#include <cmath>
#include <cstring>
#include <stdexcept>
#include <functional>
#include <source_location>
#include <QtConcurrent>
#include <QFutureWatcher>
#include <QLoggingCategory>

namespace trainer {
Q_LOGGING_CATEGORY(avatarLifecycle,"trainer.avatar.lifecycle",QtWarningMsg)
namespace {
void require(bool ok,const std::source_location where=std::source_location::current()){
    if(!ok)throw std::runtime_error("Invalid or unsupported resolved avatar at "+std::to_string(where.line()));
}
struct Glb {
    std::shared_ptr<std::atomic_bool> cancelled;
    QJsonObject json;QByteArray binary;
    explicit Glb(const QUrl& url,std::shared_ptr<std::atomic_bool> stop):cancelled(std::move(stop)){
        require(url.isLocalFile());QFile f(url.toLocalFile());require(f.open(QIODevice::ReadOnly)&&f.size()<=64*1024*1024);
        const auto b=f.readAll();require(b.size()>=28&&qFromLittleEndian<quint32>(b.constData())==0x46546c67&&qFromLittleEndian<quint32>(b.constData()+4)==2);
        const auto n=qFromLittleEndian<quint32>(b.constData()+12);require(n<=8*1024*1024&&qint64(n)+28<=b.size());
        json=QJsonDocument::fromJson(b.mid(20,n)).object();binary=b.mid(28+n);
        require(!json.isEmpty()&&json["buffers"].toArray().size()==1);
        require(!json["buffers"].toArray()[0].toObject().contains("uri"));
    }
    float component(qint64 offset,int type,bool normalized=false) const {
        const int size=type==5121?1:type==5123?2:4;require(offset>=0&&offset+size<=binary.size());
        const char* p=binary.constData()+offset;
        if(type==5121)return float(quint8(*p))/(normalized?255.f:1.f);
        if(type==5123)return float(qFromLittleEndian<quint16>(p))/(normalized?65535.f:1.f);
        if(type==5125)return float(qFromLittleEndian<quint32>(p));
        require(type==5126);const auto bits=qFromLittleEndian<quint32>(p);float v;std::memcpy(&v,&bits,4);require(std::isfinite(v));return v;
    }
    QVector<float> accessor(int id) const {
        require(!cancelled->load(std::memory_order_relaxed));
        const auto accs=json["accessors"].toArray(),views=json["bufferViews"].toArray();require(id>=0&&id<accs.size());
        const auto a=accs[id].toObject();const QString type=a["type"].toString();
        const int width=type=="SCALAR"?1:type=="VEC2"?2:type=="VEC3"?3:type=="VEC4"?4:type=="MAT4"?16:0;
        const int count=a["count"].toInt(),ct=a["componentType"].toInt(),size=ct==5121?1:ct==5123?2:4;
        require(width>0&&count>=0&&count<=2000000&&qint64(count)*width<=16000000);QVector<float> out(count*width,0);
        auto viewAt=[&](int index){require(index>=0&&index<views.size());auto v=views[index].toObject();require(v["buffer"].toInt()==0);return v;};
        if(a.contains("bufferView")){
            const auto v=viewAt(a["bufferView"].toInt());const qint64 start=qint64(v["byteOffset"].toInt())+a["byteOffset"].toInt();const int stride=v["byteStride"].toInt(width*size);require(stride>=width*size);
            for(int i=0;i<count;++i)for(int c=0;c<width;++c)out[i*width+c]=component(start+qint64(i)*stride+c*size,ct,a["normalized"].toBool());
        }
        const auto sp=a["sparse"].toObject();if(!sp.isEmpty()){
            const auto ix=sp["indices"].toObject(),values=sp["values"].toObject();const int it=ix["componentType"].toInt(),is=it==5121?1:it==5123?2:4;
            const auto iv=viewAt(ix["bufferView"].toInt()),vv=viewAt(values["bufferView"].toInt());const int n=sp["count"].toInt();require(n<=count);
            for(int i=0;i<n;++i){const int vertex=int(component(qint64(iv["byteOffset"].toInt())+ix["byteOffset"].toInt()+i*is,it));require(vertex>=0&&vertex<count);
                for(int c=0;c<width;++c)out[vertex*width+c]=component(qint64(vv["byteOffset"].toInt())+values["byteOffset"].toInt()+(qint64(i)*width+c)*size,ct,a["normalized"].toBool());}
        }return out;
    }
};
QVector3D vec(const QJsonArray& a,QVector3D fallback={}){return a.size()==3?QVector3D(a[0].toDouble(),a[1].toDouble(),a[2].toDouble()):fallback;}
QVector3D vec(const QVector<float>& a,int index){return {a[index],a[index+1],a[index+2]};}
QQuaternion quat(const QJsonArray& a){return a.size()==4?QQuaternion(a[3].toDouble(),a[0].toDouble(),a[1].toDouble(),a[2].toDouble()):QQuaternion();}
QMatrix4x4 mat(const QVector<float>& a,int offset){require(offset>=0&&offset+16<=a.size());QMatrix4x4 m;for(int i=0;i<16;++i)m.data()[i]=a[offset+i];return m;}
QVector3D normal(const QMatrix3x3& m,const QVector3D& v){return {m(0,0)*v.x()+m(0,1)*v.y()+m(0,2)*v.z(),m(1,0)*v.x()+m(1,1)*v.y()+m(1,2)*v.z(),m(2,0)*v.x()+m(2,1)*v.y()+m(2,2)*v.z()};}
float srgb(float v){return v<=.0031308f?v*12.92f:1.055f*std::pow(v,1.f/2.4f)-.055f;}
struct Vertex {float p[3],n[3],uv[2],color[4];qint32 joints[4]{};float weights[4]{};};
struct Delta {int vertex;QVector3D p,n;};
}
struct AvatarScene::Data {
    struct Node {QString name;int parent=-1;QVector3D p,s{1,1,1};QQuaternion r;QMatrix4x4 matrix;bool matrixSet=false,live=false;QVector<float> weights;};
    struct Skin {QVector<int> nodes;QVector<QMatrix4x4> inverse;};
    struct Part {int node,skin;QVector<Vertex> base;QVector<float> joints,weights,lastMorph;bool uploaded=false;QVector<QVector<Delta>> morphs;QStringList names;QByteArray indices;QQuick3DGeometry* geometry=nullptr;};
    struct Track {int node,width;QString path,interpolation;QVector<float> times,values;};
    struct Clip {QVector<Track> tracks;float duration=0;};
    QVector<Node> nodes,animated,transition;float transitionTime=0;
    QVector<Skin> skins;QVector<Part> parts;QMap<QString,Clip> clips;
    QJsonObject expressions;QSet<QString> controls;QMap<QString,float> face;
    QMap<QString,QVector3D> pose;int vertices=0;
    QVariantList materials;
    QString error;
    ~Data(){for(auto& p:parts)delete p.geometry;}
};
AvatarScene::AvatarScene(QObject* parent):QObject(parent){timer_.setInterval(42);connect(&timer_,&QTimer::timeout,this,&AvatarScene::frame);clock_.start();qCDebug(avatarLifecycle)<<"created"<<this;}
AvatarScene::~AvatarScene(){if(cancelled_)cancelled_->store(true);timer_.stop();qCDebug(avatarLifecycle)<<"destroyed"<<this<<"vertices"<<vertexCount()<<"uploads"<<geometryUploads_;}
void AvatarScene::setGpuSkinning(bool value){
    if(value==gpuSkinning_)return;
    gpuSkinning_=value;const auto source=source_;setSource({});setSource(source);emit modelChanged();
}
QVariantList AvatarScene::rigs() const {
    QVariantList result;if(!d_||!gpuSkinning_)return result;
    for(const auto& skin:d_->skins){QVariantList joints,inverse;
        for(int i=0;i<skin.nodes.size();++i){joints.append(skin.nodes[i]);inverse.append(QVariant::fromValue(skin.inverse[i]));}
        result.append(QVariantMap{{"joints",joints},{"inverse",inverse}});
    }return result;
}
int AvatarScene::vertexCount() const{return d_?d_->vertices:0;}
bool AvatarScene::supportsExpression(const QString& name) const{return d_&&d_->expressions.contains(name);}
bool AvatarScene::supportsClip(const QString& name) const{return d_&&d_->clips.contains(name);}
void AvatarScene::setRunning(bool value){if(running_==value)return;running_=value;clock_.restart();if(value&&ready())timer_.start();else timer_.stop();emit changed();}
void AvatarScene::setExpression(const QString& value){if(expression_==value||(d_&&!supportsExpression(value)))return;expression_=value;dirty_=true;emit changed();if(!running_)frame();}
void AvatarScene::setClip(const QString& value){
    if(clip_==value||(d_&&!value.isEmpty()&&!supportsClip(value)))return;
    if(d_){d_->transition=running_?d_->animated:QVector<Data::Node>();d_->transitionTime=0;}
    clip_=value;clipSeconds_=0;dirty_=true;emit changed();if(!running_)frame();
}
void AvatarScene::setClipPosition(qreal value){if(!std::isfinite(value)||clipPosition_==value)return;clipPosition_=std::clamp(value,-1.,1.);dirty_=true;emit changed();if(!running_)frame();}
void AvatarScene::setPose(const QVariantMap& value){
    for(auto i=value.begin();i!=value.end();++i){if(!i.value().canConvert<QVector3D>())return;const auto v=i.value().value<QVector3D>();if(!std::isfinite(v.x())||!std::isfinite(v.y())||!std::isfinite(v.z()))return;}
    if(pose_==value)return;pose_=value;dirty_=true;emit changed();if(!running_)frame();
}
void AvatarScene::setFace(const QVariantMap& value){
    for(auto i=value.begin();i!=value.end();++i)if(!std::isfinite(i.value().toDouble())||(d_&&!d_->controls.contains(i.key())))return;
    if(face_==value)return;face_=value;dirty_=true;emit changed();if(!running_)frame();
}
void AvatarScene::setSource(const QUrl& value){
    if(value==source_)return;if(cancelled_)cancelled_->store(true);cancelled_=std::make_shared<std::atomic_bool>(false);
    source_=value;timer_.stop();parts_.clear();d_.reset();error_.clear();rightHand_={};sockets_.clear();nodePoses_.clear();geometryUploads_=0;
    const auto generation=++loadGeneration_;
    emit frameChanged();emit modelChanged();emit changed();
    if(value.isEmpty())return;
    auto* watcher=new QFutureWatcher<std::shared_ptr<Data>>(this);
    connect(watcher,&QFutureWatcher<std::shared_ptr<Data>>::finished,this,[this,watcher,generation]{
        const auto data=watcher->result();watcher->deleteLater();
        if(generation!=loadGeneration_)return; // Revoked/replaced identities never return late.
        if(!data->error.isEmpty()){error_=data->error;emit modelChanged();return;}
        for(int i=0;i<data->parts.size();++i){auto& p=data->parts[i];
            p.geometry=new QQuick3DGeometry;p.geometry->setStride(sizeof(Vertex));using A=QQuick3DGeometry::Attribute;
            p.geometry->addAttribute(A::PositionSemantic,offsetof(Vertex,p),A::F32Type);p.geometry->addAttribute(A::NormalSemantic,offsetof(Vertex,n),A::F32Type);
            p.geometry->addAttribute(A::TexCoord0Semantic,offsetof(Vertex,uv),A::F32Type);p.geometry->addAttribute(A::ColorSemantic,offsetof(Vertex,color),A::F32Type);
            if(gpuSkinning_&&p.skin>=0){
                p.geometry->addAttribute(A::JointSemantic,offsetof(Vertex,joints),A::I32Type);
                p.geometry->addAttribute(A::WeightSemantic,offsetof(Vertex,weights),A::F32Type);
            }
            p.geometry->addAttribute(A::IndexSemantic,0,A::U32Type);p.geometry->setPrimitiveType(QQuick3DGeometry::PrimitiveType::Triangles);p.geometry->setIndexData(p.indices);
            auto material=data->materials[i].toMap();material["geometry"]=QVariant::fromValue(p.geometry);material["skin"]=gpuSkinning_?p.skin:-1;parts_.append(material);
        }
        d_=data;clipSeconds_=0;dirty_=true;clock_.restart();
        try{frame();if(running_)timer_.start();}catch(const std::exception& e){parts_.clear();d_.reset();error_=QString::fromUtf8(e.what());}
        emit modelChanged();emit changed();
    });
    watcher->setFuture(QtConcurrent::run([value,gpu=gpuSkinning_,cancelled=cancelled_]{
      auto data=std::make_shared<Data>();
      try {
        Glb g(value,cancelled);
        const auto nodes=g.json["nodes"].toArray(),meshes=g.json["meshes"].toArray(),materials=g.json["materials"].toArray();require(nodes.size()<=4096);
        for(const auto& v:nodes){auto o=v.toObject();Data::Node n;n.name=o["name"].toString();n.p=vec(o["translation"].toArray());n.s=vec(o["scale"].toArray(),{1,1,1});n.r=quat(o["rotation"].toArray());
            if(o.contains("matrix")){QVector<float> a;for(const auto& x:o["matrix"].toArray())a.append(x.toDouble());n.matrix=mat(a,0);n.matrixSet=true;
                if(gpu){ // glTF node matrices are decomposable TRS; keep the real hierarchy.
                    n.p=n.matrix.column(3).toVector3D();QMatrix3x3 rotation;
                    for(int c=0;c<3;++c){auto axis=n.matrix.column(c).toVector3D();n.s[c]=axis.length();require(n.s[c]>1e-8);axis/=n.s[c];for(int r=0;r<3;++r)rotation(r,c)=axis[r];}
                    if(n.matrix.determinant()<0){n.s[0]=-n.s[0];for(int r=0;r<3;++r)rotation(r,0)=-rotation(r,0);}
                    n.r=QQuaternion::fromRotationMatrix(rotation);QMatrix4x4 rebuilt;rebuilt.translate(n.p);rebuilt.rotate(n.r);rebuilt.scale(n.s);
                    for(int c=0;c<16;++c)require(std::abs(rebuilt.constData()[c]-n.matrix.constData()[c])<.0001f);
                    n.matrixSet=false;
                }
            }
            for(const auto& w:o["weights"].toArray())n.weights.append(w.toDouble());data->nodes.append(n);}
        for(int i=0;i<nodes.size();++i)for(const auto& child:nodes[i].toObject()["children"].toArray()){const int c=child.toInt(-1);require(c>=0&&c<nodes.size()&&data->nodes[c].parent==-1);data->nodes[c].parent=i;}
        QSet<int> visited;std::function<void(int)> mark=[&](int i){require(i>=0&&i<nodes.size()&&!visited.contains(i));visited.insert(i);data->nodes[i].live=true;for(auto c:nodes[i].toObject()["children"].toArray())mark(c.toInt(-1));};
        const auto scenes=g.json["scenes"].toArray();const int si=g.json["scene"].toInt();require(si>=0&&si<scenes.size());for(auto r:scenes[si].toObject()["nodes"].toArray())mark(r.toInt(-1));
        for(const auto& v:g.json["skins"].toArray()){const auto o=v.toObject();Data::Skin skin;QVector<float> matrices;if(o.contains("inverseBindMatrices"))matrices=g.accessor(o["inverseBindMatrices"].toInt());
            for(const auto& j:o["joints"].toArray()){const int id=j.toInt(-1);require(id>=0&&id<nodes.size());skin.nodes.append(id);skin.inverse.append(matrices.isEmpty()?QMatrix4x4():mat(matrices,(skin.nodes.size()-1)*16));}data->skins.append(skin);}
        QStringList textures;const QString cache=QStandardPaths::writableLocation(QStandardPaths::CacheLocation)+"/avatar-textures";require(QDir().mkpath(cache));
        for(const auto& image:g.json["images"].toArray()){const auto o=image.toObject();require(o.contains("bufferView")&&!o.contains("uri"));const auto views=g.json["bufferViews"].toArray();const int id=o["bufferView"].toInt(-1);require(id>=0&&id<views.size());const auto view=views[id].toObject();const int start=view["byteOffset"].toInt(),size=view["byteLength"].toInt();require(start>=0&&size>0&&qint64(start)+size<=g.binary.size());const auto bytes=g.binary.mid(start,size);
            const auto path=cache+"/"+QString::fromLatin1(QCryptographicHash::hash(bytes,QCryptographicHash::Sha256).toHex())+(o["mimeType"]=="image/jpeg"?".jpg":".png");
            if(!QFile::exists(path)){QSaveFile file(path);require(file.open(QIODevice::WriteOnly)&&file.write(bytes)==bytes.size()&&file.commit());}textures.append(QUrl::fromLocalFile(path).toString());}
        for(int ni=0;ni<nodes.size();++ni){const auto node=nodes[ni].toObject();if(!data->nodes[ni].live||!node.contains("mesh"))continue;const int mi=node["mesh"].toInt(-1);require(mi>=0&&mi<meshes.size());const auto mesh=meshes[mi].toObject();
            if(data->nodes[ni].weights.isEmpty())for(const auto& w:mesh["weights"].toArray())data->nodes[ni].weights.append(w.toDouble());
            for(const auto& pv:mesh["primitives"].toArray()){
                const auto primitive=pv.toObject(),attributes=primitive["attributes"].toObject();require(primitive["mode"].toInt(4)==4&&attributes.contains("POSITION"));
                Data::Part p;p.node=ni;p.skin=node["skin"].toInt(-1);require(p.skin<0||p.skin<data->skins.size());
                const auto positions=g.accessor(attributes["POSITION"].toInt());const int count=positions.size()/3;require(count>0&&count<=500000);p.base.resize(count);data->vertices+=count;require(data->vertices<=500000);
                auto attribute=[&](const char* name,int width){auto a=attributes.contains(name)?g.accessor(attributes[name].toInt()):QVector<float>();require(a.isEmpty()||a.size()==count*width);return a;};
                const auto normals=attribute("NORMAL",3),uv=attribute("TEXCOORD_0",2);QVector<float> colors;if(attributes.contains("COLOR_0"))colors=g.accessor(attributes["COLOR_0"].toInt());require(colors.isEmpty()||colors.size()==count*3||colors.size()==count*4);
                p.joints=attribute("JOINTS_0",4);p.weights=attribute("WEIGHTS_0",4);require(p.skin<0||(!p.joints.isEmpty()&&!p.weights.isEmpty()));
                for(int i=0;i<count;++i){auto& v=p.base[i];for(int c=0;c<3;++c){v.p[c]=positions[i*3+c];v.n[c]=normals.isEmpty()?(c==1?1:0):normals[i*3+c];}for(int c=0;c<2;++c)v.uv[c]=uv.isEmpty()?0:uv[i*2+c];for(int c=0;c<4;++c)v.color[c]=colors.isEmpty()||c>=colors.size()/count?1:colors[i*(colors.size()/count)+c];}
                if(p.skin>=0)for(int i=0;i<count;++i)for(int j=0;j<4;++j){const int bone=int(p.joints[i*4+j]);
                    require(bone>=0&&bone<data->skins[p.skin].nodes.size());p.base[i].joints[j]=bone;p.base[i].weights[j]=p.weights[i*4+j];}
                for(const auto& name:mesh["extras"].toObject()["targetNames"].toArray())p.names.append(name.toString());
                for(const auto& tv:primitive["targets"].toArray()){const auto target=tv.toObject();const auto dp=target.contains("POSITION")?g.accessor(target["POSITION"].toInt()):QVector<float>();const auto dn=target.contains("NORMAL")?g.accessor(target["NORMAL"].toInt()):QVector<float>();require((dp.isEmpty()||dp.size()==count*3)&&(dn.isEmpty()||dn.size()==count*3));QVector<Delta> deltas;
                    for(int i=0;i<count;++i){const auto a=dp.isEmpty()?QVector3D():vec(dp,i*3),b=dn.isEmpty()?QVector3D():vec(dn,i*3);if(!a.isNull()||!b.isNull())deltas.append({i,a,b});}p.morphs.append(std::move(deltas));}
                QVector<quint32> indices;if(primitive.contains("indices")){for(float f:g.accessor(primitive["indices"].toInt())){require(f>=0&&f<count);indices.append(quint32(f));}}else for(int i=0;i<count;++i)indices.append(i);require(indices.size()%3==0);
                p.indices=QByteArray(reinterpret_cast<const char*>(indices.constData()),indices.size()*sizeof(quint32));
                const int materialId=primitive["material"].toInt(-1);const auto material=materialId>=0&&materialId<materials.size()?materials[materialId].toObject():QJsonObject();const auto pbr=material["pbrMetallicRoughness"].toObject();const auto col=pbr["baseColorFactor"].toArray();QColor color=Qt::white;if(col.size()==4)color=QColor::fromRgbF(srgb(col[0].toDouble()),srgb(col[1].toDouble()),srgb(col[2].toDouble()),col[3].toDouble());
                QString texture;const int ti=pbr["baseColorTexture"].toObject()["index"].toInt(-1);const auto tx=g.json["textures"].toArray();if(ti>=0&&ti<tx.size())texture=textures.value(tx[ti].toObject()["source"].toInt(-1));
                data->materials.append(QVariantMap{{"color",color},{"texture",texture},{"roughness",pbr["roughnessFactor"].toDouble(1)},{"metalness",pbr["metallicFactor"].toDouble(0)},{"doubleSided",material["doubleSided"].toBool()},{"alphaMode",material["alphaMode"].toString("OPAQUE")},{"alphaCutoff",material["alphaCutoff"].toDouble(.5)}});data->parts.append(std::move(p));
            }
        }
        const auto faceRig=g.json["extras"].toObject()["trainerFace"].toObject();
        data->expressions=faceRig["expressions"].toObject();for(const auto& key:faceRig["controls"].toArray())data->controls.insert(key.toString());
        for(const auto& av:g.json["animations"].toArray()){const auto a=av.toObject();Data::Clip clip;const auto samplers=a["samplers"].toArray();
            for(const auto& cv:a["channels"].toArray()){const auto c=cv.toObject(),target=c["target"].toObject();const int si=c["sampler"].toInt(-1);require(si>=0&&si<samplers.size());const auto s=samplers[si].toObject();Data::Track t;t.node=target["node"].toInt(-1);require(t.node>=0&&t.node<nodes.size());t.path=target["path"].toString();t.times=g.accessor(s["input"].toInt());t.values=g.accessor(s["output"].toInt());t.interpolation=s["interpolation"].toString("LINEAR");require(!t.times.isEmpty()&&(t.interpolation=="LINEAR"||t.interpolation=="STEP"));t.width=t.values.size()/t.times.size();require(t.width>0&&t.values.size()==t.times.size()*t.width);clip.duration=std::max(clip.duration,t.times.last());clip.tracks.append(std::move(t));}data->clips.insert(a["name"].toString(),std::move(clip));}
      }catch(const std::exception& e){data->error=QString::fromUtf8(e.what());}
      return data;
    }));
}
void AvatarScene::frame(){
    if(!d_)return;
    const double dt=std::clamp(clock_.restart()/1000.,0.,.1);if(running_)clipSeconds_+=dt;
    bool updateNeeded=dirty_||(!clip_.isEmpty()&&clipPosition_<0)||!d_->transition.isEmpty();dirty_=false;
    const float smoothing=running_?float(1-std::exp(-dt/0.12)):1.f;
    auto expression=d_->expressions[expression_].toObject();
    for(auto i=face_.begin();i!=face_.end();++i)if(d_->controls.contains(i.key()))expression[i.key()]=std::clamp(i.value().toDouble(),0.,1.);
    QSet<QString> faceKeys;for(auto i=d_->face.begin();i!=d_->face.end();++i)faceKeys.insert(i.key());for(auto i=expression.begin();i!=expression.end();++i)faceKeys.insert(i.key());
    for(const auto& key:faceKeys){const float target=expression[key].toDouble();float& v=d_->face[key];if(v!=target){v+=(target-v)*smoothing;if(std::abs(target-v)<.001)v=target;updateNeeded=true;}}
    QSet<QString> poseKeys;for(auto i=d_->pose.begin();i!=d_->pose.end();++i)poseKeys.insert(i.key());for(auto i=pose_.begin();i!=pose_.end();++i)poseKeys.insert(i.key());
    for(const auto& key:poseKeys){const auto target=pose_.value(key).value<QVector3D>();auto& v=d_->pose[key];if(v!=target){v+=(target-v)*smoothing;if((target-v).lengthSquared()<.0001)v=target;updateNeeded=true;}}
    if(!updateNeeded)return;
    auto nodes=d_->nodes;const float seconds=clipSeconds_;
    const auto found=d_->clips.constFind(clip_);if(found!=d_->clips.cend()){
        const auto& clip=found.value();const float t=clipPosition_>=0?clip.duration*clipPosition_:clip.duration>0?std::fmod(seconds,clip.duration):0;
        for(const auto& track:clip.tracks){const auto high=std::upper_bound(track.times.begin(),track.times.end(),t);const int a=std::clamp(int(high-track.times.begin())-1,0,int(track.times.size())-1),b=std::min(a+1,int(track.times.size())-1);const float span=track.times[b]-track.times[a];const float blend=track.interpolation=="STEP"||span<=0?0:std::clamp((t-track.times[a])/span,0.f,1.f);QVector<float> v(track.width);for(int c=0;c<track.width;++c)v[c]=track.values[a*track.width+c]*(1-blend)+track.values[b*track.width+c]*blend;
            auto& n=nodes[track.node];if(track.path=="translation"&&v.size()==3)n.p=vec(v,0);else if(track.path=="scale"&&v.size()==3)n.s=vec(v,0);else if(track.path=="rotation"&&v.size()==4){const auto& q=track.values;const int x=a*4,y=b*4;n.r=QQuaternion::slerp(QQuaternion(q[x+3],q[x],q[x+1],q[x+2]),QQuaternion(q[y+3],q[y],q[y+1],q[y+2]),blend);}else if(track.path=="weights")n.weights=v;
        }
    }
    // Blend from the actual last sampled pose, including interrupted transitions.
    // Procedural offsets below retain their own smoothing and are not applied twice.
    if(d_->transition.size()==nodes.size()){
        d_->transitionTime+=dt;const float t=running_?std::min(1.f,d_->transitionTime/.32f):1.f;
        const float a=t*t*(3-2*t);
        for(int i=0;i<nodes.size();++i){auto& n=nodes[i];const auto& from=d_->transition[i];
            n.p=from.p*(1-a)+n.p*a;n.s=from.s*(1-a)+n.s*a;n.r=QQuaternion::slerp(from.r,n.r,a);
            for(int j=0;j<n.weights.size();++j)n.weights[j]=from.weights.value(j)*(1-a)+n.weights[j]*a;
        }
        if(t>=1)d_->transition.clear();
    }
    d_->animated=nodes;
    for(auto& node:nodes)if(d_->pose.contains(node.name))node.r*=QQuaternion::fromEulerAngles(d_->pose[node.name]);
    QVector<QMatrix4x4> world(nodes.size());QVector<int> state(nodes.size(),0);
    std::function<void(int)> update=[&](int i){if(state[i]==2)return;require(state[i]!=1);state[i]=1;const auto& n=nodes[i];QMatrix4x4 local=n.matrix;if(!n.matrixSet){local.setToIdentity();local.translate(n.p);local.rotate(n.r);local.scale(n.s);}if(n.parent>=0){update(n.parent);world[i]=world[n.parent]*local;}else world[i]=local;state[i]=2;};
    for(int i=0;i<nodes.size();++i)update(i);
    if(gpuSkinning_){nodePoses_.clear();for(const auto& node:nodes)nodePoses_.append(QVariantMap{
        {"parent",node.parent},{"position",QVariant::fromValue(node.p)},
        {"rotation",QVariant::fromValue(node.r)},{"scale",QVariant::fromValue(node.s)}});}
    sockets_.clear();
    for(int i=0;i<nodes.size();++i)if(nodes[i].name=="hand.R"||nodes[i].name=="hand.L"||nodes[i].name=="head"){
        const auto position=world[i].map(QVector3D());
        QMatrix3x3 rotation;for(int c=0;c<3;++c){QVector3D axis(world[i](0,c),world[i](1,c),world[i](2,c));axis.normalize();for(int r=0;r<3;++r)rotation(r,c)=axis[r];}
        sockets_[nodes[i].name]=QVariantMap{{"position",QVariant::fromValue(position)},{"rotation",QVariant::fromValue(QQuaternion::fromRotationMatrix(rotation))}};
        if(nodes[i].name=="hand.R")rightHand_=position;
    }
    QVector<QVector<QMatrix4x4>> transforms;QVector<QVector<QMatrix3x3>> normals;
    if(!gpuSkinning_)for(const auto& skin:d_->skins){QVector<QMatrix4x4> ts;QVector<QMatrix3x3> ns;for(int i=0;i<skin.nodes.size();++i){ts.append(world[skin.nodes[i]]*skin.inverse[i]);ns.append(ts.last().normalMatrix());}transforms.append(ts);normals.append(ns);}
    for(auto& part:d_->parts){const auto& weights=nodes[part.node].weights;
        QVector<float> morph;for(int m=0;m<part.morphs.size();++m)morph.append(d_->face.contains(part.names.value(m))?d_->face.value(part.names.value(m)):weights.value(m));
        if(gpuSkinning_&&part.skin>=0&&part.uploaded&&morph==part.lastMorph)continue;
        part.lastMorph=morph;auto vertices=part.base;
        for(int m=0;m<part.morphs.size();++m){const float weight=morph[m];if(std::abs(weight)<.00001)continue;for(const auto& delta:part.morphs[m]){auto& v=vertices[delta.vertex];for(int c=0;c<3;++c){v.p[c]+=delta.p[c]*weight;v.n[c]+=delta.n[c]*weight;}}}
        if(gpuSkinning_&&part.skin>=0){
            if(!part.uploaded){float radius=1;for(const auto& v:std::as_const(part.base))radius=std::max(radius,4*QVector3D(v.p[0],v.p[1],v.p[2]).length()+1);
                part.geometry->setBounds(QVector3D(-radius,-radius,-radius),QVector3D(radius,radius,radius));}
            // Bone/normal transformation and normalization belong to Qt's skin
            // shader. Only a changed morph needs new bind-space vertex bytes.
            part.geometry->setVertexData(QByteArray(reinterpret_cast<const char*>(vertices.constData()),vertices.size()*sizeof(Vertex)));
            part.geometry->update();part.uploaded=true;++geometryUploads_;continue;
        }
        QVector3D lo(1e9,1e9,1e9),hi(-1e9,-1e9,-1e9);const auto nm=world[part.node].normalMatrix();
        for(int i=0;i<vertices.size();++i){auto& v=vertices[i];const QVector3D p(v.p[0],v.p[1],v.p[2]),n(v.n[0],v.n[1],v.n[2]);QVector3D pos,norm;
            if(part.skin>=0){for(int j=0;j<4;++j){const float w=part.weights[i*4+j];if(w==0)continue;const int id=int(part.joints[i*4+j]);if(id<0||id>=transforms[part.skin].size())continue;pos+=transforms[part.skin][id].map(p)*w;norm+=normal(normals[part.skin][id],n)*w;}}
            else {pos=world[part.node].map(p);norm=normal(nm,n);}norm.normalize();for(int c=0;c<3;++c){v.p[c]=pos[c];v.n[c]=norm[c];lo[c]=std::min(lo[c],pos[c]);hi[c]=std::max(hi[c],pos[c]);}
        }
        part.geometry->setBounds(lo,hi);part.geometry->setVertexData(QByteArray(reinterpret_cast<const char*>(vertices.constData()),vertices.size()*sizeof(Vertex)));part.geometry->update();part.uploaded=true;++geometryUploads_;
    }
    emit frameChanged();
}
}
