#pragma once
#include <cstdint>

namespace tk {
enum UIFileStatus {
    UIFileStatusPrepared = 0,
    UIFileStatusQueued,
    UIFileStatusSending,
    UIFileStatusSent,
    UIFileStatusReceiving,
    UIFileStatusReceived,
};

using UIStateStatus = uint64_t;
enum UIStateStatusBits : uint64_t {
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
    virtual StringView name() const;
    virtual UIFileStatus status() const = 0;
    virtual float progress() const = 0;
    virtual size_t byteSize() const = 0;
    virtual const IUIFilePreview* preview() const = 0;
};

class IUIDeviceState {
    virtual size_t fileCount() const = 0;
    virtual const IUIFileState* file(int index) const = 0;
};

class IUIState {
public:
    virtual const UIStateStatus status() const = 0;
    virtual const IUIDeviceState* device(int index) const = 0;
    virtual size_t connectedDeviceCount() const = 0;
    virtual const IUIDeviceState* connectedDevice(int index) const = 0;
};

}
