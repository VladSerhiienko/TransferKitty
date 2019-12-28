#pragma once

#include <string>

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
    const IUIFileState* file(int index) const override { return &_files[index]; }
};

class DefaultUIState : public IUIState {
public:
    std::vector<DefaultUIDeviceState> _devices = {};

public:
    size_t deviceCount() const override { return _devices.size(); }
    const IUIDeviceState* device(int index) const override { return &_devices[index]; }
};

} // namespace tk
