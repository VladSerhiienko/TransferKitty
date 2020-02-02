#import "TKBluetoothCommunicator.h"
#import "TKDeviceInfoUtilities.h"
#import "TKFileSaver.h"

#if TARGET_OS_IOS
#import <UIKit/UIKit.h>
#endif

#include <stdatomic.h>
#include <chrono>

#ifndef TK_UUID_KEY
#define TK_UUID_KEY @"BluetoothCommunicatorUUID"
#endif

#ifndef TK_PERIPHERAL_NO_IMPLICIT_ADVERTISING
#define TK_PERIPHERAL_ONE_SUBSCRIPTION 1
#define TK_PERIPHERAL_IMPLICIT_ADVERTISING 1
#endif

using tk::setBit;
using tk::hasBit;
using tk::unsetBit;

// static const NSTimeInterval kScanningTimeoutSeconds   = 10.0;
// static const NSTimeInterval kConnectingTimeoutSeconds = 30.0;
// static const NSTimeInterval kRequestTimeoutSeconds    = 20.0;

@interface TKBluetoothCommunicatorDevice ()

@property(nonatomic, assign) TKBluetoothCommunicator *bluetoothCommunicator;
@property(nonatomic, assign) NSInteger localId;
@property(nonatomic, assign) NSInteger mtu;
@property(nonatomic, strong) CBCentral *central;
@property(nonatomic, strong) CBPeripheral *peripheral;
@property(nonatomic, strong) CBService *service;
@property(nonatomic, strong) CBCharacteristic *characteristic;
@property(nonatomic, strong) NSString *deviceName;
@property(nonatomic, strong) NSString *deviceModel;
@property(nonatomic, strong) NSString *deviceFriendlyModel;
@property(nonatomic, strong) NSUUID *deviceUUID;
@property(atomic, assign) bool pendingWriteValue;

@end

@implementation TKBluetoothCommunicatorDevice
- (NSInteger)getId {
    return [self localId];
}
- (NSInteger)getMTU {
    return [self mtu];
}
- (NSUUID *)getUUID {
    return [self deviceUUID];
}
- (NSString *)getName {
    return [self deviceName];
}
- (NSString *)getModel {
    return [self deviceModel];
}
- (NSString *)getFriendlyModel {
    return [self deviceFriendlyModel];
}

- (instancetype)init {
    [self setDeviceName:[TKStringUtilities empty]];
    [self setDeviceModel:[TKStringUtilities empty]];
    [self setDeviceFriendlyModel:[TKStringUtilities empty]];
    return self;
}
- (void)setUUID:(NSUUID *)uuid {
    [self setDeviceUUID:uuid];
    [[self bluetoothCommunicator] bluetoothCommunicatorDeviceDidUpdateProperty:self];
}
- (void)setName:(NSString *)name {
    [self setDeviceName:name];
    [[self bluetoothCommunicator] bluetoothCommunicatorDeviceDidUpdateProperty:self];
}
- (void)setModel:(NSString *)model {
    [self setDeviceModel:model];
    [[self bluetoothCommunicator] bluetoothCommunicatorDeviceDidUpdateProperty:self];
}
- (void)setFriendlyModel:(NSString *)friendlyModel {
    [self setDeviceFriendlyModel:friendlyModel];
    [[self bluetoothCommunicator] bluetoothCommunicatorDeviceDidUpdateProperty:self];
}
- (NSObject *)dictKey {
    DCHECK(self.peripheral || self.central);
    return self.peripheral ? self.peripheral : self.central;
}

- (BOOL)isEqual:(id)object {
    if (nil == object) { return false; }
    if (self == object) { return true; }
    if (![object isKindOfClass:[self class]]) { return false; }

    TKBluetoothCommunicatorDevice *other = object;
    DCHECK(self.peripheral || self.central);
    return (self.peripheral && [self.peripheral isEqual:[other peripheral]]) ||
           (self.central && [self.central isEqual:[other central]]);
}

- (NSUInteger)hash {
    DCHECK(self.peripheral || self.central);
    return self.peripheral ? [self.peripheral hash] : [self.central hash];
}

- (id)copyWithZone:(NSZone *)zone {
    return self;
    // id copy = [[[self class] alloc] init];
    // [copy setBluetoothCommunicator:[self bluetoothCommunicator]];
    // [copy setLocalId:[self localId]];
    // [copy setMtu:[self mtu]];
    // [copy setCentral:[self central]];
    // [copy setPeripheral:[self peripheral]];
    // [copy setService:[self service]];
    // [copy setCharacteristic:[self characteristic]];
    // [copy setDeviceName:[self deviceName]];
    // [copy setDeviceModel:[self deviceModel]];
    // [copy setDeviceFriendlyModel:[self deviceFriendlyModel]];
    // [copy setDeviceUUID:[self deviceUUID]];
    // [copy setPendingWriteValue:[self pendingWriteValue]];
    // return copy;
}

@end

@interface TKBluetoothCommunicator () <CBCentralManagerDelegate, CBPeripheralDelegate>
@end

@interface TKBluetoothCommunicator () <CBPeripheralManagerDelegate>
@end

@interface TKBluetoothCommunicator () <TKDebugLogger>
@end

@implementation TKBluetoothCommunicator {
    CBPeripheralManager *_peripheralManager;
    CBService *_peripheralService;
    CBMutableCharacteristic *_peripheralCharacteristic;

    CBCentralManager *_centralManager;
    NSUInteger _statusBits;
    id<TKBluetoothCommunicatorDelegate> _delegate;
    NSArray<CBUUID *> *_serviceUUIDs;
    NSArray<CBUUID *> *_characteristicUUIDs;
    NSArray<CBUUID *> *_descriptorUUIDs;
    NSMutableSet *_connectingDevices;
    NSMutableDictionary *_connectedDevices;
    NSUUID *_UUID;
    NSString *_name;
    NSString *_model;
    NSString *_friendlyModel;
    atomic_bool _scanningFlag;
    TKBluetoothCommunicatorScheduler *_scheduler;
}

//
// C o m m o n
//

static TKBluetoothCommunicator *_instance = nil;
+ (id)instance {
    @synchronized(self) {
        if (_instance == nil) {
            _instance = [[self alloc] init];
            [TKDebug addDebugLogger:_instance];
        }
    }

    return _instance;
}

- (void)prepareUUIDs {
    // DLOGF(@"%s", TK_FUNC_NAME);

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *stringUUID = [defaults objectForKey:TK_UUID_KEY];
    NSUUID *deviceUUID = nil;

    if (stringUUID == nil || [stringUUID length] == 0) {
        // DLOGF(@"%s, adding UUID to standard user defaults", TK_FUNC_NAME);
        deviceUUID = [NSUUID UUID];
        stringUUID = [deviceUUID UUIDString];
        [defaults setObject:stringUUID forKey:TK_UUID_KEY];
        [defaults synchronize];
    } else {
        deviceUUID = [[NSUUID alloc] initWithUUIDString:stringUUID];
    }

    // DLOGF(@"%s: UUID %@", TK_FUNC_NAME, deviceUUID);

    _UUID = deviceUUID;
    _serviceUUIDs = @[ [CBUUID UUIDWithString:@"07BDC246-B8DD-4240-9743-EDD6B9AFF20F"] ];
    _characteristicUUIDs = @[ [CBUUID UUIDWithString:@"4035D667-4896-4C38-8010-837506F54932"] ];
    _descriptorUUIDs = @[
        [CBUUID UUIDWithString:@"00002902-0000-1000-8000-00805f9b34fb"],
        [CBUUID UUIDWithString:@"00002901-0000-1000-8000-00805f9b34fb"]
    ];

    // DLOGF(@"%s: Service UUID %@", TK_FUNC_NAME, [_serviceUUIDs objectAtIndex:0]);
    // DLOGF(@"%s: Characteristic UUID %@", TK_FUNC_NAME, [_characteristicUUIDs objectAtIndex:0]);
    // DLOGF(@"%s: Descriptor Client Config UUID %@", TK_FUNC_NAME, [_descriptorUUIDs objectAtIndex:0]);
    // DLOGF(@"%s: Descriptor User Description UUID %@", TK_FUNC_NAME, [_descriptorUUIDs objectAtIndex:1]);
}
- (void)prepareName {
    // DLOGF(@"%s", TK_FUNC_NAME);
    _name = [TKDeviceInfoUtilities name];
    _model = [TKDeviceInfoUtilities modelName];
    _friendlyModel = [TKDeviceInfoUtilities friendlyModelName];
}

// clang-format off
- (NSUInteger)statusBits                        { return _statusBits; }
- (NSUUID *)getUUID                             { return _UUID; }
- (NSString *)getName                           { return _name; }
- (NSString *)getModel                          { return _model; }
- (NSString *)getFriendlyModel                  { return _friendlyModel; }
- (TKBluetoothCommunicatorScheduler*)scheduler  { return _scheduler; }
- (TKBluetoothCommunicatorEncoder*)encoder      { return [_scheduler bluetoothCommunicatorEncoder]; }
- (TKBluetoothCommunicatorDecoder*)decoder      { return [_scheduler bluetoothCommunicatorDecoder]; }
// clang-format on

//
// P e r i p h e r a l
//

- (void)initPeripheralWithDelegate:(id<TKBluetoothCommunicatorDelegate>)delegate {
    // DLOGF(@"%s", TK_FUNC_NAME);
    if (hasBit(_statusBits,
               TKBluetoothCommunicatorStatusBitStartingPeripheral | TKBluetoothCommunicatorStatusBitPeripheral)) {
        [TKDebug check:false
                  file:@__FILE__
                  line:__LINE__
                   tag:@"BluetoothCommunicator"
                   msg:@"Already running a peripheral role."];
        return;
    }

    atomic_store(&_scanningFlag, false);
    [self prepareUUIDs];
    [self prepareName];

    _delegate = delegate;
    _statusBits = TKBluetoothCommunicatorStatusBitStartingPeripheral;
    _scheduler = [[TKBluetoothCommunicatorScheduler alloc] initWithBluetoothCommunicator:self];
    _peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil options:nil];
}

// https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/PerformingCommonPeripheralRoleTasks/PerformingCommonPeripheralRoleTasks.html
- (void)publishServices {
    // clang-format off
    constexpr CBCharacteristicProperties properties = CBCharacteristicPropertyRead | CBCharacteristicPropertyWrite | CBCharacteristicPropertyNotify;
    constexpr CBAttributePermissions permissions = CBAttributePermissionsReadable | CBAttributePermissionsWriteable;
    // clang-format on

    // https://stackoverflow.com/questions/18622608/how-do-you-create-a-descriptor-for-a-mutable-characteristic

    CBUUID *userDescriptionUUID = [CBUUID UUIDWithString:CBUUIDCharacteristicUserDescriptionString];
    CBMutableDescriptor *userDescriptionDescriptor = [[CBMutableDescriptor alloc] initWithType:userDescriptionUUID
                                                                                         value:@"DATA_RESPOND"];

    NSArray<CBDescriptor *> *peripheralDescriptors = [[NSArray alloc] initWithObjects:userDescriptionDescriptor, nil];

    CBMutableCharacteristic *peripheralCharacteristic =
        [[CBMutableCharacteristic alloc] initWithType:[_characteristicUUIDs objectAtIndex:0]
                                           properties:properties
                                                value:nil
                                          permissions:permissions];
    peripheralCharacteristic.descriptors = peripheralDescriptors;

    CBMutableService *peripheralService = [[CBMutableService alloc] initWithType:[_serviceUUIDs objectAtIndex:0]
                                                                         primary:YES];
    peripheralService.characteristics = @[ peripheralCharacteristic ];

    NSUInteger statusBits = setBit(_statusBits, TKBluetoothCommunicatorStatusBitPublishingService);
    [self setStatusBits:statusBits];

    _peripheralService = peripheralService;
    _peripheralCharacteristic = peripheralCharacteristic;

    [_peripheralManager addService:peripheralService];
}

- (void)startAdvertising {
    if (hasBit(_statusBits, TKBluetoothCommunicatorStatusBitStartingAdvertising)) { return; }
    if (hasBit(_statusBits, TKBluetoothCommunicatorStatusBitAdvertising)) { return; }

    assert(_peripheralManager);
    assert(!_peripheralManager.isAdvertising);

    NSUInteger statusBits = setBit(_statusBits, TKBluetoothCommunicatorStatusBitStartingAdvertising);
    [self setStatusBits:statusBits];

    if (_connectedDevices == nil) {
        _connectedDevices = [[NSMutableDictionary alloc] init];
        _connectingDevices = [[NSMutableSet alloc] init];
        // DLOGF(@"%s: Created peripheral list.", TK_FUNC_NAME);
    } else {
        // DLOGF(@"%s: Clearing peripheral list.", TK_FUNC_NAME);
        [_connectedDevices removeAllObjects];
        [_connectingDevices removeAllObjects];
    }

    NSDictionary *advertisementData =
        @{CBAdvertisementDataServiceUUIDsKey : _serviceUUIDs, CBAdvertisementDataLocalNameKey : @"TK"};

    [_peripheralManager startAdvertising:advertisementData];
    // -> peripheralManagerDidStartAdvertising
}

