#pragma once

#include <string>

#include "TKIUIState.h"
#include "TKOptional.h"
#include "EASTL/bonus/ring_buffer.h"

namespace tk {

class DefaultUIFilePreview : public IUIFilePreview {
public:
};

class DefaultUIFileState : public IUIFileState {
public:
    std::string _name = "";
    UIFileStatus _status = UIFileStatusUnknown;
    float _progress = 0.0f;
    size_t _byteSize = 0;
    Optional<DefaultUIFilePreview> _preview = {};

public:
    StringView name() const override { return {_name.c_str(), _name.size()}; }
    UIFileStatus status() const override { return _status; }
    float progress() const override { return _progress; }
    size_t byteSize() const override { return _byteSize; }
    const IUIFilePreview* preview() const override { return _preview.get(); }
};

class DefaultUIDeviceState : public IUIDeviceState {
public:
    std::vector<DefaultUIFileState> _files = {};
    UIStateStatus _status = UIStateStatusBitUnknown;

public:
    const UIStateStatus status() const override { return _status; }
    size_t fileCount() const override { return _files.size(); }
    const IUIFileState* file(size_t index) const override { return &_files[index]; }
};

class DefaultUIState : public IUIState {
public:
    std::vector<DefaultUIDeviceState> _devices = {};
    eastl::ring_buffer<std::string> _debugLogs{256};

public:
    size_t deviceCount() const override { return _devices.size(); }
    const IUIDeviceState* device(size_t index) const override { return &_devices[index]; }
    
    size_t debugLogCount() const override { return _debugLogs.size(); }
    StringView debugLog(size_t index) const override { auto& log = _debugLogs[index]; return StringView{log.c_str(), log.size()}; }
};

} // namespace tk
