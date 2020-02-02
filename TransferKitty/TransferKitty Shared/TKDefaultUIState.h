#pragma once

#include <string>
#include <unordered_set>

#include "EASTL/bonus/ring_buffer.h"
#include "TKIUIState.h"
#include "TKOptional.h"

namespace tk {

class DefaultUIFilePreview : public IUIFilePreview {
public:
};

class DefaultUIFileState : public IUIFileState {
public:
    std::string _name = "";
    UIFileStatus _status = UIFileStatusUnknown;
    size_t _bytesProcessed = 0;
    size_t _totalSizeInBytes = 0;
    Optional<DefaultUIFilePreview> _preview = {};

public:
    StringView name() const override { return {_name.c_str(), _name.size()}; }
    UIFileStatus status() const override { return _status; }
    size_t bytesProcessed() const override { return _bytesProcessed; }
    size_t totalSizeInBytes() const override { return _totalSizeInBytes; }
    const IUIFilePreview* preview() const override { return _preview.get(); }
};

class DefaultUIDeviceState : public IUIDeviceState {
public:
    uint64_t _hash = 0;
    BridgedHandle _deviceHandle = nullptr;
    std::string _name = "";
    std::string _model = "";
    std::string _friendlyModel = "";
    std::string _uuidString = "";
    std::vector<DefaultUIFileState> _files = {};
    UIStateStatus _status = UIStateStatusBitUnknown;

public:
    const UIStateStatus status() const override { return _status; }
    size_t fileCount() const override { return _files.size(); }
    const IUIFileState* file(size_t index) const override { return &_files[index]; }
    StringView name() const override { return StringView{_name.c_str(), _name.size()}; }
    StringView model() const override { return StringView{_model.c_str(), _model.size()}; }
    StringView friendlyModel() const override { return StringView{_friendlyModel.c_str(), _friendlyModel.size()}; }
    StringView uuidString() const override { return StringView{_uuidString.c_str(), _uuidString.size()}; }
};

class DefaultUIState : public IUIState {
public:
    std::vector<DefaultUIDeviceState> _devices = {};
    eastl::ring_buffer<std::string> _debugLogs{256};
    bool _didClickSendButton = false;

public:
    void didClickSendButton() override { _didClickSendButton = true; }

    size_t deviceCount() const override { return _devices.size(); }
    const IUIDeviceState* device(size_t index) const override { return &_devices[index]; }

    size_t debugLogCount() const override { return _debugLogs.size(); }
    StringView debugLog(size_t index) const override {
        auto& log = _debugLogs[index];
        return StringView{log.c_str(), log.size()};
    }
};

} // namespace tk