- (void)stopAdvertising {
    if (hasBit(_statusBits, TKBluetoothCommunicatorStatusBitStartingAdvertising) ||
        hasBit(_statusBits, TKBluetoothCommunicatorStatusBitAdvertising)) {
        [_peripheralManager stopAdvertising];

        NSUInteger statusBits = unsetBit(_statusBits, TKBluetoothCommunicatorStatusBitStartingAdvertising);
        statusBits = unsetBit(statusBits, TKBluetoothCommunicatorStatusBitStartingAdvertising);
        [self setStatusBits:statusBits];
    }
}

// TODO: If has pending data, flush it here, or wait for the next opportunity.
- (void)peripheralManagerIsReadyToUpdateSubscribers:(CBPeripheralManager *)peripheral {
    // DLOGF(@"%s", TK_FUNC_NAME);
    [_scheduler flush];
}

// CBPeripheralManagerDelegate
- (void)peripheralManagerDidStartAdvertising:(CBPeripheralManager *)peripheralManager error:(NSError *)error {
    // DLOGF(@"%s", TK_FUNC_NAME);

    if (!peripheralManager) {
        // DLOGF(@"%s: peripheral is not available, update is skipped.", TK_FUNC_NAME);
        return;
    }
    DCHECK(peripheralManager && peripheralManager == _peripheralManager);
    DCHECK(hasBit(_statusBits, TKBluetoothCommunicatorStatusBitStartingAdvertising));
    DCHECK(!hasBit(_statusBits, TKBluetoothCommunicatorStatusBitAdvertising));

    NSUInteger statusBits = unsetBit(_statusBits, TKBluetoothCommunicatorStatusBitStartingAdvertising);

    if (error) {
        // DLOGF(@"%s: Caught error, description=%@", TK_FUNC_NAME, [error description]);
        // DLOGF(@"%s: Caught error, debugDescription=%@", TK_FUNC_NAME, [error debugDescription]);
        // DLOGF(@"%s: Caught error, code=%ld", TK_FUNC_NAME, (long)[error code]);

        [self setStatusBits:statusBits];
        return;
    }

    // DLOGF(@"%s: Started advertising.", TK_FUNC_NAME);

    statusBits = setBit(statusBits, TKBluetoothCommunicatorStatusBitAdvertising);
    [self setStatusBits:statusBits];
}

// CBPeripheralManagerDelegate
- (void)peripheralManager:(CBPeripheralManager *)peripheralManager
            didAddService:(CBService *)service
                    error:(NSError *)error {
    // DLOGF(@"%s", TK_FUNC_NAME);

    if (!peripheralManager) {
        // DLOGF(@"%s: peripheral is not available, update is skipped.", TK_FUNC_NAME);
        return;
    }
    if (!service) {
        // DLOGF(@"%s: service is not available, update is skipped.", TK_FUNC_NAME);
        return;
    }

    DCHECK(peripheralManager && peripheralManager == _peripheralManager);
    DCHECK(service && service.UUID == _peripheralService.UUID);
    DCHECK(hasBit(_statusBits, TKBluetoothCommunicatorStatusBitPublishingService));
    DCHECK(!hasBit(_statusBits, TKBluetoothCommunicatorStatusBitPublishedService));

    NSUInteger statusBits = unsetBit(_statusBits, TKBluetoothCommunicatorStatusBitPublishingService);

    if (error) {
        // DLOGF(@"%s: Caught error, description=%@", TK_FUNC_NAME, [error description]);
        // DLOGF(@"%s: Caught error, debugDescription=%@", TK_FUNC_NAME, [error debugDescription]);
        // DLOGF(@"%s: Caught error, code=%ld", TK_FUNC_NAME, (long)[error code]);

        [self setStatusBits:statusBits];
        return;
    }

    // DLOGF(@"%s, Service %@ is published.", TK_FUNC_NAME, service);

    statusBits = setBit(statusBits, TKBluetoothCommunicatorStatusBitPublishedService);
    [self setStatusBits:statusBits];
}

- (TKBluetoothCommunicatorDevice *)centralDidSubscribe:(CBCentral *)central
                                      toCharacteristic:(CBCharacteristic *)characteristic {
    TKBluetoothCommunicatorDevice *device = [_connectedDevices objectForKey:central];
    if (device) {
        assert(device.bluetoothCommunicator == self);
        assert(device.central == central);
        return device;
    }

    device = [[TKBluetoothCommunicatorDevice alloc] init];
    if (!device) { return nil; }

    [_connectedDevices setObject:device forKey:central];

    device.bluetoothCommunicator = self;
    device.central = central;
    device.mtu = [central maximumUpdateValueLength];
    device.localId = [_connectedDevices count];
    device.characteristic = characteristic;
    device.pendingWriteValue = false;

    [_peripheralManager setDesiredConnectionLatency:CBPeripheralManagerConnectionLatencyLow forCentral:central];
    [_delegate bluetoothCommunicator:self didConnectToDevice:device];
    return device;
}

- (void)centralDidUnsubscribe:(CBCentral *)central toCharacteristic:(CBCharacteristic *)characteristic {
    TKBluetoothCommunicatorDevice *device = [_connectedDevices objectForKey:central];
    [self cancelConnectionForDevice:device];
}

// CBPeripheralManagerDelegate
// https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/PerformingCommonPeripheralRoleTasks/PerformingCommonPeripheralRoleTasks.html#//apple_ref/doc/uid/TP40013257-CH4-SW1
// Android: bluetoothGattServerDidRequestRead
- (void)peripheralManager:(CBPeripheralManager *)peripheralManager didReceiveReadRequest:(CBATTRequest *)request {
    // DLOGF(@"%s", TK_FUNC_NAME);

    DCHECK(peripheralManager);
    if (!peripheralManager) {
        // DLOGF(@"%s: peripheral is not available, update is skipped.", TK_FUNC_NAME);
        return;
    }

    DCHECK(request);
    if (!request) {
        // DLOGF(@"%s: request is not available, update is skipped.", TK_FUNC_NAME);
        return;
    }

    if (![request.characteristic.UUID isEqual:[_characteristicUUIDs objectAtIndex:0]]) {
        // DLOGF(@"%s: requested characteristic is not available, update is skipped.", TK_FUNC_NAME);
        return;
    }

    if (request.offset != 0) {
        // DLOGF(@"%s: responding to request, invalid offset.", TK_FUNC_NAME);
        [_peripheralManager respondToRequest:request withResult:CBATTErrorInvalidOffset];
        return;
    }

    if (TKBluetoothCommunicatorDevice *device = [_connectedDevices objectForKey:request.central]) {
        // DLOGF(@"%s: device that requested read: name=%@, uuid=%@", TK_FUNC_NAME, device.deviceName,
        // device.deviceUUID);

        request.value = nil;
        // DLOGF(@"%s: responding to request, success.", TK_FUNC_NAME);
        [_peripheralManager respondToRequest:request withResult:CBATTErrorSuccess];
    } else {
        // DLOGF(@"%s: responding to request, read not permitted.", TK_FUNC_NAME);
        [_peripheralManager respondToRequest:request withResult:CBATTErrorReadNotPermitted];
        return;
    }
}

// CBPeripheralManagerDelegate
// https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/PerformingCommonPeripheralRoleTasks/PerformingCommonPeripheralRoleTasks.html#//apple_ref/doc/uid/TP40013257-CH4-SW1
// Android: bluetoothGattServerDidRequestWrite
- (void)peripheralManager:(CBPeripheralManager *)peripheral
    didReceiveWriteRequests:(NSArray<CBATTRequest *> *)requests {
    constexpr CBATTError BAD_RESPONSE = CBATTErrorWriteNotPermitted;
    constexpr CBATTError GOOD_RESPONSE = CBATTErrorSuccess;

    // DLOGF(@"%s: received %u write requests.", TK_FUNC_NAME, requests ? requests.count : 0);

    for (NSUInteger i = 0; i < requests.count; ++i) {
        CBATTRequest *request = [requests objectAtIndex:i];

        DCHECK(request);
        DCHECK(request.value);
        DCHECK(request.central);

        if (!request || !request.value || !request.central) {
            // DLOGF(@"%s: caught invalid request, responding with error.", TK_FUNC_NAME);
            [_peripheralManager respondToRequest:request withResult:BAD_RESPONSE];
            continue;
        }

        NSData *value = [NSData dataWithData:request.value];
        DCHECK(value);

        TKBluetoothCommunicatorDevice *device = [_connectedDevices objectForKey:request.central];
        DCHECK(device);

        if (!device) {
            // DLOGF(@"%s: failed to find connected device, responding with error.", TK_FUNC_NAME);
            [_peripheralManager respondToRequest:request withResult:BAD_RESPONSE];
            continue;
        }

        // DLOGF(@"%s: received a valid request, respoding with success.", TK_FUNC_NAME);
        [_peripheralManager respondToRequest:request withResult:GOOD_RESPONSE];

        if (![_scheduler scheduleMessageFrom:device wholeMessageData:value]) {
            [self cancelConnectionForDevice:device];
        }
    }
}

// CBPeripheralManagerDelegate
// TODO
// https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/PerformingCommonPeripheralRoleTasks/PerformingCommonPeripheralRoleTasks.html#//apple_ref/doc/uid/TP40013257-CH4-SW1
- (void)peripheralManager:(CBPeripheralManager *)peripheralManager
                         central:(CBCentral *)central
    didSubscribeToCharacteristic:(CBCharacteristic *)characteristic {
    // DLOGF(@"%s", TK_FUNC_NAME);

#ifdef TK_PERIPHERAL_ONE_SUBSCRIPTION
    if ([_connectedDevices count] > 0) {
        // DLOGF(@"%s: skipping subscription request, only subscription is allowed.", TK_FUNC_NAME);
        return;
    }
#endif

    DCHECK(peripheralManager && peripheralManager == _peripheralManager);
    DCHECK(characteristic && characteristic == _peripheralService.characteristics[0]);
    DCHECK(central);

    if (!peripheralManager) {
        // DLOGF(@"%s: peripheral is not available, update is skipped.", TK_FUNC_NAME);
        return;
    }
    if (!characteristic) {
        // DLOGF(@"%s: characteristic is not available, update is skipped.", TK_FUNC_NAME);
        return;
    }
    if (!central) {
        // DLOGF(@"%s: central is not available, update is skipped.", TK_FUNC_NAME);
        return;
    }

    TKBluetoothCommunicatorDevice *device = [self centralDidSubscribe:central toCharacteristic:characteristic];
    DCHECK(device);

#ifdef TK_PERIPHERAL_ONE_SUBSCRIPTION
    DCHECK([_connectedDevices count] == 1);
    [self stopAdvertising];
#endif
}

// CBPeripheralManagerDelegate
// Connection from the side of peripheral manager cannot be cancelled
// forcefully, but it can be timed out (30 seconds), the peripheral manager
// should not respond to requests.
// https://stackoverflow.com/questions/21537427/terminate-a-connection-cbperipheralmanager-side
// TODO
// https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/PerformingCommonPeripheralRoleTasks/PerformingCommonPeripheralRoleTasks.html#//apple_ref/doc/uid/TP40013257-CH4-SW1
- (void)peripheralManager:(CBPeripheralManager *)peripheralManager
                             central:(CBCentral *)central
    didUnsubscribeFromCharacteristic:(CBCharacteristic *)characteristic {
    // DLOGF(@"%s", TK_FUNC_NAME);
    DCHECK(peripheralManager && peripheralManager == _peripheralManager);
    DCHECK(characteristic && characteristic == _peripheralService.characteristics[0]);
    DCHECK(central);

    if (!peripheralManager) {
        // DLOGF(@"%s: peripheral is not available, update is skipped.", TK_FUNC_NAME);
        return;
    }
    if (!characteristic) {
        // DLOGF(@"%s: characteristic is not available, update is skipped.", TK_FUNC_NAME);
        return;
    }
    if (!central) {
        // DLOGF(@"%s: central is not available, update is skipped.", TK_FUNC_NAME);
        return;
    }

    [self centralDidUnsubscribe:central toCharacteristic:characteristic];

#ifdef TK_PERIPHERAL_ONE_SUBSCRIPTION
    assert([_connectedDevices count] == 0);
    [self startAdvertising];
#endif
}

//
// C e n t r a l
//

