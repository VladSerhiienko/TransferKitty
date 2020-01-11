#pragma once
#include <cstdint>

namespace tk {
enum UIFileStatus {
    UIFileStatusUnknown = 0,
    UIFileStatusPrepared,
    UIFileStatusQueued,
    UIFileStatusSending,
    UIFileStatusSent,
    UIFileStatusReceiving,
    UIFileStatusReceived,
};

using UIStateStatus = uint64_t;
enum UIStateStatusBits : uint64_t {
    UIStateStatusBitUnknown = 0,
    UIStateStatusBitPeripheral = 1 << 0,
    UIStateStatusBitCentral = 1 << 1,
    UIStateStatusBitPreparedFiles = 1 << 2,
    UIStateStatusBitPreparingFiles = 1 << 3,
    UIStateStatusBitScanning = 1 << 4,
    UIStateStatusBitAdvertising = 1 << 5,
    UIStateStatusBitSending = 1 << 6,
    UIStateStatusBitReceiving = 1 << 7,
};

struct StringView {
    const char* data = nullptr;
    size_t size = 0;
};

class IUIFilePreview {
public:
};

class IUIFileState {
public:
    virtual StringView name() const = 0;
    virtual UIFileStatus status() const = 0;
    virtual float progress() const = 0;
    virtual size_t byteSize() const = 0;
    virtual const IUIFilePreview* preview() const = 0;
};

class IUIDeviceState {
public:
    virtual const UIStateStatus status() const = 0;
    virtual size_t fileCount() const = 0;
    virtual const IUIFileState* file(size_t index) const = 0;
};

class IUIState {
public:
    virtual size_t deviceCount() const = 0;
    virtual const IUIDeviceState* device(size_t index) const = 0;
    
    virtual size_t debugLogCount() const = 0;
    virtual StringView debugLog(size_t index) const = 0;
};

} // namespace tk
