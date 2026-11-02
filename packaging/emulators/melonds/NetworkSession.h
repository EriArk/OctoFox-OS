// SPDX-License-Identifier: GPL-3.0-or-later
#pragma once
#include "NativeSession.h"
#include <QJsonObject>
#include <QString>
#include <optional>
namespace traineros::ds {
// Shared frontend boundary. The two-player protocol remains available unchanged.
class NetworkSession {
public:
    struct OwnerSeed {uint32_t expectedSize=0;std::optional<std::vector<uint8_t>> bytes;};
    virtual ~NetworkSession()=default;
    virtual bool Ready() const=0;
    virtual bool StartupReady() const=0;
    virtual std::optional<std::vector<uint8_t>> TakePeerState(unsigned seat)=0;
    virtual void MachinesReady()=0;
    virtual bool Failed() const=0;
    virtual QString Failure() const=0;
    virtual uint64_t VerifiedChecks() const=0;
    virtual unsigned Delay() const=0;
    virtual bool Finishing() const=0;
    virtual std::optional<uint32_t> EndFrame() const=0;
    virtual bool ReturnSafe() const=0;
    virtual void OwnerRetained()=0;
    virtual bool Finished() const=0;
    virtual void Tick(uint32_t next)=0;
    virtual void Finish(uint32_t next)=0;
    virtual bool Inputs(uint32_t frame,FrameInput live,std::vector<FrameInput>& result)=0;
    virtual void Committed(uint32_t frame)=0;
    virtual void Checkpoint(const FrameResult& value)=0;
};
}