- (void)initCentralWithDelegate:(id<TKBluetoothCommunicatorDelegate>)delegate {
    // DLOGF(@"%s", TK_FUNC_NAME);
    if (hasBit(_statusBits,
               TKBluetoothCommunicatorStatusBitStartingCentral | TKBluetoothCommunicatorStatusBitCentral)) {
        DCHECKF(false, "Already running a central role.");
        return;
    }

    atomic_store(&_scanningFlag, false);
    [self prepareUUIDs];
    [self prepareName];

    _delegate = delegate;
    _statusBits = TKBluetoothCommunicatorStatusBitStartingCentral;
    _scheduler = [[TKBluetoothCommunicatorScheduler alloc] initWithBluetoothCommunicator:self];
    _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil options:nil];
}

- (void)cancelConnectionForDevice:(TKBluetoothCommunicatorDevice *)device {
    // DLOGF(@"%s", TK_FUNC_NAME);

    if ([device peripheral]) {
        [_connectedDevices removeObjectForKey:[device peripheral]];
        [_centralManager cancelPeripheralConnection:[device peripheral]];
        [_delegate bluetoothCommunicator:self didDisconnectDevice:device];
    } else if ([device central]) {
        [_connectedDevices removeObjectForKey:[device central]];
        [_delegate bluetoothCommunicator:self didDisconnectDevice:device];
    }
}

// CBPeripheralDelegate
- (void)peripheral:(CBPeripheral *)peripheral
    didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic
                              error:(NSError *)error {
    // DLOGF(@"%s", TK_FUNC_NAME);

    if (peripheral == nil) {
        // DLOGF(@"%s: peripheral is not available, update is skipped.", TK_FUNC_NAME);
        return;
    }

    // DLOGF(@"%s: peripheral=%@, UUID=%@, name=%@", TK_FUNC_NAME, peripheral, peripheral.identifier, peripheral.name);

    if (characteristic == nil) {
        // DLOGF(@"%s: characteristic is not available, update is skipped.", TK_FUNC_NAME);
        return;
    }

    // DLOGF(@"%s: characteristic=%@, UUID=%@", TK_FUNC_NAME, characteristic, characteristic.UUID);

    TKBluetoothCommunicatorDevice *device = [_connectedDevices objectForKey:peripheral];
    if (device == nil || ([device peripheral] != peripheral) || ([device characteristic] != characteristic)) {
        // DLOGF(@"%s: Caught unexpected peripheral.", TK_FUNC_NAME);
        return;
    }

    if (error) {
        // DLOGF(@"%s: Caught error, description=%@", TK_FUNC_NAME, [error description]);
        // DLOGF(@"%s: Caught error, debugDescription=%@", TK_FUNC_NAME, [error debugDescription]);
        // DLOGF(@"%s: Caught error, code=%ld", TK_FUNC_NAME, (long)[error code]);

        [_delegate bluetoothCommunicator:self didReceiveValue:nil orError:error fromDevice:device];
        return;
    }

    [_scheduler scheduleMessageFrom:device wholeMessageData:characteristic.value];
    [_delegate bluetoothCommunicator:self didReceiveValue:characteristic.value orError:nil fromDevice:device];
}

- (void)peripheral:(CBPeripheral *)peripheral
    didDiscoverCharacteristicsForService:(CBService *)service
                                   error:(NSError *)error {
    // DLOGF(@"%s", TK_FUNC_NAME);

    if (peripheral == nil) {
        NSLog(@"%s: peripheral is not available, peripheral is skipped.", TK_FUNC_NAME);
        return;
    }

    // DLOGF(@"%s: peripheral=%@, UUID=%@, name=%@", TK_FUNC_NAME, peripheral, peripheral.identifier, peripheral.name);

    TKBluetoothCommunicatorDevice *device = [_connectedDevices objectForKey:peripheral];
    if (device == nil || ([device peripheral] != peripheral) || ([device service] != service)) {
        // DLOGF(@"%s: Caught unexpected peripheral.", TK_FUNC_NAME);
        return;
    }

    if (error) {
        // DLOGF(@"%s: Caught error, description=%@", TK_FUNC_NAME, [error description]);
        // DLOGF(@"%s: Caught error, debugDescription=%@", TK_FUNC_NAME, [error debugDescription]);
        // DLOGF(@"%s: Caught error, code=%ld", TK_FUNC_NAME, (long)[error code]);

        [self cancelConnectionForDevice:device];
        [self startDiscoveringDevices];
        return;
    }

    if (service.characteristics == nil || service.characteristics.count < 1) {
        // DLOGF(@"%s: No discovered characteristics", TK_FUNC_NAME);

        [self cancelConnectionForDevice:device];
        [self startDiscoveringDevices];
        return;
    }

    NSLog(@"%s: Discovered characteristic count=%lu", TK_FUNC_NAME, (unsigned long)service.characteristics.count);
    for (CBCharacteristic *c in service.characteristics) {
        DLOGF(@"%s: Discovered characteristic, UUID=%@", TK_FUNC_NAME, [c UUID]);
        DLOGF(@"%s: Discovered characteristic, description=%@", TK_FUNC_NAME, [c description]);
        DLOGF(@"%s: Discovered characteristic, debugDescription=%@", TK_FUNC_NAME, [c debugDescription]);
    }

    DCHECK([_characteristicUUIDs count] == 1);
    for (CBCharacteristic *c in service.characteristics) {
        if ([[c UUID] isEqual:[_characteristicUUIDs objectAtIndex:0]]) {
            // DLOGF(@"%s: Found desired characteristic, UUID=%@", TK_FUNC_NAME, [c UUID]);
            // DLOGF(@"%s: Subscribing to the characteristic.", TK_FUNC_NAME);

            if (c.properties & CBCharacteristicPropertyNotify) {
                [device setCharacteristic:c];
                [peripheral setNotifyValue:YES forCharacteristic:c];
                [_delegate bluetoothCommunicator:self didSubscribeToDevice:device];
            } else {
                // DLOGF(@"%s: Characteristic does not contain notify property.", TK_FUNC_NAME);
                [self cancelConnectionForDevice:device];
                [self startDiscoveringDevices];
            }

            break;
        }
    }
}

// https://developer.apple.com/documentation/corebluetooth/cbperipheraldelegate/1518865-peripheral?language=objc
- (void)peripheral:(CBPeripheral *)peripheral didModifyServices:(NSArray<CBService *> *)invalidatedServices {
    // DLOGF(@"%s", TK_FUNC_NAME);

    if (peripheral == nil) {
        // DLOGF(@"%s: peripheral is not available, peripheral is skipped.", TK_FUNC_NAME);
        return;
    }

    TKBluetoothCommunicatorDevice *device = [_connectedDevices objectForKey:peripheral];
    if (device == nil || ([device peripheral] != peripheral)) {
        // DLOGF(@"%s: Caught unexpected peripheral.", TK_FUNC_NAME);
        return;
    }

    if (invalidatedServices == nil) {
        // DLOGF(@"%s: Caught null invalidated services.", TK_FUNC_NAME);
        [self cancelConnectionForDevice:device];
    } else if (device.service && [invalidatedServices containsObject:device.service]) {
        // DLOGF(@"%s: Invalidated services collecton contains connected service, cancelling peripheral connection.",
        // TK_FUNC_NAME);
        [self cancelConnectionForDevice:device];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    // DLOGF(@"%s", TK_FUNC_NAME);

    if (peripheral == nil) {
        // DLOGF(@"%s: peripheral is not available, peripheral is skipped.", TK_FUNC_NAME);
        return;
    }

    // DLOGF(@"%s: peripheral=%@, UUID=%@, name=%@", TK_FUNC_NAME, peripheral, peripheral.identifier, peripheral.name);

    TKBluetoothCommunicatorDevice *device = [_connectedDevices objectForKey:peripheral];
    if (device == nil || ([device peripheral] != peripheral)) {
        // DLOGF(@"%s: Caught unexpected peripheral.", TK_FUNC_NAME);
        return;
    }

    if (error) {
        // DLOGF(@"%s: Caught error, code=%ld", TK_FUNC_NAME, (long)[error code]);
        // DLOGF(@"%s: Caught error, description=%@", TK_FUNC_NAME, [error description]);
        // DLOGF(@"%s: Caught error, debugDescription=%@", TK_FUNC_NAME, [error debugDescription]);

        [self cancelConnectionForDevice:device];
        [self startDiscoveringDevices];
        return;
    }

    if (peripheral.services == nil || peripheral.services.count < 1) {
        // DLOGF(@"%s: No discovered services", TK_FUNC_NAME);

        [self cancelConnectionForDevice:device];
        [self startDiscoveringDevices];
        return;
    }

    // DLOGF(@"%s: Discovered service count=%lu", TK_FUNC_NAME, (unsigned long)peripheral.services.count);
    for (CBService *discoveredService in peripheral.services) {
        // DLOGF(@"%s: Discovered service, UUID=%@", TK_FUNC_NAME, [discoveredService UUID]);
        // DLOGF(@"%s: Discovered service, description=%@", TK_FUNC_NAME, [discoveredService description]);
        // DLOGF(@"%s: Discovered service, debugDescription=%@", TK_FUNC_NAME, [discoveredService debugDescription]);
    }

    DCHECK([_serviceUUIDs count] == 1);
    for (CBService *discoveredService in peripheral.services) {
        if ([[discoveredService UUID] isEqual:[_serviceUUIDs objectAtIndex:0]]) {
            // DLOGF(@"%s: Found desired service, UUID=%@", TK_FUNC_NAME, [discoveredService UUID]);
            // DLOGF(@"%s: Discovering service characteristics.", TK_FUNC_NAME);

            [device setService:discoveredService];
            [peripheral discoverCharacteristics:_characteristicUUIDs forService:discoveredService];
            break;
        }
    }
}

- (void)centralManager:(CBCentralManager *)central
    didDisconnectPeripheral:(CBPeripheral *)peripheral
                      error:(nullable NSError *)error {
    // DLOGF(@"%s", TK_FUNC_NAME);

    if (central == nil) {
        // DLOGF(@"%s: central is not available, peripheral is skipped.", TK_FUNC_NAME);
        return;
    }

    if (peripheral == nil) {
        // DLOGF(@"%s: peripheral is not available, peripheral is skipped.", TK_FUNC_NAME);
        return;
    }

    // DLOGF( @"%s: central=%@", TK_FUNC_NAME, central );
    // DLOGF( @"%s: _centralManager=%@", TK_FUNC_NAME, _centralManager );
    // DLOGF(@"%s: peripheral=%@, UUID=%@, name=%@", TK_FUNC_NAME, peripheral, peripheral.identifier, peripheral.name);

    TKBluetoothCommunicatorDevice *device = [_connectedDevices objectForKey:peripheral];
    if (device == nil) {
        // DLOGF(@"%s: Device was not connected, panic.", TK_FUNC_NAME);
        return;
    }

    [_connectedDevices removeObjectForKey:peripheral];
    [_delegate bluetoothCommunicator:self didDisconnectDevice:device];

    NSUInteger statusBits = unsetBit(_statusBits, TKBluetoothCommunicatorStatusBitConnected);
    [self setStatusBits:statusBits];
    [self startDiscoveringDevices];
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    // DLOGF(@"%s", TK_FUNC_NAME);
    [self stopDiscoveringDevices];

    if (central == nil) {
        // DLOGF(@"%s: central is not available, peripheral is skipped.", TK_FUNC_NAME);
        return;
    }

    if (peripheral == nil) {
        // DLOGF(@"%s: peripheral is not available, peripheral is skipped.", TK_FUNC_NAME);
        return;
    }

    // DLOGF( @"%s: central=%@", TK_FUNC_NAME, central );
    // DLOGF( @"%s: _centralManager=%@", TK_FUNC_NAME, _centralManager );
    // DLOGF( @"%s: peripheral=%@, UUID=%@, name=%@", TK_FUNC_NAME, peripheral,
    // peripheral.identifier, peripheral.name );

    NSUInteger withResponse = [peripheral maximumWriteValueLengthForType:CBCharacteristicWriteWithResponse];
    NSUInteger withoutResponse = [peripheral maximumWriteValueLengthForType:CBCharacteristicWriteWithoutResponse];

    DLOGF(@"%s: maximumWriteValueLength:WithResponse    %u", TK_FUNC_NAME, withResponse);
    DLOGF(@"%s: maximumWriteValueLength:WithoutResponse %u", TK_FUNC_NAME, withoutResponse);

    TKBluetoothCommunicatorDevice *device = [[TKBluetoothCommunicatorDevice alloc] init];
    [device setBluetoothCommunicator:self];
    [device setMtu:withResponse];

    [device setPeripheral:peripheral];
    [device setLocalId:[_connectedDevices count]];
    [device setPendingWriteValue:false];

    [_connectedDevices setObject:device forKey:peripheral];
    // [_connectingDevices removeObject:peripheral];
    [_delegate bluetoothCommunicator:self didConnectToDevice:device];

    //_currentStatusBits = unsetBit(_currentStatusBits,
    // TKBluetoothCommunicatorStatusBitConnecting); _currentStatusBits =
    // setBit(_currentStatusBits, TKBluetoothCommunicatorStatusBitConnected);
    // [_delegate bluetoothCommunicatorDidChangeState:self];

    //
    // Comment from sample:
    //
    // By specifying the actual services we want to connect to, this will
    // work for iOS apps that are in the background.
    //
    // If you specify nil in the list of services and the application is in the
    // background, it may sometimes only discover the Generic Access Profile
    // and the Generic Attribute Profile services.

    [peripheral setDelegate:self];
    [peripheral discoverServices:_serviceUUIDs];
    // [peripheral discoverServices:nil];

    // TODO: Either user should stop scanning, or set a timeout for connection.
    // [self stopDiscoveringDevices];

    NSUInteger statusBits = unsetBit(_statusBits, TKBluetoothCommunicatorStatusBitConnecting);
    statusBits = unsetBit(statusBits, TKBluetoothCommunicatorStatusBitScanning);
    statusBits = setBit(statusBits, TKBluetoothCommunicatorStatusBitConnected);
    [self setStatusBits:statusBits];
}

- (void)centralManager:(CBCentralManager *)central
    didFailToConnectPeripheral:(CBPeripheral *)peripheral
                         error:(NSError *)error {
    // // DLOGF(@"%s", TK_FUNC_NAME);
    // // DLOGF(@"%s: central=%@", TK_FUNC_NAME, central);
    // DLOGF( @"%s: _centralManager=%@", TK_FUNC_NAME, _centralManager );
    // DLOGF(@"%s: peripheral=%@, UUID=%@, name=%@", TK_FUNC_NAME, peripheral, peripheral.identifier, peripheral.name);
    // DLOGF(@"%s: error=%@", TK_FUNC_NAME, error);
}

- (void)centralManager:(CBCentralManager *)central
    didDiscoverPeripheral:(CBPeripheral *)peripheral
        advertisementData:(NSDictionary *)advertisementData
                     RSSI:(NSNumber *)rssi {
    // // DLOGF(@"%s", TK_FUNC_NAME);
    // // DLOGF(@"%s: central=%@", TK_FUNC_NAME, central);
    // DLOGF( @"%s: _centralManager=%@", TK_FUNC_NAME, _centralManager );

    // if (peripheral.name && peripheral.name.length > 0){
    //     // DLOGF(@"%s: name=%@, UUID=%@, peripheral=%@", TK_FUNC_NAME, peripheral.name, peripheral.identifier,
    //     peripheral);
    // }

    // DLOGF( @"%s: advertisementData=%@", TK_FUNC_NAME, advertisementData );
    // DLOGF( @"%s: rssi=%@", TK_FUNC_NAME, rssi );

    if (advertisementData == nil || [advertisementData count] == 0) {
        // // DLOGF(@"%s: Advertisement data is either nil or empty, peripheral is "
        //       @"skipped.",
        //       TK_FUNC_NAME);
        return;
    }

    NSArray *advertisedServiceUUIDs = [advertisementData objectForKey:CBAdvertisementDataServiceUUIDsKey];
    if (advertisedServiceUUIDs == nil || [advertisedServiceUUIDs count] == 0) {
        // // DLOGF(@"%s: No advertised services, peripheral is skipped.", TK_FUNC_NAME);
        return;
    }

    NSString *peripheralLocalName = [advertisementData objectForKey:CBAdvertisementDataLocalNameKey];
    if (peripheralLocalName != nil) {
        // // DLOGF(@"%s: Found peripheral name key, name=%@.", TK_FUNC_NAME, peripheralLocalName);
    }

    for (CBUUID *advertisedServiceUUID in advertisedServiceUUIDs) {
        if ([_serviceUUIDs containsObject:advertisedServiceUUID]) {
            // // DLOGF(@"%s: Found matching service, UUID=%@.", TK_FUNC_NAME, advertisedServiceUUID);

            if ([_connectingDevices containsObject:peripheral]) {
                // // DLOGF(@"%s: Already connecting to this peripheral.", TK_FUNC_NAME);
                continue;
            }
            if ([_connectedDevices objectForKey:peripheral] != nil) {
                // // DLOGF(@"%s: Already connected to this peripheral.", TK_FUNC_NAME);
                continue;
            }
            if (!atomic_load(&_scanningFlag)) {
                // // DLOGF(@"%s: Scanning has been stopped.", TK_FUNC_NAME);
                break;
            }

            // DLOGF(@"%s: Connecting to the peripheral.", TK_FUNC_NAME);

            const bool notEmpty = [_connectedDevices count] > 0 || [_connectingDevices count] > 0;
            (void)notEmpty;

            [_connectingDevices addObject:peripheral];
            [_centralManager connectPeripheral:peripheral options:nil];

            NSUInteger statusBits = setBit(_statusBits, TKBluetoothCommunicatorStatusBitConnecting);
            [self setStatusBits:statusBits];
            break;
        }
    }
}

- (NSArray *)connectedDevices {
    // DLOGF(@"%s", TK_FUNC_NAME);
    return [_connectedDevices allValues];
}

- (void)bluetoothCommunicatorDeviceDidUpdateProperty:(TKBluetoothCommunicatorDevice *)device {
    [_delegate bluetoothCommunicator:self didUpdateDevice:device];
}

- (TKBluetoothCommunicatorWriteValueResult)writeValue:(NSData *)value toDevice:(TKBluetoothCommunicatorDevice *)device {
    // DLOGF(@"%s", TK_FUNC_NAME);

    if (!value || !device) {
        // DLOGF(@"%s: value or device are nulls, write is skipped.", TK_FUNC_NAME);
        return TKBluetoothCommunicatorWriteValueResultErrorPanic;
    }
    if ([device pendingWriteValue]) {
        // DLOGF(@"%s: Cannot write with pending response, write is skipped.", TK_FUNC_NAME);
        return TKBluetoothCommunicatorWriteValueResultFailedReschedule;
    }

    CBPeripheral *peripheral = [device peripheral];
    if (peripheral) {
        CBCharacteristic *characteristic = [device characteristic];
        if (!peripheral || !characteristic) {
            // DLOGF(@"%s: peripheral or characteristic are nulls, write is skipped.", TK_FUNC_NAME);
            return TKBluetoothCommunicatorWriteValueResultErrorPanic;
        }

        [peripheral writeValue:value forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
        return TKBluetoothCommunicatorWriteValueResultSuccessContinue;
    }

    CBCentral *central = [device central];
    if (central) {
        if (!central || [device.characteristic UUID] != [_peripheralCharacteristic UUID]) {
            return TKBluetoothCommunicatorWriteValueResultErrorPanic;
        }

        // https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/PerformingCommonPeripheralRoleTasks/PerformingCommonPeripheralRoleTasks.html
        if ([_peripheralManager updateValue:value
                          forCharacteristic:_peripheralCharacteristic
                       onSubscribedCentrals:@[ central ]]) {
            // DLOGF(@"%s: peripheral manager updated value for characterisic.", TK_FUNC_NAME);
            return TKBluetoothCommunicatorWriteValueResultSuccessContinue;
        }

        // DLOGF(@"%s: peripheral manager failed to update value for characterisic.", TK_FUNC_NAME);
        // peripheralManagerIsReadyToUpdateSubscribers
        return TKBluetoothCommunicatorWriteValueResultFailedReschedule;
    }

    // DLOGF(@"%s: writing value failed, panic.", TK_FUNC_NAME);
    return TKBluetoothCommunicatorWriteValueResultErrorPanic;
}

- (void)peripheral:(CBPeripheral *)peripheral
    didWriteValueForCharacteristic:(CBCharacteristic *)characteristic
                             error:(nullable NSError *)error {
    // DLOGF(@"%s", TK_FUNC_NAME);

    TKBluetoothCommunicatorDevice *device = [_connectedDevices objectForKey:peripheral];
    if (device == nil || ([device peripheral] != peripheral) || ([device characteristic] != characteristic)) {
        // DLOGF(@"%s: Caught unexpected peripheral.", TK_FUNC_NAME);
        return;
    }

    // [device setPendingWriteValue:false];

    if (error) {
        // DLOGF(@"%s: Caught error, description=%@", TK_FUNC_NAME, [error description]);
        // DLOGF(@"%s: Caught error, debugDescription=%@", TK_FUNC_NAME, [error debugDescription]);
        // DLOGF(@"%s: Caught error, code=%ld", TK_FUNC_NAME, (long)[error code]);

        [_delegate bluetoothCommunicator:self didWriteValueOrError:error toDevice:device];
    } else {
        [_delegate bluetoothCommunicator:self didWriteValueOrError:nil toDevice:device];
    }
}

- (void)setStatusBits:(NSUInteger)statusBits {
    if (_statusBits != statusBits) {
        tk::swap(_statusBits, statusBits);
        [_delegate bluetoothCommunicator:self
                     didChangeStatusFrom:TKBluetoothCommunicatorStatusBits(statusBits)
                                      to:TKBluetoothCommunicatorStatusBits(_statusBits)];
    }
}

- (void)stopDiscoveringDevices {
    // DLOGF(@"%s", TK_FUNC_NAME);

    if (!atomic_exchange(&_scanningFlag, false)) {
        // DLOGF(@"%s: Scanning has being stopped.", TK_FUNC_NAME);
        return;
    }

    // DLOGF(@"%s: Stopping scanning.", TK_FUNC_NAME);

    [_connectingDevices removeAllObjects];
    [_centralManager stopScan];

    [self setStatusBits:unsetBit(_statusBits, TKBluetoothCommunicatorStatusBitScanning)];
}

- (void)startDiscoveringDevices {
    // DLOGF(@"%s", TK_FUNC_NAME);

    //
    // Comment from sample:
    //
    // By turning on allow duplicates, it allows us to scan more reliably, but
    // if it finds a peripheral that does not have the services we like or
    // recognize, we'll continually see it again and again in the didDiscover
    // callback.

    //
    // Comment from sample:
    //
    // We could pass in the set of serviceUUIDs when scanning like Apple
    // recommends, but if the application we're scanning for is in the
    // background on the iOS device, then it occassionally will not see any
    // services.
    //
    // So instead, we do the opposite of what Apple recommends and scan
    // with no service UUID restrictions.

    if (atomic_exchange(&_scanningFlag, true)) {
        // DLOGF(@"%s: Scanning has being started.", TK_FUNC_NAME);
        return;
    }

    NSDictionary *scanningOptions = @{CBCentralManagerScanOptionAllowDuplicatesKey : @YES};

    if (_connectedDevices == nil) {
        _connectedDevices = [[NSMutableDictionary alloc] init];
        _connectingDevices = [[NSMutableSet alloc] init];
        // DLOGF(@"%s: Created peripheral list.", TK_FUNC_NAME);
    } else {
        // DLOGF(@"%s: Clearing peripheral list.", TK_FUNC_NAME);
        [_connectedDevices removeAllObjects];
        [_connectingDevices removeAllObjects];
    }

    // DLOGF(@"%s: Starting discovering peripherals.", TK_FUNC_NAME);

    NSArray *serviceUUIDs = nil; // _serviceUUIDs

    atomic_store(&_scanningFlag, true);
    [_centralManager scanForPeripheralsWithServices:serviceUUIDs options:scanningOptions];

    [self setStatusBits:setBit(_statusBits, TKBluetoothCommunicatorStatusBitScanning)];
}

- (void)peripheralManagerDidUpdateState:(nonnull CBPeripheralManager *)peripheral {
    DCHECK(peripheral);
    switch (peripheral.state) {
        case CBManagerStatePoweredOn: {
            DCHECK(_peripheralManager == peripheral);
            // DLOGF(@"%s: Caught CBManagerStatePoweredOn.", TK_FUNC_NAME);
            NSUInteger statusBits = unsetBit(_statusBits, TKBluetoothCommunicatorStatusBitWaitingForUserInput);
            statusBits = unsetBit(statusBits, TKBluetoothCommunicatorStatusBitWaitingForSystem);
            statusBits = unsetBit(statusBits, TKBluetoothCommunicatorStatusBitStartingPeripheral);
            statusBits = setBit(statusBits, TKBluetoothCommunicatorStatusBitPeripheral);
            [self setStatusBits:statusBits];
        } break;

        case CBManagerStateUnknown:
            // DLOGF(@"%s: Caught CBManagerStateUnknown. Waiting for an update.", TK_FUNC_NAME);
            [self setStatusBits:setBit(_statusBits, TKBluetoothCommunicatorStatusBitWaitingForSystem)];
            break;
        case CBManagerStateResetting:
            // DLOGF(@"%s: Caught CBManagerStateResetting. Waiting for an update.", TK_FUNC_NAME);
            [self setStatusBits:setBit(_statusBits, TKBluetoothCommunicatorStatusBitWaitingForSystem)];
            break;

        case CBManagerStatePoweredOff: {
            // DLOGF(@"%s: Caught CBManagerStatePoweredOff state.", TK_FUNC_NAME);
            NSUInteger statusBits = unsetBit(_statusBits, TKBluetoothCommunicatorStatusBitStartingPeripheral);
            statusBits = setBit(statusBits, TKBluetoothCommunicatorStatusBitWaitingForUserInput);
            [self setStatusBits:statusBits];
        } break;
        case CBManagerStateUnauthorized:
            // DLOGF(@"%s: Caught CBManagerStateUnauthorized state.", TK_FUNC_NAME);
            [self setStatusBits:setBit(_statusBits, TKBluetoothCommunicatorStatusBitWaitingForUserInput)];
            break;

        case CBManagerStateUnsupported:
            // DLOGF(@"%s: Caught CBManagerStateUnsupported state.", TK_FUNC_NAME);
            [self setStatusBits:TKBluetoothCommunicatorStatusBitUnsupported];
            break;

        default:
            // DLOGF(@"%s: Error, unexpected state %li.", TK_FUNC_NAME, (long)peripheral.state);
            [self setStatusBits:TKBluetoothCommunicatorStatusBitPanic];
            break;
    }
}

- (void)centralManagerDidUpdateState:(nonnull CBCentralManager *)central {
    DCHECK(central);
    switch (central.state) {
        case CBManagerStatePoweredOn: {
            DCHECK(_centralManager == central);
            // DLOGF(@"%s: Caught CBManagerStatePoweredOn.", TK_FUNC_NAME);
            NSUInteger statusBits = unsetBit(_statusBits, TKBluetoothCommunicatorStatusBitWaitingForUserInput);
            statusBits = unsetBit(statusBits, TKBluetoothCommunicatorStatusBitWaitingForSystem);
            statusBits = unsetBit(statusBits, TKBluetoothCommunicatorStatusBitStartingCentral);
            statusBits = setBit(statusBits, TKBluetoothCommunicatorStatusBitCentral);
            [self setStatusBits:statusBits];
        } break;

        case CBManagerStateUnknown:
            // DLOGF(@"%s: Caught CBManagerStateUnknown. Waiting for an update.", TK_FUNC_NAME);
            [self setStatusBits:setBit(_statusBits, TKBluetoothCommunicatorStatusBitWaitingForSystem)];
            break;
        case CBManagerStateResetting:
            // DLOGF(@"%s: Caught CBManagerStateResetting. Waiting for an update.", TK_FUNC_NAME);
            [self setStatusBits:setBit(_statusBits, TKBluetoothCommunicatorStatusBitWaitingForSystem)];
            break;

        case CBManagerStatePoweredOff: {
            // DLOGF(@"%s: Caught CBManagerStatePoweredOff state.", TK_FUNC_NAME);
            NSUInteger statusBits = unsetBit(_statusBits, TKBluetoothCommunicatorStatusBitStartingCentral);
            statusBits = setBit(statusBits, TKBluetoothCommunicatorStatusBitWaitingForUserInput);
            [self setStatusBits:statusBits];
        } break;
        case CBManagerStateUnauthorized:
            // DLOGF(@"%s: Caught CBManagerStateUnauthorized state.", TK_FUNC_NAME);
            [self setStatusBits:setBit(_statusBits, TKBluetoothCommunicatorStatusBitWaitingForUserInput)];
            break;

        case CBManagerStateUnsupported:
            // DLOGF(@"%s: Caught CBManagerStateUnsupported state.", TK_FUNC_NAME);
            [self setStatusBits:TKBluetoothCommunicatorStatusBitUnsupported];
            break;

        default:
            // DLOGF(@"%s: Error, unexpected state %li.", TK_FUNC_NAME, (long)central.state);
            [self setStatusBits:TKBluetoothCommunicatorStatusBitPanic];
            break;
    }
}

- (void)debugObject:(NSObject *)debugObject didLog:(NSString *)log {
    assert(debugObject == self && "Instances should match.");
    [_delegate bluetoothCommunicator:self didLog:log];
}

@end

@implementation TKBluetoothCommunicatorLongMessage {
    NSUInteger _responseMessageType;
    NSUInteger _messageType;
    NSUInteger _messageContentsLength;
    NSMutableData *_messageContents;
    NSUInteger _messageContentsOffset;
    std::chrono::high_resolution_clock::time_point _initTimePoint;
    std::chrono::high_resolution_clock::time_point _lastTimePoint;
}

- (NSUInteger)getMessageType {
    return _messageType;
}
- (NSUInteger)getResponseMessageType {
    return _responseMessageType;
}
- (NSUInteger)getMessageContentsOffset {
    return _messageContentsOffset;
}
- (NSUInteger)getMessageContentsLength {
    return _messageContentsLength;
}

- (NSData *)getMessageContents {
    return _messageContents;
}

- (instancetype)initWithMessageData:(NSData *)messageData {
    [self start:messageData];
    return self;
}
- (void)start:(NSData *)wholeMessageData {
    DCHECK([self isEmpty]);
    _initTimePoint = std::chrono::high_resolution_clock::now();
    _responseMessageType = [TKBluetoothCommunicatorMessage getResponseMessageType:wholeMessageData];
    _messageType = [TKBluetoothCommunicatorMessage getMessageType:wholeMessageData];
    _messageContentsLength = [TKBluetoothCommunicatorMessage getMessageContentsByteLength:wholeMessageData];
    _messageContents = [[NSMutableData alloc] initWithCapacity:_messageContentsLength];
    _messageContentsOffset = 0;

    const NSUInteger contentsLength = wholeMessageData.length - TKBluetoothCommunicatorLongMessageStartByteIndex;
    if (contentsLength) {
        const uint8_t *contentsPtr =
            (const uint8_t *)[wholeMessageData bytes] + TKBluetoothCommunicatorLongMessageStartByteIndex;
        [_messageContents appendBytes:contentsPtr length:contentsLength];
        _messageContentsOffset += contentsLength;
    }
}
- (bool)canAppend:(NSUInteger)byteArrayLength {
    const NSUInteger unfilledByteCount = _messageContentsLength - _messageContentsOffset;
    return unfilledByteCount >= byteArrayLength;
}
- (bool)isComplete {
    return _messageContentsLength == _messageContentsOffset;
}
- (bool)append:(NSData *)wholeMessageData {
    DCHECK([self canAppend:wholeMessageData.length]);
    _lastTimePoint = std::chrono::high_resolution_clock::now();
    [_messageContents appendData:wholeMessageData];
    _messageContentsOffset += wholeMessageData.length;
    return [self isComplete];
}
- (double)bytesPerSecond {
    std::chrono::duration<double> duration =
    std::chrono::duration_cast<std::chrono::duration<double>>(_lastTimePoint - _initTimePoint);
    return double(_messageContentsOffset) / duration.count();
}
- (double)secondsETA {
    double bps = [self bytesPerSecond];
    double bytesLeft = _messageContentsLength - _messageContentsOffset;
    return bytesLeft / bps;
}

- (bool)isEmpty {
    DCHECK(_messageContents != nil || _responseMessageType == 0);
    DCHECK(_messageContents != nil || _messageType == 0);
    DCHECK(_messageContents != nil || _messageContentsLength == 0);
    DCHECK(_messageContents != nil || _messageContentsOffset == 0);
    return _messageContents == nil;
}
- (void)clear {
    _responseMessageType = 0;
    _messageType = 0;
    _messageContentsLength = 0;
    _messageContents = nil;
    _messageContentsOffset = 0;
}
@end

@implementation TKBluetoothCommunicatorMessage
+ (NSUInteger)getMessageType:(NSData *)wholeMessageBytes {
    const uint8_t decoratedMessageType =
        ((const uint8_t *)[wholeMessageBytes bytes])[TKBluetoothCommunicatorMessageTypeByteIndex];
    return (NSUInteger)decoratedMessageType;
}
+ (NSUInteger)getResponseMessageType:(NSData *)wholeMessageBytes {
    const uint8_t decoratedMessageType =
        ((const uint8_t *)[wholeMessageBytes bytes])[TKBluetoothCommunicatorResponseMessageTypeByteIndex];
    return (NSUInteger)decoratedMessageType;
}
+ (bool)isShortMessage:(NSUInteger)decoratedMessageType {
    return hasBit(decoratedMessageType, TKBluetoothCommunicatorMessageShortBit);
}
+ (bool)isEncryptedMessage:(NSUInteger)decoratedMessageType {
    return hasBit(decoratedMessageType, TKBluetoothCommunicatorMessageEncryptedBit);
}
+ (NSUInteger)undecorateMessageType:(NSUInteger)decoratedMessageType {
    decoratedMessageType = unsetBit(decoratedMessageType, TKBluetoothCommunicatorMessageShortBit);
    decoratedMessageType = unsetBit(decoratedMessageType, TKBluetoothCommunicatorMessageEncryptedBit);
    return decoratedMessageType;
}
+ (NSUInteger)shortMessageType:(NSUInteger)decoratedMessageType {
    decoratedMessageType = setBit(decoratedMessageType, TKBluetoothCommunicatorMessageShortBit);
    return decoratedMessageType;
}
+ (NSUInteger)longMessageType:(NSUInteger)decoratedMessageType {
    decoratedMessageType = unsetBit(decoratedMessageType, TKBluetoothCommunicatorMessageShortBit);
    return decoratedMessageType;
}
+ (NSUInteger)getMessageContentsByteLength:(NSData *)wholeMessageData {
    DCHECK(wholeMessageData != nil && [wholeMessageData length] > TKBluetoothCommunicatorMessageLength3ByteIndex);
    NSRange lengthRange = NSMakeRange(TKBluetoothCommunicatorMessageLength0ByteIndex,
                                      TKBluetoothCommunicatorMessageLengthIntegerByteLength);
    TKSubdata *lengthSubdata = [[TKSubdata alloc] initWithData:wholeMessageData range:lengthRange];
    return [self bytesToInt:lengthSubdata];
    // return [self bytesToInt:[NSDataNoCopyUtilities
    // subdataNoCopy:wholeMessageData range:lengthRange]];
}

//
// NSUInteger
//

+ (void)intToBytes:(NSUInteger)integer writeTo:(NSMutableData *)mutableSubdata {
    DCHECK(integer <= 4294967295);
    DCHECK(mutableSubdata != nil);
    DCHECK([mutableSubdata length] >= TKBluetoothCommunicatorMessageLengthIntegerByteLength);

    uint8_t *ptr = (uint8_t *)[mutableSubdata bytes];
    ptr[0] = (uint8_t)(integer & 0xff);
    ptr[1] = (uint8_t)((integer >> 8) & 0xff);
    ptr[2] = (uint8_t)((integer >> 16) & 0xff);
    ptr[3] = (uint8_t)((integer >> 24) & 0xff);
}
+ (NSData *)intToBytes:(NSUInteger)integer {
    NSMutableData *intBytes =
        [[NSMutableData alloc] initWithLength:TKBluetoothCommunicatorMessageLengthIntegerByteLength];
    TKMutableSubdata *subdata = [[TKMutableSubdata alloc] initWithMutableData:intBytes];
    [self intToBytes:integer writeTo:subdata];
    return intBytes;
}
+ (NSUInteger)bytesToInt:(TKSubdata *)subdata {
    DCHECK(subdata != nil && [subdata length] >= TKBluetoothCommunicatorMessageLengthIntegerByteLength);

    const uint8_t *rawPtr = [subdata bytes];
    NSUInteger integer = (NSUInteger)rawPtr[0];
    integer |= ((NSUInteger)(rawPtr[1])) << 8;
    integer |= ((NSUInteger)(rawPtr[2])) << 16;
    integer |= ((NSUInteger)(rawPtr[3])) << 24;
    return integer;
}

//
// NSUUID
//

+ (NSData *)uuidToBytes:(NSUUID *)UUID {
    NSMutableData *uuidBytes = [[NSMutableData alloc] initWithLength:TKBluetoothCommunicatorUUIDByteLength];
    TKMutableSubdata *uuidSubdata = [[TKMutableSubdata alloc] initWithMutableData:uuidBytes];
    [self uuidToBytes:UUID writeTo:uuidSubdata];
    return uuidBytes;
}

+ (void)uuidToBytes:(NSUUID *)UUID writeTo:(NSMutableData *)mutableSubdata {
    return [UUID getUUIDBytes:(uint8_t *)[mutableSubdata bytes]];
}

+ (NSUUID *)bytesToUUID:(NSData *)subdata {
    const uint8_t *rawPtr = (const uint8_t *)[subdata bytes];
    return [[NSUUID alloc] initWithUUIDBytes:rawPtr];
}

+ (bool)requiresResponse:(NSData *)wholeMessageData {
    const uint8_t *rawPtr = (const uint8_t *)[wholeMessageData bytes];
    NSUInteger responseMessageType = rawPtr[TKBluetoothCommunicatorResponseMessageTypeByteIndex];
    return responseMessageType != TKBluetoothCommunicatorMessageTypeFinish;
}
@end

@implementation TKStringUtilities (TKBluetoothCommunicatorStatusBits)
+ (NSString *)communicatorBitsToString:(TKBluetoothCommunicatorStatusBits)bits {
    NSMutableString *mutableString = [[NSMutableString alloc] initWithCapacity:128];

    // clang-format off
    if (bits == TKBluetoothCommunicatorStatusBitInitial)                 { [mutableString appendString:@"Initial|"]; }
    if (bits &  TKBluetoothCommunicatorStatusBitStartingCentral)         { [mutableString appendString:@"StartingCentral|"]; }
    if (bits &  TKBluetoothCommunicatorStatusBitCentral)                 { [mutableString appendString:@"Central|"]; }
    if (bits &  TKBluetoothCommunicatorStatusBitScanning)                { [mutableString appendString:@"Scanning|"]; }
    if (bits &  TKBluetoothCommunicatorStatusBitReceiving)               { [mutableString appendString:@"Receiving|"]; }
    if (bits &  TKBluetoothCommunicatorStatusBitStartingPeripheral)      { [mutableString appendString:@"StartingPeripheral|"]; }
    if (bits &  TKBluetoothCommunicatorStatusBitPeripheral)              { [mutableString appendString:@"Peripheral|"]; }
    if (bits &  TKBluetoothCommunicatorStatusBitAdvertising)             { [mutableString appendString:@"Advertising|"]; }
    if (bits &  TKBluetoothCommunicatorStatusBitSending)                 { [mutableString appendString:@"Sending|"]; }
    if (bits &  TKBluetoothCommunicatorStatusBitConnecting)              { [mutableString appendString:@"Connecting|"]; }
    if (bits &  TKBluetoothCommunicatorStatusBitConnected)               { [mutableString appendString:@"Connected|"]; }
    if (bits &  TKBluetoothCommunicatorStatusBitWaitingForSystem)        { [mutableString appendString:@"WaitingForSystem|"]; }
    if (bits &  TKBluetoothCommunicatorStatusBitWaitingForUserInput)     { [mutableString appendString:@"WaitingForUserInput|"]; }
    if (bits &  TKBluetoothCommunicatorStatusBitUnsupported)             { [mutableString appendString:@"Unsupported|"]; }
    if (bits &  TKBluetoothCommunicatorStatusBitPanic)                   { [mutableString appendString:@"Panic|"]; }
    if (bits &  TKBluetoothCommunicatorStatusBitPublishingService)       { [mutableString appendString:@"PublishingService|"]; }
    if (bits &  TKBluetoothCommunicatorStatusBitPublishedService)        { [mutableString appendString:@"PublishedService|"]; }
    if (bits &  TKBluetoothCommunicatorStatusBitStartingAdvertising)     { [mutableString appendString:@"StartingAdvertising|"]; }
    // clang-format on

    [mutableString deleteCharactersInRange:NSMakeRange([mutableString length] - 1, 1)];
    return mutableString;
}

@end

@implementation TKSubdata {
    NSData *_data;
    NSRange _range;
}
- (instancetype)initWithData:(NSData *)data {
    return [self initWithData:data range:NSMakeRange(0, [data length])];
}
- (instancetype)initWithData:(NSData *)data range:(NSRange)range {
    DCHECK(data);
    DCHECK(range.location <= [data length]);
    DCHECK((range.location + range.length) <= [data length]);

    _data = data;
    _range = range;
    return self;
}
- (instancetype)initWithSubdata:(TKSubdata *)subdata range:(NSRange)range {
    DCHECK(subdata);
    DCHECK(range.location <= [subdata length]);
    DCHECK((range.location + range.length) <= [subdata length]);

    _data = [subdata data];
    _range = NSMakeRange([subdata range].location + range.location, range.length);
    return self;
}

// clang-format off
- (NSData *)data { return _data; }
- (NSRange)range { return _range; }
- (const uint8_t *)bytes { return (const uint8_t *)[_data bytes] + _range.location; }
- (NSUInteger)length { return _range.length; }
// clang-format on
@end

@implementation TKMutableSubdata {
    NSMutableData *_data;
    NSRange _range;
}
- (instancetype)initWithMutableData:(NSMutableData *)data {
    return [self initWithMutableData:data range:NSMakeRange(0, [data length])];
}
- (instancetype)initWithMutableData:(NSMutableData *)data range:(NSRange)range {
    DCHECK(data);
    DCHECK(range.location < [data length]);
    DCHECK((range.location + range.length) <= [data length]);

    _data = data;
    _range = range;
    return self;
}
- (uint8_t *)bytes {
    return (uint8_t *)[_data bytes] + _range.location;
}
- (NSUInteger)length {
    return _range.length;
}
@end

@implementation TKBluetoothCommunicatorEncoder {
    TKBluetoothCommunicator *_bluetoothCommunicator;
}
- (TKBluetoothCommunicator *)bluetoothCommunicator {
    return _bluetoothCommunicator;
}
- (instancetype)initWithBluetoothCommunicator:(TKBluetoothCommunicator *)bluetoothCommunicator {
    DCHECK(bluetoothCommunicator != nil);
    _bluetoothCommunicator = bluetoothCommunicator;
    return self;
}

- (NSData *)encodeShortMessage:(NSData *)data
                   messageType:(NSUInteger)messageType
           responseMessageType:(NSUInteger)responseMessageType {
    const NSUInteger dataLength = data != nil ? [data length] : 0;
    const uint8_t *dataBytes = data != nil ? (const uint8_t *)[data bytes] : NULL;

    const NSUInteger mutableDataLength = dataLength + TKBluetoothCommunicatorShortMessageStartByteIndex;
    NSMutableData *mutableData = [[NSMutableData alloc] initWithLength:mutableDataLength];
    uint8_t *messageBytes = (uint8_t *)[mutableData mutableBytes];

    messageBytes[TKBluetoothCommunicatorResponseMessageTypeByteIndex] = responseMessageType;
    messageBytes[TKBluetoothCommunicatorMessageTypeByteIndex] =
        [TKBluetoothCommunicatorMessage shortMessageType:messageType];

    for (NSUInteger i = 0; i < dataLength; ++i) {
        messageBytes[TKBluetoothCommunicatorShortMessageStartByteIndex + i] = dataBytes[i];
    }

    return mutableData;
}
- (NSData *)encodeLongMessage:(NSData *)data
                  messageType:(NSUInteger)messageType
          responseMessageType:(NSUInteger)responseMessageType {
    const NSUInteger dataLength = [data length];
    const uint8_t *dataBytes = (const uint8_t *)[data bytes];

    const NSUInteger mutableDataLength = dataLength + TKBluetoothCommunicatorLongMessageStartByteIndex;
    NSMutableData *mutableData = [[NSMutableData alloc] initWithLength:mutableDataLength];

    uint8_t *messageBytes = (uint8_t *)[mutableData mutableBytes];
    messageBytes[TKBluetoothCommunicatorResponseMessageTypeByteIndex] = responseMessageType;
    messageBytes[TKBluetoothCommunicatorMessageTypeByteIndex] =
        [TKBluetoothCommunicatorMessage longMessageType:messageType];

    NSRange lengthRange = NSMakeRange(TKBluetoothCommunicatorMessageLength0ByteIndex,
                                      TKBluetoothCommunicatorMessageLengthIntegerByteLength);
    TKMutableSubdata *lengthMutableSubdata = [[TKMutableSubdata alloc] initWithMutableData:mutableData
                                                                                     range:lengthRange];
    // NSMutableData* lengthMutableData = [NSDataNoCopyUtilities
    // mutableSubdataNoCopy:mutableData range:lengthRange];
    [TKBluetoothCommunicatorMessage intToBytes:[data length] writeTo:lengthMutableSubdata];

    for (NSUInteger i = 0; i < dataLength; ++i) {
        messageBytes[TKBluetoothCommunicatorLongMessageStartByteIndex + i] = dataBytes[i];
    }

    return mutableData;
}
- (NSData *)encodeMessage:(TKBluetoothCommunicatorDevice *)device
      messageContentsData:(NSData *)messageContentsData
              messageType:(NSUInteger)messageType
      responseMessageType:(NSUInteger)responseMessageType {
    NSUInteger wholeMessageLength = [messageContentsData length] + TKBluetoothCommunicatorShortMessageStartByteIndex;
    return wholeMessageLength > [device mtu] // If it fits, it sits.
               ? [self encodeLongMessage:messageContentsData
                             messageType:messageType
                     responseMessageType:responseMessageType]
               : [self encodeShortMessage:messageContentsData
                              messageType:messageType
                      responseMessageType:responseMessageType];
}

- (NSData *)encodeFileMessage:(TKBluetoothCommunicatorDevice *)device
                     fileName:(NSString *)fileName
                     fileData:(TKSubdata *)fileData
          responseMessageType:(NSUInteger)responseMessageType {
    NSData *fileNameData = [fileName dataUsingEncoding:NSUTF8StringEncoding];

    const uint8_t stringTermination[] = {0, 0};
    const NSUInteger messageContentsLength = [fileNameData length] + 2 + [fileData length];

    NSMutableData *messageContentsData = [[NSMutableData alloc] initWithCapacity:messageContentsLength];
    [messageContentsData appendData:fileNameData];
    [messageContentsData appendBytes:stringTermination length:sizeof(stringTermination)];
    [messageContentsData appendBytes:fileData.bytes length:[fileData length]];

    return [self encodeMessage:device
           messageContentsData:messageContentsData
                   messageType:TKBluetoothCommunicatorMessageTypeFile
           responseMessageType:responseMessageType];
}
- (NSData *)encodeConfirmationMessage:(TKBluetoothCommunicatorDevice *)device
                  responseMessageType:(NSUInteger)responseMessageType {
    return [self encodeMessage:device
           messageContentsData:nil
                   messageType:TKBluetoothCommunicatorMessageTypeConfirm
           responseMessageType:responseMessageType];
}
- (NSData *)encodeUUIDMessage:(TKBluetoothCommunicatorDevice *)device
          responseMessageType:(NSUInteger)responseMessageType {
    NSUUID *property = [_bluetoothCommunicator getUUID];
    return [self encodeMessage:device
           messageContentsData:[TKBluetoothCommunicatorMessage uuidToBytes:property]
                   messageType:TKBluetoothCommunicatorMessageTypeUUID
           responseMessageType:responseMessageType];
}
- (NSData *)encodeNameMessage:(TKBluetoothCommunicatorDevice *)device
          responseMessageType:(NSUInteger)responseMessageType {
    NSString *property = [_bluetoothCommunicator getName];
    return [self encodeMessage:device
           messageContentsData:[property dataUsingEncoding:NSUTF8StringEncoding]
                   messageType:TKBluetoothCommunicatorMessageTypeName
           responseMessageType:responseMessageType];
}
- (NSData *)encodeModelMessage:(TKBluetoothCommunicatorDevice *)device
           responseMessageType:(NSUInteger)responseMessageType {
    NSString *property = [_bluetoothCommunicator getModel];
    return [self encodeMessage:device
           messageContentsData:[property dataUsingEncoding:NSUTF8StringEncoding]
                   messageType:TKBluetoothCommunicatorMessageTypeDeviceModel
           responseMessageType:responseMessageType];
}
- (NSData *)encodeFriendlyModelMessage:(TKBluetoothCommunicatorDevice *)device
                   responseMessageType:(NSUInteger)responseMessageType {
    NSString *property = [_bluetoothCommunicator getFriendlyModel];
    return [self encodeMessage:device
           messageContentsData:[property dataUsingEncoding:NSUTF8StringEncoding]
                   messageType:TKBluetoothCommunicatorMessageTypeDeviceFriendlyModel
           responseMessageType:responseMessageType];
}

@end

@implementation TKBluetoothCommunicatorDecoder {
    TKBluetoothCommunicator *_bluetoothCommunicator;
}
- (TKBluetoothCommunicator *)bluetoothCommunicator {
    return _bluetoothCommunicator;
}
- (instancetype)initWithBluetoothCommunicator:(TKBluetoothCommunicator *)bluetoothCommunicator {
    DCHECK(bluetoothCommunicator != nil);
    _bluetoothCommunicator = bluetoothCommunicator;
    return self;
}

- (void)decodeWholeFileMessageFrom:(TKBluetoothCommunicatorDevice *)device fileMessageContents:(NSData *)data {
    const uint8_t *rawPtr = (const uint8_t *)[data bytes];
    NSUInteger fileNameLength = 0;
    for (NSUInteger i = 1; i < [data length]; ++i) {
        if (rawPtr[i - 1] == 0 && rawPtr[i] == 0) {
            fileNameLength = i - 1;
            break;
        }
    }

    if (fileNameLength == 0) {
        // DLOGF(@"%s: Failed to find file name length in the message data, "
        //      @"skipping "
        //      @"the message.",
        //      TK_FUNC_NAME);
        return;
    }

    // DLOGF(@"%s: File name length = %u", TK_FUNC_NAME, fileNameLength);

    DCHECK([data length] > (fileNameLength + 2));
    if ([data length] <= (fileNameLength + 2)) {
        // DLOGF(@"%s: The message data appeared insufficient to store file data, "
        //      @"skipping the message.",
        //      TK_FUNC_NAME);
        return;
    }

    NSUInteger fileLength = [data length] - fileNameLength - 2;
    DCHECK(fileLength > 0);

    NSString *fileName = [[NSString alloc] initWithBytes:rawPtr length:fileNameLength encoding:NSUTF8StringEncoding];
    DCHECK(fileName && [fileName length] > 0);

    NSData *fileData = [[NSData alloc] initWithBytes:(rawPtr + fileNameLength + 2) length:fileLength];
    DCHECK(fileData && [fileData length] > 0);

    [TKFileSaver saveFile:fileName fileData:fileData];
}

+ (NSString *)utf8StringInitWithSubdata:(TKSubdata *)subdata {
    NSString *stringProperty = [[NSString alloc] initWithBytes:[subdata bytes]
                                                        length:[subdata length]
                                                      encoding:NSUTF8StringEncoding];
    return stringProperty;
}

- (void)decodeWholeMessageFrom:(TKBluetoothCommunicatorDevice *)device
        undecoratedMessageType:(NSUInteger)undecoratedMessageType
               messageContents:(TKSubdata *)messageContents {
    switch (undecoratedMessageType) {
        case TKBluetoothCommunicatorMessageTypeFinish: {
            // DLOGF(@"%s: Received EOM", TK_FUNC_NAME);
        } break;

        case TKBluetoothCommunicatorMessageTypeFile: {
            [self decodeWholeFileMessageFrom:device fileMessageContents:messageContents];
        } break;

        case TKBluetoothCommunicatorMessageTypeUUID: {
            if (nil == [device getUUID]) {
                NSUUID *uuid = [TKBluetoothCommunicatorMessage bytesToUUID:messageContents];
                [device setUUID:uuid];

                // DLOGF(@"%s: Assigned UUID: %@", TK_FUNC_NAME, uuid);
            } else {
                // DLOGF(@"%s: Skinned UUID, already assigned.", TK_FUNC_NAME);
            }
        } break;
        case TKBluetoothCommunicatorMessageTypeName: {
            if ([TKStringUtilities isNilOrEmpty:[device getName]]) {
                NSString *stringProperty = [TKBluetoothCommunicatorDecoder utf8StringInitWithSubdata:messageContents];
                [device setName:stringProperty];

                // DLOGF(@"%s: Received name: %@", TK_FUNC_NAME, stringProperty);
            } else {
                // DLOGF(@"%s: Skinned name, already assigned.", TK_FUNC_NAME);
            }
        } break;
        case TKBluetoothCommunicatorMessageTypeDeviceModel: {
            if ([TKStringUtilities isNilOrEmpty:[device getModel]]) {
                NSString *stringProperty = [TKBluetoothCommunicatorDecoder utf8StringInitWithSubdata:messageContents];
                [device setModel:stringProperty];

                // DLOGF(@"%s: Received model: %@", TK_FUNC_NAME, stringProperty);
            } else {
                // DLOGF(@"%s: Skinned model name, already assigned.", TK_FUNC_NAME);
            }
        } break;
        case TKBluetoothCommunicatorMessageTypeDeviceFriendlyModel: {
            if ([TKStringUtilities isNilOrEmpty:[device getFriendlyModel]]) {
                NSString *stringProperty = [TKBluetoothCommunicatorDecoder utf8StringInitWithSubdata:messageContents];
                [device setFriendlyModel:stringProperty];

                // DLOGF(@"%s: Received friendly model: %@", TK_FUNC_NAME, stringProperty);
            } else {
                // DLOGF(@"%s: Skinned friendly model name, already assigned.", TK_FUNC_NAME);
            }
        } break;

        default: {
            // DLOGF(@"%s: Received unexpected message type: %u", TK_FUNC_NAME, undecoratedMessageType);
        } break;
    }
}

- (void)decodeShortMessageFrom:(TKBluetoothCommunicatorDevice *)device
        undecoratedMessageType:(NSUInteger)undecoratedMessageType
              wholeMessageData:(TKSubdata *)wholeMessageData {
    const NSUInteger offset = TKBluetoothCommunicatorShortMessageStartByteIndex;
    const NSUInteger length = [wholeMessageData length] - offset;

    NSRange range = NSMakeRange(offset, length);
    TKSubdata *messageContents = [[TKSubdata alloc] initWithSubdata:wholeMessageData range:range];

    [self decodeWholeMessageFrom:device undecoratedMessageType:undecoratedMessageType messageContents:messageContents];
}
@end

@implementation TKBluetoothCommunicatorScheduledOperation {
    NSData *_data;
    bool _requiresResponse;
}

- (NSData *)data {
    return _data;
}
- (bool)requiresResponse {
    return _requiresResponse;
}

- (instancetype)initWithData:(NSData *)data requiresResponse:(bool)requiresResponse {
    _data = data;
    _requiresResponse = requiresResponse;
    return self;
}
@end

@implementation TKBluetoothCommunicatorScheduler {
    TKBluetoothCommunicator *_bluetoothCommunicator;
    TKBluetoothCommunicatorEncoder *_encoder;
    TKBluetoothCommunicatorDecoder *_decoder;
    // dispatch_queue_t _readQueue;
    // dispatch_queue_t _writeQueue;
    NSMutableDictionary *_scheduledReads;
    NSMutableDictionary *_scheduledWrites;
    NSMutableDictionary *_longMessages;
    BOOL _shouldReflush;
}

- (TKBluetoothCommunicator *)bluetoothCommunicator {
    return _bluetoothCommunicator;
}
- (TKBluetoothCommunicatorEncoder *)bluetoothCommunicatorEncoder {
    return _encoder;
}
- (TKBluetoothCommunicatorDecoder *)bluetoothCommunicatorDecoder {
    return _decoder;
}
- (instancetype)initWithBluetoothCommunicator:(TKBluetoothCommunicator *)bluetoothCommunicator {
    DCHECK(bluetoothCommunicator != nil);
    _bluetoothCommunicator = bluetoothCommunicator;
    _encoder = [[TKBluetoothCommunicatorEncoder alloc] initWithBluetoothCommunicator:bluetoothCommunicator];
    _decoder = [[TKBluetoothCommunicatorDecoder alloc] initWithBluetoothCommunicator:bluetoothCommunicator];
    // _readQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    // _writeQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

    _scheduledReads = [[NSMutableDictionary alloc] init];
    _scheduledWrites = [[NSMutableDictionary alloc] init];
    _longMessages = [[NSMutableDictionary alloc] init];
    _shouldReflush = false;

    return self;
}

- (NSMutableArray *)nilForEmptyOperations:(NSMutableArray *)operations {
    return operations && [operations count] ? operations : nil;
}

- (NSMutableArray *)synchronizedGetOperations:(TKBluetoothCommunicatorDevice *)device
                          operationDictionary:(NSMutableDictionary *)operationDictionary {
    if (operationDictionary == nil || device == nil) { return nil; }

    NSMutableArray *operations = nil;
    @synchronized(operationDictionary) {
        operations = [operationDictionary objectForKey:device];
    }
    return operations;
}

- (NSMutableArray *)synchronizedGetOrCreateOperations:(TKBluetoothCommunicatorDevice *)device
                                  operationDictionary:(NSMutableDictionary *)operationDictionary {
    if (operationDictionary == nil || device == nil) { return nil; }

    NSMutableArray *operations = [operationDictionary objectForKey:device];
    if (operations == nil) {
        @synchronized(self) {
            operations = [operationDictionary objectForKey:device];
            if (operations == nil) {
                operations = [[NSMutableArray alloc] init];
                [operationDictionary setObject:operations forKey:device];
            }
        }
    }

    return operations;
}

- (NSMutableArray *)synchronizedGetOperationsOrNil:(TKBluetoothCommunicatorDevice *)device
                               operationDictionary:(NSMutableDictionary *)operationDictionary {
    return [self nilForEmptyOperations:[self synchronizedGetOperations:device operationDictionary:operationDictionary]];
}

- (TKBluetoothCommunicatorScheduledOperation *)synchronizedPollFirstOperation:(NSMutableArray *)operations {
    TKBluetoothCommunicatorScheduledOperation *operation = nil;
    @synchronized(operations) {
        operation = [operations firstObject];
        [operations removeObjectAtIndex:0];
    }
    return operation;
}

- (void)synchronizedRemoveFirstOperation:(NSMutableArray *)operations {
    @synchronized(operations) {
        assert([operations count] > 0);
        [operations removeObjectAtIndex:0];
    }
}

- (TKBluetoothCommunicatorScheduledOperation *)synchronizedPeekFirstOperation:(NSMutableArray *)operations {
    TKBluetoothCommunicatorScheduledOperation *operation = nil;
    @synchronized(operations) {
        operation = [operations firstObject];
    }
    return operation;
}

- (bool)shouldExecuteOperations:(NSMutableDictionary *)operationDictionary {
    NSArray *allKeys = nil;
    @synchronized(operationDictionary) {
        allKeys = [operationDictionary allKeys];
    }

    const NSUInteger keyCount = [allKeys count];
    for (NSUInteger i = 0; i < keyCount; ++i) {
        TKBluetoothCommunicatorDevice *device = [allKeys objectAtIndex:i];
        DCHECK(device != nil);
        if (!device) { continue; }

        NSMutableArray *operations = [self synchronizedGetOperationsOrNil:device
                                                      operationDictionary:operationDictionary];
        if (operations && [operations count]) { return true; }
    }

    return false;
}

- (void)executeOperations:(NSMutableDictionary *)operationDictionary
    skipWithPendingWrites:(BOOL)skipWithPendingWrites
        operationExecutor:(TKBluetoothCommunicatorOperationExecutionResult (^)(id device, id data))operationExecutor {
    NSArray *allKeys = nil;
    @synchronized(operationDictionary) {
        allKeys = [operationDictionary allKeys];
    }

    const NSUInteger keyCount = [allKeys count];
    // DLOGF(@"%s: devices = %u", TK_FUNC_NAME, keyCount);

    for (NSUInteger i = 0; i < keyCount; ++i) {
        TKBluetoothCommunicatorDevice *device = [allKeys objectAtIndex:i];
        DCHECK(device != nil);
        // // DLOGF(@"%s: device = %p, executing operations", TK_FUNC_NAME, device);

        if (!device) {
            assert(false);
            continue;
        }
        if (skipWithPendingWrites && [device pendingWriteValue]) {
            // DLOGF(@"%s: device = %p, skipping with pending write", TK_FUNC_NAME, device);
            continue;
        }

        NSMutableArray *operations = [self synchronizedGetOperationsOrNil:device
                                                      operationDictionary:operationDictionary];
        if (!operations) {
            // DLOGF(@"%s: device = %p, no scheduled operations", TK_FUNC_NAME, device);
            continue;
        }

        NSUInteger operationCount = 0;
        while ((void)(operationCount = [operations count]), operationCount) {
            TKBluetoothCommunicatorScheduledOperation *operation = [self synchronizedPeekFirstOperation:operations];
            if (!operation) {
                assert(false);
                [self synchronizedRemoveFirstOperation:operations];
                continue;
            }

            TKBluetoothCommunicatorOperationExecutionResult result = operationExecutor(device, operation);
            switch (result) {
                case TKBluetoothCommunicatorOperationExecutionResultFailedRetryLater:
                    return;
                default:
                    // case
                    // TKBluetoothCommunicatorOperationExecutionResultSuccessContinue:
                    // case
                    // TKBluetoothCommunicatorOperationExecutionResultFailedContinue:
                    [self synchronizedRemoveFirstOperation:operations];
                    break;
            }
        }
    }
}

- (NSData *)encodeResponse:(TKBluetoothCommunicatorDevice *)device messageType:(NSUInteger)messageType {
    NSData *responseData = nil;
    switch (messageType) {
        case TKBluetoothCommunicatorMessageTypeUUID: {
            NSUInteger responseMessageType =
                [device getUUID] ? TKBluetoothCommunicatorMessageTypeFinish : TKBluetoothCommunicatorMessageTypeUUID;
            responseData = [_encoder encodeUUIDMessage:device responseMessageType:responseMessageType];
        } break;
        case TKBluetoothCommunicatorMessageTypeName: {
            bool deviceHasName = ![TKStringUtilities isNilOrEmpty:[device getName]];
            NSUInteger responseMessageType =
                deviceHasName ? TKBluetoothCommunicatorMessageTypeFinish : TKBluetoothCommunicatorMessageTypeName;
            responseData = [_encoder encodeNameMessage:device responseMessageType:responseMessageType];
        } break;
        case TKBluetoothCommunicatorMessageTypeDeviceModel: {
            bool deviceHasProperty = ![TKStringUtilities isNilOrEmpty:[device getModel]];
            NSUInteger responseMessageType = deviceHasProperty ? TKBluetoothCommunicatorMessageTypeFinish
                                                               : TKBluetoothCommunicatorMessageTypeDeviceModel;
            responseData = [_encoder encodeModelMessage:device responseMessageType:responseMessageType];
        } break;
        case TKBluetoothCommunicatorMessageTypeDeviceFriendlyModel: {
            bool deviceHasProperty = ![TKStringUtilities isNilOrEmpty:[device getFriendlyModel]];
            NSUInteger responseMessageType = deviceHasProperty ? TKBluetoothCommunicatorMessageTypeFinish
                                                               : TKBluetoothCommunicatorMessageTypeDeviceFriendlyModel;
            responseData = [_encoder encodeFriendlyModelMessage:device responseMessageType:responseMessageType];
        } break;

        case TKBluetoothCommunicatorMessageTypeConfirm:
            responseData = [_encoder encodeConfirmationMessage:device
                                           responseMessageType:TKBluetoothCommunicatorMessageTypeFinish];
            break;

        case TKBluetoothCommunicatorMessageTypeFinish:
        case TKBluetoothCommunicatorMessageTypeFile: {
            // DLOGF(@"%s: Not responding.", TK_FUNC_NAME);
        } break;

        default: {
            // DLOGF(@"%s: Not responding, unknown response type requested.", TK_FUNC_NAME);
        } break;
    }

    return responseData;
}

- (NSUInteger)decodeReceivedMessageAndRespond:(TKBluetoothCommunicatorDevice *)device
                          receivedMessageData:(NSData *)receivedMessageData {
    NSUInteger responseMessageType = TKBluetoothCommunicatorMessageTypeFinish;

    TKBluetoothCommunicatorLongMessage *longMessage = [_longMessages objectForKey:device];
    if (longMessage != nil) {
        // DLOGF(@"%s: Resuming the long message.", TK_FUNC_NAME);

        if ([longMessage append:receivedMessageData]) {
            DCHECK([longMessage isComplete]);
            // DLOGF(@"%s: Completing the long message.", TK_FUNC_NAME);

            responseMessageType = [longMessage getResponseMessageType];

            const NSUInteger decoratedMessageType = [longMessage getMessageType];
            const NSUInteger undecoratedMessageType =
                [TKBluetoothCommunicatorMessage undecorateMessageType:decoratedMessageType];
            NSData *messageContents = [longMessage getMessageContents];
            TKSubdata *messageContentsSubdata = [[TKSubdata alloc] initWithData:messageContents];

            [_decoder decodeWholeMessageFrom:device
                      undecoratedMessageType:undecoratedMessageType
                             messageContents:messageContentsSubdata];

            [longMessage clear];
            [_longMessages removeObjectForKey:device];
        } else {
            DCHECK(![longMessage isComplete]);
            DLOGF(@"%s: %lu/%lu bytes received, %.3f%% complete, speed %.2f kb/s, ETA %im%is",
                  TK_FUNC_NAME,
                  [longMessage getMessageContentsOffset],
                  [longMessage getMessageContentsLength],
                  double([longMessage getMessageContentsOffset]) / double([longMessage getMessageContentsLength]) * 100.0,
                  [longMessage bytesPerSecond] / 1024.0,
                  (int)floor([longMessage secondsETA] / 60.0),
                  (int)(([longMessage secondsETA] - floor([longMessage secondsETA])) * 60.0));

            responseMessageType = TKBluetoothCommunicatorMessageTypeConfirm;
        }
    } else {
        const NSUInteger decoratedMessageType = [TKBluetoothCommunicatorMessage getMessageType:receivedMessageData];
        const NSUInteger undecoratedMessageType =
            [TKBluetoothCommunicatorMessage undecorateMessageType:decoratedMessageType];
        const bool isMessageShort = [TKBluetoothCommunicatorMessage isShortMessage:decoratedMessageType];

        if (isMessageShort) {
            // DLOGF(@"%s: Sending short message to parser.", TK_FUNC_NAME);

            [_decoder decodeShortMessageFrom:device
                      undecoratedMessageType:undecoratedMessageType
                            wholeMessageData:[[TKSubdata alloc] initWithData:receivedMessageData]];

            responseMessageType = [TKBluetoothCommunicatorMessage getResponseMessageType:receivedMessageData];
        } else {
            // DLOGF(@"%s: Starting long message.", TK_FUNC_NAME);

            TKBluetoothCommunicatorLongMessage *longMessage =
                [[TKBluetoothCommunicatorLongMessage alloc] initWithMessageData:receivedMessageData];
            [_longMessages setObject:longMessage forKey:device];

            responseMessageType = TKBluetoothCommunicatorMessageTypeConfirm;
        }
    }

    return responseMessageType;
}

- (void)executeReads {
    // DLOGF(@"%s: scheduled reads count = %u", TK_FUNC_NAME, _scheduledReads.count);
    [self executeOperations:_scheduledReads
        skipWithPendingWrites:false
            operationExecutor:^(id deviceId, id operationId) {
                TKBluetoothCommunicatorDevice *device = deviceId;
                TKBluetoothCommunicatorScheduledOperation *operation = operationId;
                DCHECK(device && operation);

                // DLOGF(@"%s: device = %p, executing read operation", TK_FUNC_NAME, device);
                [device setPendingWriteValue:false];

                NSUInteger responseMessageType = [self decodeReceivedMessageAndRespond:device
                                                                   receivedMessageData:[operation data]];

                NSData *responseMessageData = [self encodeResponse:device messageType:responseMessageType];
                if (responseMessageData) {
                    // DLOGF(@"%s: Responding with message type: %u, reflushing", TK_FUNC_NAME, responseMessageType);
                    [self scheduleMessageTo:device wholeMessageData:responseMessageData shouldFlush:false];
                    self->_shouldReflush = true;
                }

                return TKBluetoothCommunicatorOperationExecutionResultSuccessContinue;
            }];
}

- (void)executeWrites {
    // DLOGF(@"%s: scheduled writes count = %u", TK_FUNC_NAME, _scheduledWrites.count);
    [self executeOperations:_scheduledWrites
        skipWithPendingWrites:true
            operationExecutor:^(id deviceId, id operationId) {
                TKBluetoothCommunicatorDevice *device = deviceId;
                TKBluetoothCommunicatorScheduledOperation *operation = operationId;
                DCHECK(device && operation);
                // DLOGF(@"%s: device = %p, executing write operation", TK_FUNC_NAME, device);

                TKBluetoothCommunicatorWriteValueResult result = [self.bluetoothCommunicator writeValue:[operation data]
                                                                                               toDevice:device];
                switch (result) {
                    case TKBluetoothCommunicatorWriteValueResultSuccessContinue:
                        // DLOGF(@"%s: device = %p, write operation succeeded", TK_FUNC_NAME, device);

                        if ([operation requiresResponse]) {
                            // DLOGF(@"%s: device = %p, setting pending write to true", TK_FUNC_NAME, device);
                            [device setPendingWriteValue:true];
                        }

                        return TKBluetoothCommunicatorOperationExecutionResultSuccessContinue;

                    case TKBluetoothCommunicatorWriteValueResultFailedReschedule:
                        // DLOGF(@"%s: device = %p, write operation rescheduled", TK_FUNC_NAME, device);
                        return TKBluetoothCommunicatorOperationExecutionResultFailedRetryLater;
                    default:
                        // DLOGF(@"%s: device = %p, write operation failed", TK_FUNC_NAME, device);
                        return TKBluetoothCommunicatorOperationExecutionResultFailedContinue;
                }
            }];
}

- (void)flush {
    [self executeReads];
    [self executeWrites];

    if (_shouldReflush) {
        // DLOGF(@"%s: reflusing.", TK_FUNC_NAME);
        _shouldReflush = false;
        [self flush];
    }

    // dispatch_async(_readQueue, ^{ [self executeReads]; });
    // dispatch_async(_writeQueue, ^{ [self executeWrites]; });
}

- (bool)scheduleMessageFrom:(TKBluetoothCommunicatorDevice *)device wholeMessageData:(NSData *)wholeMessageData {
    NSMutableArray *mutableArray = [self synchronizedGetOrCreateOperations:device operationDictionary:_scheduledReads];
    DCHECK(mutableArray);
    if (!mutableArray) {
        assert(false);
        return false;
    }

    TKBluetoothCommunicatorScheduledOperation *op =
        [[TKBluetoothCommunicatorScheduledOperation alloc] initWithData:wholeMessageData requiresResponse:true];
    @synchronized(mutableArray) {
        [mutableArray addObject:op];
    }
    [self flush];
    return true;
}

- (bool)scheduleMessageTo:(TKBluetoothCommunicatorDevice *)device wholeMessageData:(NSData *)wholeMessageData {
    return [self scheduleMessageTo:device wholeMessageData:wholeMessageData shouldFlush:true];
}

- (bool)scheduleMessageTo:(TKBluetoothCommunicatorDevice *)device
         wholeMessageData:(NSData *)wholeMessageData
              shouldFlush:(BOOL)shouldFlush {
    NSMutableArray *mutableArray = [self synchronizedGetOrCreateOperations:device operationDictionary:_scheduledWrites];
    if (!mutableArray) {
        assert(false);
        return false;
    }

    if ([device mtu] >= [wholeMessageData length]) {
        bool requiresResponse = [TKBluetoothCommunicatorMessage requiresResponse:wholeMessageData];
        TKBluetoothCommunicatorScheduledOperation *op =
            [[TKBluetoothCommunicatorScheduledOperation alloc] initWithData:wholeMessageData
                                                           requiresResponse:requiresResponse];
        @synchronized(mutableArray) {
            [mutableArray addObject:op];
        }
    } else {
        NSUInteger messageChunkFrom = 0;
        while (messageChunkFrom < [wholeMessageData length]) {
            NSUInteger writableLength = [wholeMessageData length] - messageChunkFrom;
            writableLength = MIN([device mtu], writableLength);
            DCHECK(writableLength > 0 && "writableLength > 0");

            NSRange messageChunkRange = NSMakeRange(messageChunkFrom, writableLength);
            NSData *messageChunk = [wholeMessageData subdataWithRange:messageChunkRange];
            messageChunkFrom += writableLength;

            bool requiresResponse = true;
            TKBluetoothCommunicatorScheduledOperation *op =
                [[TKBluetoothCommunicatorScheduledOperation alloc] initWithData:messageChunk
                                                               requiresResponse:requiresResponse];
            @synchronized(mutableArray) {
                [mutableArray addObject:op];
            }
        }
    }

    if (shouldFlush) { [self flush]; }

    return true;
}

- (void)scheduleIntroductionMessagesTo:(TKBluetoothCommunicatorDevice *)device {
    // DLOGF(@"%s", TK_FUNC_NAME);

    NSData *uuidMsgData = [_encoder encodeUUIDMessage:device
                                  responseMessageType:TKBluetoothCommunicatorMessageTypeUUID];
    [self scheduleMessageTo:device wholeMessageData:uuidMsgData];

    NSData *nameMsgData = [_encoder encodeNameMessage:device
                                  responseMessageType:TKBluetoothCommunicatorMessageTypeName];
    [self scheduleMessageTo:device wholeMessageData:nameMsgData];

    NSData *modelMsgData = [_encoder encodeModelMessage:device
                                    responseMessageType:TKBluetoothCommunicatorMessageTypeDeviceModel];
    [self scheduleMessageTo:device wholeMessageData:modelMsgData];

    NSData *friendlyModelMsgData =
        [_encoder encodeFriendlyModelMessage:device
                         responseMessageType:TKBluetoothCommunicatorMessageTypeDeviceFriendlyModel];
    [self scheduleMessageTo:device wholeMessageData:friendlyModelMsgData];
}

@end
