#import "BluetoothCommunicator.h"
#import <UIKit/UIKit.h>

#import <sys/utsname.h>
#include <stdatomic.h>

#define FUNC_NAME __PRETTY_FUNCTION__
#define UUID_KEY @"BluetoothCommunicatorUUID"

#ifdef DEBUG
#define TK_DEBUG 1
#else
#define TK_DEBUG 0
#endif

#define GUARDED_BY(lock)

// static const NSTimeInterval kScanningTimeoutSeconds   = 10.0;
// static const NSTimeInterval kConnectingTimeoutSeconds = 30.0;
// static const NSTimeInterval kRequestTimeoutSeconds    = 20.0;

NSUInteger unsetBit(const NSUInteger bits, const NSUInteger bit) {
    return bits & ~bit;
}
NSUInteger setBit(const NSUInteger bits, const NSUInteger bit) {
    return bits | bit;
}
bool isBitSet(const NSUInteger bits, const NSUInteger bit) {
    return (bits & bit) == bit;
}

@interface BluetoothCommunicatorDevice ( )

@property( nonatomic, assign ) BluetoothCommunicator * bluetoothCommunicator;
@property( nonatomic, assign ) NSInteger               localId;
@property( nonatomic, assign ) NSInteger               mtu;
@property( nonatomic, assign ) NSInteger               maxWriteLength;
@property( nonatomic, assign ) NSInteger               maxWriteLengthWithResponse;
@property( nonatomic, strong ) CBPeripheral *          peripheral;
@property( nonatomic, strong ) CBService *             service;
@property( nonatomic, strong ) CBCharacteristic *      characteristic;
@property( nonatomic, strong ) NSString *              deviceName;
@property( nonatomic, strong ) NSString *              deviceModel;
@property( nonatomic, strong ) NSString *              deviceFriendlyModel;
@property( nonatomic, strong ) NSUUID *                deviceUUID;
@property( atomic, assign ) bool                       pendingWriteValue;
// @property( atomic, assign ) NSUInteger                 currentLongMessageType;
// @property( atomic, assign ) NSUInteger                 currentLongMessageContentsLength;
// @property( atomic, strong ) NSMutableData *            currentLongMessageContents;

@end

@implementation BluetoothCommunicatorDevice
- (NSInteger)getId { return [self localId]; }
- (NSInteger)getMTU { return [self mtu]; }
- (NSUUID *)getUUID { return [self deviceUUID]; }
- (NSString *)getName { return [self deviceName]; }
- (NSString *)getModel { return [self deviceModel]; }
- (NSString *)getFriendlyModel { return [self deviceFriendlyModel]; }

- (instancetype)init {
    [self setDeviceName:[NSStringUtilities empty]];
    [self setDeviceModel:[NSStringUtilities empty]];
    [self setDeviceFriendlyModel:[NSStringUtilities empty]];
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

- (BOOL)isEqual:(id)object {
    if (nil == object) { return false; }
    if (self == object) { return true; }
    if (![object isKindOfClass:[self class]]) { return false; }
    
    BluetoothCommunicatorDevice* other = object;
    return [[self peripheral] isEqual:[other peripheral]];
}

- (NSUInteger)hash {
    return [[self peripheral] hash];
}

- (id)copyWithZone:(NSZone *)zone {
    id copy = [[[self class] alloc] init];
    [copy setBluetoothCommunicator:[self bluetoothCommunicator]];
    [copy setLocalId:[self localId]];
    [copy setMtu:[self mtu]];
    [copy setMaxWriteLength:[self maxWriteLength]];
    [copy setMaxWriteLengthWithResponse:[self maxWriteLengthWithResponse]];
    [copy setPeripheral:[self peripheral]];
    [copy setService:[self service]];
    [copy setCharacteristic:[self characteristic]];
    [copy setDeviceName:[self deviceName]];
    [copy setDeviceModel:[self deviceModel]];
    [copy setDeviceFriendlyModel:[self deviceFriendlyModel]];
    [copy setDeviceUUID:[self deviceUUID]];
    [copy setPendingWriteValue:[self pendingWriteValue]];
    return copy;
}

//- (NSUInteger)longMessageType {
//    return [self currentLongMessageType];
//}
//- (NSUInteger)longMessageContentsLength {
//    return [self currentLongMessageContentsLength];
//}
//
//- (void)startLongMessage:(NSUInteger)messageType messageContentsLength:(NSUInteger)messageContentsLength messageContents:(NSData *)messageContents {
//    assert(![self didStartLongMessage]);
//
//    [self setCurrentLongMessageType:messageType];
//    [self setCurrentLongMessageContentsLength:messageContentsLength];
//    [self setCurrentLongMessageContents:[[NSMutableData alloc] initWithCapacity:messageContentsLength]];
//    [[self currentLongMessageContents] appendData:messageContents];
//}
//
//- (void)appendLongMessageContents:(NSData *)messageContentsRange {
//    [[self currentLongMessageContents] appendData:messageContentsRange];
//}
//
//- (NSData*)getAndForgetLongMessageContents {
//    assert([self didFinishLongMessage]);
//
//    NSData* result = [self currentLongMessageContents];
//    [self setCurrentLongMessageContents:nil];
//    return result;
//}
//
//- (bool)didStartLongMessage {
//    return [self currentLongMessageContents] != nil;
//}
//
//- (bool)didFinishLongMessage {
//    return [self didStartLongMessage] && [[self currentLongMessageContents] length] == [self currentLongMessageContentsLength];
//}

@end

@interface BluetoothCommunicator ( ) < CBCentralManagerDelegate, CBPeripheralDelegate >
@end

@implementation BluetoothCommunicator {
    CBCentralManager *                  _centralManager;
    NSUInteger                          _statusBits;
    id< BluetoothCommunicatorDelegate > _delegate;
    NSArray< CBUUID * > *               _serviceUUIDs;
    NSArray< CBUUID * > *               _characteristicUUIDs;
    NSMutableSet *                      _connectingDevices;
    NSMutableDictionary *               _connectedDevices;
    NSUUID *                            _UUID;
    NSString *                          _name;
    NSString *                          _model;
    NSString *                          _friendlyModel;
    atomic_bool                         _scanningFlag;
    BluetoothCommunicatorScheduler*     _scheduler;
}

static BluetoothCommunicator *_instance = nil;

+ (id)instance {
    @synchronized( self ) {
        if ( _instance == nil ) {
            _instance = [[self alloc] init];
            [Debug setBluetoothCommunicator:_instance];
        }
    }
    
    return _instance;
}

+ (NSString *)createModelName {
    struct utsname systemInfo;
    uname(&systemInfo);
    return [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
}

- (NSUInteger)statusBits {
    return _statusBits;
}

- (void)prepareUUIDs {
    DLOGF( @"%s", FUNC_NAME );
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString* stringUUID = [defaults objectForKey:UUID_KEY];
    NSUUID* deviceUUID = nil;
    
    if (stringUUID == nil || [stringUUID length] == 0) {
        DLOGF( @"%s, adding UUID to standard user defaults", FUNC_NAME );
        deviceUUID = [NSUUID UUID];
        stringUUID = [deviceUUID UUIDString];
        [defaults setObject:stringUUID forKey:UUID_KEY];
        [defaults synchronize];
    } else {
        deviceUUID = [[NSUUID alloc] initWithUUIDString:stringUUID];
    }
    
    DLOGF( @"%s: UUID %@", FUNC_NAME, deviceUUID );
    
    _UUID = deviceUUID;
    _serviceUUIDs = @[ [CBUUID UUIDWithString:@"07BDC246-B8DD-4240-9743-EDD6B9AFF20F"] ];
    _characteristicUUIDs = @[ [CBUUID UUIDWithString:@"4035D667-4896-4C38-8010-837506F54932"] ];
    
    DLOGF( @"%s: Service UUID %@", FUNC_NAME, [_serviceUUIDs objectAtIndex:0] );
    DLOGF( @"%s: Characteristic UUID %@", FUNC_NAME, [_characteristicUUIDs objectAtIndex:0] );
}

- (void)prepareName {
    DLOGF( @"%s", FUNC_NAME );
    _name = [[UIDevice currentDevice] name];
    _model = [BluetoothCommunicator createModelName];
    _friendlyModel = [BluetoothCommunicator createModelFriendlyName];
}

- (NSUUID *)getUUID {
    return _UUID;
}

- (NSString *)getName {
    return _name;
}

- (NSString *)getModel {
    return _model;
}

- (NSString *)getFriendlyModel {
    return _friendlyModel;
}

- (void)initCentralWithDelegate:(id< BluetoothCommunicatorDelegate >)delegate {
    DLOGF( @"%s", FUNC_NAME );
    if (isBitSet(_statusBits, BTCStatusBitStartingCentral | BTCStatusBitCentral)) {
        [Debug check:false file:@__FILE__ line:__LINE__ tag:@"BluetoothCommunicator" msg:@"Already initialized"];
        return;
    }

    atomic_store(&_scanningFlag, false);

    _delegate = delegate;
    _statusBits = BTCStatusBitStartingCentral;
    _scheduler = [[BluetoothCommunicatorScheduler alloc] initWithBluetoothCommunicator:self];
    
    _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil options:nil];
    
    [self prepareUUIDs];
    [self prepareName];
}

- (void)cancelConnectionForDevice:(BluetoothCommunicatorDevice *)device {
    DLOGF( @"%s", FUNC_NAME );
    // TODO: Remove and get the removed item in one call? I wish they had removeObjectForKey() function
    //       that returns the remove instance, just to avoid multiple lookups. Maybe we should use
    //       std containers or smth self-written.

    [_connectedDevices removeObjectForKey:[device peripheral]];
    [_centralManager cancelPeripheralConnection:[device peripheral]];
    [_delegate bluetoothCommunicator:self didDisconnectDevice:device];
}

- (void)peripheral:(CBPeripheral *)peripheral
    didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic
                              error:(NSError *)error {
    DLOGF( @"%s", FUNC_NAME );

    if ( peripheral == nil ) {
        DLOGF( @"%s: peripheral is not available, update is skipped.", FUNC_NAME );
        return;
    }

    DLOGF( @"%s: peripheral=%@, UUID=%@, name=%@", FUNC_NAME, peripheral, peripheral.identifier, peripheral.name );

    if ( characteristic == nil ) {
        DLOGF( @"%s: characteristic is not available, update is skipped.", FUNC_NAME );
        return;
    }

    DLOGF( @"%s: characteristic=%@, UUID=%@", FUNC_NAME, characteristic, characteristic.UUID );

    BluetoothCommunicatorDevice *device = [_connectedDevices objectForKey:peripheral];
    if ( device == nil || ( [device peripheral] != peripheral ) || ( [device characteristic] != characteristic ) ) {
        DLOGF( @"%s: Caught unexpected peripheral.", FUNC_NAME );
        return;
    }

    if ( error ) {
        DLOGF( @"%s: Caught error, description=%@", FUNC_NAME, [error description] );
        DLOGF( @"%s: Caught error, debugDescription=%@", FUNC_NAME, [error debugDescription] );
        DLOGF( @"%s: Caught error, code=%ld", FUNC_NAME, (long) [error code] );

        [_delegate bluetoothCommunicator:self didReceiveValue:nil orError:error fromDevice:device];
        return;
    }

    [_scheduler scheduleMessageFrom:device wholeMessageData:characteristic.value];
    [_delegate bluetoothCommunicator:self didReceiveValue:characteristic.value orError:nil fromDevice:device];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    DLOGF( @"%s", FUNC_NAME );

    if ( peripheral == nil ) {
        NSLog( @"%s: peripheral is not available, peripheral is skipped.", FUNC_NAME );
        return;
    }

    DLOGF( @"%s: peripheral=%@, UUID=%@, name=%@", FUNC_NAME, peripheral, peripheral.identifier, peripheral.name );

    BluetoothCommunicatorDevice *device = [_connectedDevices objectForKey:peripheral];
    if ( device == nil || ( [device peripheral] != peripheral ) || ( [device service] != service ) ) {
        DLOGF( @"%s: Caught unexpected peripheral.", FUNC_NAME );
        return;
    }

    if ( error ) {
        DLOGF( @"%s: Caught error, description=%@", FUNC_NAME, [error description] );
        DLOGF( @"%s: Caught error, debugDescription=%@", FUNC_NAME, [error debugDescription] );
        DLOGF( @"%s: Caught error, code=%ld", FUNC_NAME, (long) [error code] );

        [self cancelConnectionForDevice:device];
        [self startDiscoveringDevices];
        return;
    }

    if ( service.characteristics == nil || service.characteristics.count < 1 ) {
        DLOGF( @"%s: No discovered characteristics", FUNC_NAME );

        [self cancelConnectionForDevice:device];
        [self startDiscoveringDevices];
        return;
    }

    NSLog( @"%s: Discovered characteristic count=%lu", FUNC_NAME, (unsigned long)service.characteristics.count );
    for ( CBCharacteristic *c in service.characteristics ) {
        DLOGF( @"%s: Discovered characteristic, UUID=%@", FUNC_NAME, [c UUID] );
        DLOGF( @"%s: Discovered characteristic, description=%@", FUNC_NAME, [c description] );
        DLOGF( @"%s: Discovered characteristic, debugDescription=%@", FUNC_NAME, [c debugDescription] );
    }

    DCHECK( [_characteristicUUIDs count] == 1 );
    for ( CBCharacteristic *c in service.characteristics ) {
        if ( [[c UUID] isEqual:[_characteristicUUIDs objectAtIndex:0]] ) {
            DLOGF( @"%s: Found desired characteristic, UUID=%@", FUNC_NAME, [c UUID] );
            DLOGF( @"%s: Subscribing to the characteristic.", FUNC_NAME );

            if ( c.properties & CBCharacteristicPropertyNotify ) {
                [device setCharacteristic:c];
                [peripheral setNotifyValue:YES forCharacteristic:c];
                [_delegate bluetoothCommunicator:self didSubscribeToDevice:device];
            } else {
                DLOGF( @"%s: Characteristic does not contain notify property.", FUNC_NAME );
                [self cancelConnectionForDevice:device];
                [self startDiscoveringDevices];
            }

            break;
        }
    }
}

// https://developer.apple.com/documentation/corebluetooth/cbperipheraldelegate/1518865-peripheral?language=objc
- (void)peripheral:(CBPeripheral *)peripheral didModifyServices:(NSArray<CBService *> *)invalidatedServices {
    DLOGF( @"%s", FUNC_NAME );

    if ( peripheral == nil ) {
        DLOGF( @"%s: peripheral is not available, peripheral is skipped.", FUNC_NAME );
        return;
    }

    BluetoothCommunicatorDevice *device = [_connectedDevices objectForKey:peripheral];
    if ( device == nil || ( [device peripheral] != peripheral ) ) {
        DLOGF( @"%s: Caught unexpected peripheral.", FUNC_NAME );
        return;
    }
    
    if (invalidatedServices == nil) {
        DLOGF( @"%s: Caught null invalidated services.", FUNC_NAME );
        [self cancelConnectionForDevice:device];
    } else if (device.service && [invalidatedServices containsObject:device.service]) {
        DLOGF( @"%s: Invalidated services collecton contains connected service, cancelling peripheral connection.", FUNC_NAME );
        [self cancelConnectionForDevice:device];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    DLOGF( @"%s", FUNC_NAME );

    if ( peripheral == nil ) {
        DLOGF( @"%s: peripheral is not available, peripheral is skipped.", FUNC_NAME );
        return;
    }

    DLOGF( @"%s: peripheral=%@, UUID=%@, name=%@", FUNC_NAME, peripheral, peripheral.identifier, peripheral.name );

    BluetoothCommunicatorDevice *device = [_connectedDevices objectForKey:peripheral];
    if ( device == nil || ( [device peripheral] != peripheral ) ) {
        DLOGF( @"%s: Caught unexpected peripheral.", FUNC_NAME );
        return;
    }

    if ( error ) {
        DLOGF( @"%s: Caught error, code=%ld", FUNC_NAME, (long) [error code] );
        DLOGF( @"%s: Caught error, description=%@", FUNC_NAME, [error description] );
        DLOGF( @"%s: Caught error, debugDescription=%@", FUNC_NAME, [error debugDescription] );

        [self cancelConnectionForDevice:device];
        [self startDiscoveringDevices];
        return;
    }

    if ( peripheral.services == nil || peripheral.services.count < 1 ) {
        DLOGF( @"%s: No discovered services", FUNC_NAME );

        [self cancelConnectionForDevice:device];
        [self startDiscoveringDevices];
        return;
    }

    DLOGF( @"%s: Discovered service count=%lu", FUNC_NAME, (unsigned long)peripheral.services.count );
    for ( CBService *discoveredService in peripheral.services ) {
        DLOGF( @"%s: Discovered service, UUID=%@", FUNC_NAME, [discoveredService UUID] );
        DLOGF( @"%s: Discovered service, description=%@", FUNC_NAME, [discoveredService description] );
        DLOGF( @"%s: Discovered service, debugDescription=%@", FUNC_NAME, [discoveredService debugDescription] );
    }

    DCHECK( [_serviceUUIDs count] == 1 );
    for ( CBService *discoveredService in peripheral.services ) {
        if ( [[discoveredService UUID] isEqual:[_serviceUUIDs objectAtIndex:0]] ) {
            DLOGF( @"%s: Found desired service, UUID=%@", FUNC_NAME, [discoveredService UUID] );
            DLOGF( @"%s: Discovering service characteristics.", FUNC_NAME );

            [device setService:discoveredService];
            [peripheral discoverCharacteristics:_characteristicUUIDs forService:discoveredService];
            break;
        }
    }
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error {
    DLOGF( @"%s", FUNC_NAME );

    if ( central == nil ) {
        DLOGF( @"%s: central is not available, peripheral is skipped.", FUNC_NAME );
        return;
    }

    if ( peripheral == nil ) {
        DLOGF( @"%s: peripheral is not available, peripheral is skipped.", FUNC_NAME );
        return;
    }
    
    // DLOGF( @"%s: central=%@", FUNC_NAME, central );
    // DLOGF( @"%s: _centralManager=%@", FUNC_NAME, _centralManager );
    DLOGF( @"%s: peripheral=%@, UUID=%@, name=%@", FUNC_NAME, peripheral, peripheral.identifier, peripheral.name );

    BluetoothCommunicatorDevice* device = [_connectedDevices objectForKey:peripheral];
    if (device == nil) {
        DLOGF( @"%s: Device was not connected, panic.", FUNC_NAME );
        return;
    }

    [_connectedDevices removeObjectForKey:peripheral];
    [_delegate bluetoothCommunicator:self didDisconnectDevice:device];
    
    NSUInteger statusBits = unsetBit(_statusBits, BTCStatusBitConnected);
    [self setStatusBits:statusBits];
    [self startDiscoveringDevices];
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    DLOGF( @"%s", FUNC_NAME );
    [self stopDiscoveringDevices];

    if ( central == nil ) {
        DLOGF( @"%s: central is not available, peripheral is skipped.", FUNC_NAME );
        return;
    }

    if ( peripheral == nil ) {
        DLOGF( @"%s: peripheral is not available, peripheral is skipped.", FUNC_NAME );
        return;
    }

    // DLOGF( @"%s: central=%@", FUNC_NAME, central );
    // DLOGF( @"%s: _centralManager=%@", FUNC_NAME, _centralManager );
    // DLOGF( @"%s: peripheral=%@, UUID=%@, name=%@", FUNC_NAME, peripheral, peripheral.identifier, peripheral.name );

    NSUInteger withResponse    = [peripheral maximumWriteValueLengthForType:CBCharacteristicWriteWithResponse];
    NSUInteger withoutResponse = [peripheral maximumWriteValueLengthForType:CBCharacteristicWriteWithoutResponse];

    DLOGF( @"%s: maximumWriteValueLength:WithResponse    %u", FUNC_NAME, withResponse );
    DLOGF( @"%s: maximumWriteValueLength:WithoutResponse %u", FUNC_NAME, withoutResponse );

    BluetoothCommunicatorDevice *device = [[BluetoothCommunicatorDevice alloc] init];
    [device setBluetoothCommunicator:self];
    [device setMtu:withResponse];
    [device setMaxWriteLength:withoutResponse];
    [device setMaxWriteLengthWithResponse:withResponse];
    [device setPeripheral:peripheral];
    [device setLocalId:[_connectedDevices count]];
    [device setPendingWriteValue:false];

    [_connectedDevices setObject:device forKey:peripheral];
    // [_connectingDevices removeObject:peripheral];
    [_delegate bluetoothCommunicator:self didConnectToDevice:device];

    //_currentStatusBits = unsetBit(_currentStatusBits, BTCStatusBitConnecting);
    //_currentStatusBits = setBit(_currentStatusBits, BTCStatusBitConnected);
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
    
    NSUInteger statusBits = unsetBit(_statusBits, BTCStatusBitConnecting);
    statusBits = unsetBit(statusBits, BTCStatusBitScanning);
    statusBits = setBit(statusBits, BTCStatusBitConnected);
    [self setStatusBits:statusBits];
}

- (void)centralManager:(CBCentralManager *)central
    didFailToConnectPeripheral:(CBPeripheral *)peripheral
                         error:(NSError *)error {
    DLOGF( @"%s", FUNC_NAME );
    DLOGF( @"%s: central=%@", FUNC_NAME, central );
    // DLOGF( @"%s: _centralManager=%@", FUNC_NAME, _centralManager );
    DLOGF( @"%s: peripheral=%@, UUID=%@, name=%@", FUNC_NAME, peripheral, peripheral.identifier, peripheral.name );
    DLOGF( @"%s: error=%@", FUNC_NAME, error );
}

- (void)centralManager:(CBCentralManager *)central
    didDiscoverPeripheral:(CBPeripheral *)peripheral
        advertisementData:(NSDictionary *)advertisementData
                     RSSI:(NSNumber *)rssi {
    DLOGF( @"%s", FUNC_NAME );
    DLOGF( @"%s: central=%@", FUNC_NAME, central );
    // DLOGF( @"%s: _centralManager=%@", FUNC_NAME, _centralManager );
    DLOGF( @"%s: peripheral=%@, UUID=%@, name=%@", FUNC_NAME, peripheral, peripheral.identifier, peripheral.name );
    // DLOGF( @"%s: advertisementData=%@", FUNC_NAME, advertisementData );
    // DLOGF( @"%s: rssi=%@", FUNC_NAME, rssi );

    if ( advertisementData == nil || [advertisementData count] == 0 ) {
        DLOGF( @"%s: Advertisement data is either nil or empty, peripheral is skipped.", FUNC_NAME );
        return;
    }

    NSArray *advertisedServiceUUIDs = [advertisementData objectForKey:CBAdvertisementDataServiceUUIDsKey];
    if ( advertisedServiceUUIDs == nil || [advertisedServiceUUIDs count] == 0 ) {
        DLOGF( @"%s: No advertised services, peripheral is skipped.", FUNC_NAME );
        return;
    }

    NSString *peripheralLocalName = [advertisementData objectForKey:CBAdvertisementDataLocalNameKey];
    if ( peripheralLocalName != nil ) {
        DLOGF( @"%s: Found peripheral name key, name=%@.", FUNC_NAME, peripheralLocalName );
    }

    for ( CBUUID *advertisedServiceUUID in advertisedServiceUUIDs ) {
        if ( [_serviceUUIDs containsObject:advertisedServiceUUID] ) {
            
            DLOGF( @"%s: Found matching service, UUID=%@.", FUNC_NAME, advertisedServiceUUID );

            if ([_connectingDevices containsObject:peripheral]) {
                DLOGF( @"%s: Already connecting to this peripheral.", FUNC_NAME );
                continue;
            }
            if ([_connectedDevices objectForKey:peripheral] != nil) {
                DLOGF( @"%s: Already connected to this peripheral.", FUNC_NAME );
                continue;
            }
            if (!atomic_load(&_scanningFlag)) {
                DLOGF( @"%s: Scanning has been stopped.", FUNC_NAME );
                break;
            }
            
            DLOGF( @"%s: Connecting to the peripheral.", FUNC_NAME );
            
            const bool notEmpty = [_connectedDevices count] > 0 || [_connectingDevices count] > 0;
            (void)notEmpty;

            [_connectingDevices addObject:peripheral];
            [_centralManager connectPeripheral:peripheral options:nil];
            
            NSUInteger statusBits = setBit(_statusBits, BTCStatusBitConnecting);
            [self setStatusBits:statusBits];
            break;
        }
    }
}

- (NSArray *)connectedDevices {
    DLOGF( @"%s", FUNC_NAME );
    return [_connectedDevices allValues];
}

- (void)bluetoothCommunicatorDeviceDidUpdateProperty:(BluetoothCommunicatorDevice *)device {
    [_delegate bluetoothCommunicator:self didUpdateDevice:device];
}

- (bool)schedulerScheduleMessageFrom:(BluetoothCommunicatorDevice*)bluetoothCommunicatorDevice wholeMessageData:(NSData*)wholeMessageData {
    return [_scheduler scheduleMessageFrom:bluetoothCommunicatorDevice wholeMessageData:wholeMessageData];
}

- (bool)schedulerScheduleMessageTo:(BluetoothCommunicatorDevice*)bluetoothCommunicatorDevice wholeMessageData:(NSData*)wholeMessageData {
    return [_scheduler scheduleMessageTo:bluetoothCommunicatorDevice wholeMessageData:wholeMessageData];
}

- (bool)writeValue:(NSData *)value toDevice:(BluetoothCommunicatorDevice *)device {
    DLOGF( @"%s", FUNC_NAME );

    if ( !value || !device ) {
        DLOGF( @"%s: value or device are nulls, write is skipped.", FUNC_NAME );
        return false;
    }
    if ( [device pendingWriteValue] ) {
        DLOGF( @"%s: Cannot write with pending response, write is skipped.", FUNC_NAME );
        return false;
    }

    CBPeripheral * peripheral = [device peripheral];
    CBCharacteristic *characteristic = [device characteristic];

    if ( !peripheral || !characteristic ) {
        DLOGF( @"%s: peripheral or characteristic are nulls, write is skipped.", FUNC_NAME );
        return false;
    }

    // [device setPendingWriteValue:true];
    [peripheral writeValue:value forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
    return true;
}

- (void)peripheral:(CBPeripheral *)peripheral
    didWriteValueForCharacteristic:(CBCharacteristic *)characteristic
                             error:(nullable NSError *)error {
    DLOGF( @"%s", FUNC_NAME );

    BluetoothCommunicatorDevice *device = [_connectedDevices objectForKey:peripheral];
    if ( device == nil || ( [device peripheral] != peripheral ) || ( [device characteristic] != characteristic ) ) {
        DLOGF( @"%s: Caught unexpected peripheral.", FUNC_NAME );
        return;
    }

    // [device setPendingWriteValue:false];

    if ( error ) {
        DLOGF( @"%s: Caught error, description=%@", FUNC_NAME, [error description] );
        DLOGF( @"%s: Caught error, debugDescription=%@", FUNC_NAME, [error debugDescription] );
        DLOGF( @"%s: Caught error, code=%ld", FUNC_NAME, (long) [error code] );

        [_delegate bluetoothCommunicator:self didWriteValueOrError:error toDevice:device];
    } else {
        [_delegate bluetoothCommunicator:self didWriteValueOrError:nil toDevice:device];
    }
}

- (void)setStatusBits:(BTCStatusBits)statusBits {
    if (_statusBits != statusBits) {
        _statusBits = statusBits;
        [_delegate bluetoothCommunicator:self didChangeStatus:statusBits];
    }
}

- (void)stopDiscoveringDevices {
    DLOGF( @"%s", FUNC_NAME );
    
    if (!atomic_exchange(&_scanningFlag, false)) {
        DLOGF( @"%s: Scanning has being stopped.", FUNC_NAME );
        return;
    }
    
    DLOGF( @"%s: Stopping scanning.", FUNC_NAME );
    
    [_connectingDevices removeAllObjects];
    [_centralManager stopScan];
    
    [self setStatusBits:unsetBit(_statusBits, BTCStatusBitScanning)];
}

- (void)startDiscoveringDevices {
    DLOGF( @"%s", FUNC_NAME );

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
    // recommends, but if the application we're scanning for is in the background
    // on the iOS device, then it occassionally will not see any services.
    //
    // So instead, we do the opposite of what Apple recommends and scan
    // with no service UUID restrictions.
    
    if (atomic_exchange(&_scanningFlag, true)) {
        DLOGF( @"%s: Scanning has being started.", FUNC_NAME );
        return;
    }

    NSDictionary *scanningOptions = @{CBCentralManagerScanOptionAllowDuplicatesKey : @YES};

    // TODO: createOrClear().
    if ( _connectedDevices == nil ) {
        _connectedDevices = [[NSMutableDictionary alloc] init];
        _connectingDevices = [[NSMutableSet alloc] init];
        DLOGF( @"%s: Created peripheral list.", FUNC_NAME );
        DLOGF( @"%s: _connectedPeriperals=%@", FUNC_NAME, _connectedDevices );
    } else {
        DLOGF( @"%s: Clearing peripheral list.", FUNC_NAME );
        [_connectedDevices removeAllObjects];
        [_connectingDevices removeAllObjects];
    }

    DLOGF( @"%s: Starting discovering peripherals.", FUNC_NAME );

    NSArray *serviceUUIDs = nil; // _serviceUUIDs
    
    
    atomic_store(&_scanningFlag, true);
    [_centralManager scanForPeripheralsWithServices:serviceUUIDs options:scanningOptions];
    
    [self setStatusBits:setBit(_statusBits, BTCStatusBitScanning)];
}

- (void)centralManagerDidUpdateState:(nonnull CBCentralManager *)central {
    DCHECK( central );
    switch ( central.state ) {
        case CBCentralManagerStatePoweredOn: {
                DCHECK( _centralManager == central );
                DLOGF( @"%s: Caught CBCentralManagerStatePoweredOn.", FUNC_NAME );
                NSUInteger statusBits = unsetBit(_statusBits, BTCStatusBitWaitingForUserInput);
                statusBits = unsetBit(statusBits, BTCStatusBitWaitingForSystem);
                statusBits = unsetBit(statusBits, BTCStatusBitStartingCentral);
                statusBits = setBit(statusBits, BTCStatusBitCentral);
                [self setStatusBits:statusBits];
            } break;

        case CBCentralManagerStateUnknown:
            DLOGF( @"%s: Caught CBCentralManagerStateUnknown. Waiting for an update.", FUNC_NAME );
            [self setStatusBits:setBit(_statusBits, BTCStatusBitWaitingForSystem)];
            break;
        case CBCentralManagerStateResetting:
            DLOGF( @"%s: Caught CBCentralManagerStateResetting. Waiting for an update.", FUNC_NAME );
            [self setStatusBits:setBit(_statusBits, BTCStatusBitWaitingForSystem)];
            break;

        case CBCentralManagerStatePoweredOff: {
                DLOGF( @"%s: Caught CBCentralManagerStatePoweredOff state.", FUNC_NAME );
                NSUInteger statusBits = unsetBit(_statusBits, BTCStatusBitStartingCentral);
                statusBits = unsetBit(statusBits, BTCStatusBitStartingPeripheral);
                statusBits = setBit(statusBits, BTCStatusBitWaitingForUserInput);
                [self setStatusBits:statusBits];
            } break;
        case CBCentralManagerStateUnauthorized:
            DLOGF( @"%s: Caught CBCentralManagerStateUnauthorized state.", FUNC_NAME );
            [self setStatusBits:setBit(_statusBits, BTCStatusBitWaitingForUserInput)];
            break;

        case CBCentralManagerStateUnsupported:
            DLOGF( @"%s: Caught CBCentralManagerStateUnsupported state.", FUNC_NAME );
            [self setStatusBits:BTCStatusBitUnsupported];
            break;

        default:
            DLOGF( @"%s: Error, unexpected state %li.", FUNC_NAME, (long) central.state );
            [self setStatusBits:BTCStatusBitPanic];
            break;
    }
}

+ (NSString *)createModelFriendlyName {
    NSString* model = [BluetoothCommunicator createModelName];

    if ([model compare:@"iPhone3,1"] == kCFCompareEqualTo) return @"iPhone 4";
    if ([model compare:@"iPhone3,2"] == kCFCompareEqualTo) return @"iPhone 4";
    if ([model compare:@"iPhone3,3"] == kCFCompareEqualTo) return @"iPhone 4";
    if ([model compare:@"iPhone4,1"] == kCFCompareEqualTo) return @"iPhone 4s";
    if ([model compare:@"iPhone5,1"] == kCFCompareEqualTo) return @"iPhone 5";
    if ([model compare:@"iPhone5,2"] == kCFCompareEqualTo) return @"iPhone 5";
    if ([model compare:@"iPhone5,3"] == kCFCompareEqualTo) return @"iPhone 5c";
    if ([model compare:@"iPhone5,4"] == kCFCompareEqualTo) return @"iPhone 5c";
    if ([model compare:@"iPhone6,1"] == kCFCompareEqualTo) return @"iPhone 5s";
    if ([model compare:@"iPhone6,2"] == kCFCompareEqualTo) return @"iPhone 5s";
    if ([model compare:@"iPhone7,2"] == kCFCompareEqualTo) return @"iPhone 6";
    if ([model compare:@"iPhone7,1"] == kCFCompareEqualTo) return @"iPhone 6 Plus";
    if ([model compare:@"iPhone8,1"] == kCFCompareEqualTo) return @"iPhone 6s";
    if ([model compare:@"iPhone8,2"] == kCFCompareEqualTo) return @"iPhone 6s Plus";
    if ([model compare:@"iPhone9,1"] == kCFCompareEqualTo) return @"iPhone 7";
    if ([model compare:@"iPhone9,3"] == kCFCompareEqualTo) return @"iPhone 7";
    if ([model compare:@"iPhone9,2"] == kCFCompareEqualTo) return @"iPhone 7 Plus";
    if ([model compare:@"iPhone9,4"] == kCFCompareEqualTo) return @"iPhone 7 Plus";
    if ([model compare:@"iPhone8,4"] == kCFCompareEqualTo) return @"iPhone SE";
    if ([model compare:@"iPhone10,1"] == kCFCompareEqualTo) return @"iPhone 8";
    if ([model compare:@"iPhone10,4"] == kCFCompareEqualTo) return @"iPhone 8";
    if ([model compare:@"iPhone10,2"] == kCFCompareEqualTo) return @"iPhone 8 Plus";
    if ([model compare:@"iPhone10,5"] == kCFCompareEqualTo) return @"iPhone 8 Plus";
    if ([model compare:@"iPhone10,3"] == kCFCompareEqualTo) return @"iPhone X";
    if ([model compare:@"iPhone10,6"] == kCFCompareEqualTo) return @"iPhone X";
    if ([model compare:@"iPhone11,2"] == kCFCompareEqualTo) return @"iPhone XS";
    if ([model compare:@"iPhone11,4"] == kCFCompareEqualTo) return @"iPhone XS Max";
    if ([model compare:@"iPhone11,6"] == kCFCompareEqualTo) return @"iPhone XS Max";
    if ([model compare:@"iPhone11,8"] == kCFCompareEqualTo) return @"iPhone XR";

    if ([model compare:@"iPad2,1"] == kCFCompareEqualTo) return @"iPad 2";
    if ([model compare:@"iPad2,2"] == kCFCompareEqualTo) return @"iPad 2";
    if ([model compare:@"iPad2,3"] == kCFCompareEqualTo) return @"iPad 2";
    if ([model compare:@"iPad2,4"] == kCFCompareEqualTo) return @"iPad 2";
    if ([model compare:@"iPad3,1"] == kCFCompareEqualTo) return @"iPad 3";
    if ([model compare:@"iPad3,2"] == kCFCompareEqualTo) return @"iPad 3";
    if ([model compare:@"iPad3,3"] == kCFCompareEqualTo) return @"iPad 3";
    if ([model compare:@"iPad3,4"] == kCFCompareEqualTo) return @"iPad 4";
    if ([model compare:@"iPad3,5"] == kCFCompareEqualTo) return @"iPad 4";
    if ([model compare:@"iPad3,6"] == kCFCompareEqualTo) return @"iPad 4";
    if ([model compare:@"iPad4,1"] == kCFCompareEqualTo) return @"iPad Air";
    if ([model compare:@"iPad4,2"] == kCFCompareEqualTo) return @"iPad Air";
    if ([model compare:@"iPad4,3"] == kCFCompareEqualTo) return @"iPad Air";
    if ([model compare:@"iPad5,3"] == kCFCompareEqualTo) return @"iPad Air 2";
    if ([model compare:@"iPad5,4"] == kCFCompareEqualTo) return @"iPad Air 2";
    if ([model compare:@"iPad6,11"] == kCFCompareEqualTo) return @"iPad 5";
    if ([model compare:@"iPad6,12"] == kCFCompareEqualTo) return @"iPad 5";
    if ([model compare:@"iPad7,5"] == kCFCompareEqualTo) return @"iPad 6";
    if ([model compare:@"iPad7,6"] == kCFCompareEqualTo) return @"iPad 6";
    if ([model compare:@"iPad2,5"] == kCFCompareEqualTo) return @"iPad Mini";
    if ([model compare:@"iPad2,6"] == kCFCompareEqualTo) return @"iPad Mini";
    if ([model compare:@"iPad2,7"] == kCFCompareEqualTo) return @"iPad Mini";
    if ([model compare:@"iPad4,4"] == kCFCompareEqualTo) return @"iPad Mini 2";
    if ([model compare:@"iPad4,5"] == kCFCompareEqualTo) return @"iPad Mini 2";
    if ([model compare:@"iPad4,6"] == kCFCompareEqualTo) return @"iPad Mini 2";
    if ([model compare:@"iPad4,7"] == kCFCompareEqualTo) return @"iPad Mini 3";
    if ([model compare:@"iPad4,8"] == kCFCompareEqualTo) return @"iPad Mini 3";
    if ([model compare:@"iPad4,9"] == kCFCompareEqualTo) return @"iPad Mini 3";
    if ([model compare:@"iPad5,1"] == kCFCompareEqualTo) return @"iPad Mini 4";
    if ([model compare:@"iPad5,2"] == kCFCompareEqualTo) return @"iPad Mini 4";
    if ([model compare:@"iPad6,3"] == kCFCompareEqualTo) return @"iPad Pro (9.7-inch)";
    if ([model compare:@"iPad6,4"] == kCFCompareEqualTo) return @"iPad Pro (9.7-inch)";
    if ([model compare:@"iPad6,7"] == kCFCompareEqualTo) return @"iPad Pro (12.9-inch)";
    if ([model compare:@"iPad6,8"] == kCFCompareEqualTo) return @"iPad Pro (12.9-inch)";
    if ([model compare:@"iPad7,1"] == kCFCompareEqualTo) return @"iPad Pro (12.9-inch) (2nd generation)";
    if ([model compare:@"iPad7,2"] == kCFCompareEqualTo) return @"iPad Pro (12.9-inch) (2nd generation)";
    if ([model compare:@"iPad7,3"] == kCFCompareEqualTo) return @"iPad Pro (10.5-inch)";
    if ([model compare:@"iPad7,4"] == kCFCompareEqualTo) return @"iPad Pro (10.5-inch)";
    if ([model compare:@"iPad8,1"] == kCFCompareEqualTo) return @"iPad Pro (11-inch)";
    if ([model compare:@"iPad8,2"] == kCFCompareEqualTo) return @"iPad Pro (11-inch)";
    if ([model compare:@"iPad8,3"] == kCFCompareEqualTo) return @"iPad Pro (11-inch)";
    if ([model compare:@"iPad8,4"] == kCFCompareEqualTo) return @"iPad Pro (11-inch)";
    if ([model compare:@"iPad8,5"] == kCFCompareEqualTo) return @"iPad Pro (12.9-inch) (3rd generation)";
    if ([model compare:@"iPad8,6"] == kCFCompareEqualTo) return @"iPad Pro (12.9-inch) (3rd generation)";
    if ([model compare:@"iPad8,7"] == kCFCompareEqualTo) return @"iPad Pro (12.9-inch) (3rd generation)";
    if ([model compare:@"iPad8,8"] == kCFCompareEqualTo) return @"iPad Pro (12.9-inch) (3rd generation)";

    if ([model compare:@"iPod5,1"] == kCFCompareEqualTo) return @"iPod Touch 5";
    if ([model compare:@"iPod7,1"] == kCFCompareEqualTo) return @"iPod Touch 6";

    if ([model compare:@"AppleTV5,3"] == kCFCompareEqualTo) return @"Apple TV";
    if ([model compare:@"AppleTV6,2"] == kCFCompareEqualTo) return @"Apple TV 4K";

    if ([model compare:@"AudioAccessory1,1"] == kCFCompareEqualTo) return @"HomePod";

    if ([model compare:@"i386"] == kCFCompareEqualTo) return @"Simulator";
    if ([model compare:@"x86_64"] == kCFCompareEqualTo) return @"Simulator";
    
    if ([model compare:@"iPhone" options:NSCaseInsensitiveSearch range:NSMakeRange(0, 6)] == kCFCompareEqualTo) return @"iPhone";
    if ([model compare:@"iPad" options:NSCaseInsensitiveSearch range:NSMakeRange(0, 4)] == kCFCompareEqualTo) return @"iPad";
    if ([model compare:@"iPod" options:NSCaseInsensitiveSearch range:NSMakeRange(0, 4)] == kCFCompareEqualTo) return @"iPod";
    if ([model compare:@"AppleTV" options:NSCaseInsensitiveSearch range:NSMakeRange(0, 7)] == kCFCompareEqualTo) return @"AppleTV";
    if ([model compare:@"AudioAccessory" options:NSCaseInsensitiveSearch range:NSMakeRange(0, 14)] == kCFCompareEqualTo) return @"HomePod";

    return model;
}

@end

@implementation BluetoothCommunicatorLongMessage {
    NSUInteger _responseMessageType;
    NSUInteger _messageType;
    NSUInteger _messageContentsLength;
    NSMutableData* _messageContents;
    NSUInteger _messageContentsOffset;
}

- (NSUInteger)getMessageType { return _messageType; }
- (NSUInteger)getResponseMessageType { return _responseMessageType; }
- (NSUInteger)getMessageContentsOffset { return _messageContentsOffset; }
- (NSUInteger)getMessageContentsLength { return _messageContentsLength; }

- (NSData*)getMessageContents {
    return _messageContents;
}

- (instancetype)initWithMessageData:(NSData*)messageData {
    [self start:messageData];
    return self;
}
- (void)start:(NSData *)wholeMessageData {
    DCHECK([self isEmpty]);
    _responseMessageType = [BluetoothCommunicatorMessage getResponseMessageType:wholeMessageData];
    _messageType = [BluetoothCommunicatorMessage getMessageType:wholeMessageData];
    _messageContentsLength = [BluetoothCommunicatorMessage getMessageContentsByteLength:wholeMessageData];
    _messageContents = [[NSMutableData alloc] initWithCapacity:_messageContentsLength];
    _messageContentsOffset = 0;
    
    const NSUInteger contentsLength = wholeMessageData.length - BTCLongMessageStartByteIndex;
    if (contentsLength) {
        const uint8_t* contentsPtr = (const uint8_t*)[wholeMessageData bytes] + BTCLongMessageStartByteIndex;
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
    [_messageContents appendData:wholeMessageData];
    _messageContentsOffset += wholeMessageData.length;
    return [self isComplete];
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

@implementation BluetoothCommunicatorMessage
+ (NSUInteger)getMessageType:(NSData*)wholeMessageBytes {
    const uint8_t decoratedMessageType = ((const uint8_t*)[wholeMessageBytes bytes])[BTCMessageTypeByteIndex];
    return (NSUInteger) decoratedMessageType;
}
+ (NSUInteger)getResponseMessageType:(NSData*)wholeMessageBytes {
    const uint8_t decoratedMessageType = ((const uint8_t*)[wholeMessageBytes bytes])[BTCResponseMessageTypeByteIndex];
    return (NSUInteger) decoratedMessageType;
}
+ (bool)isShortMessage:(NSUInteger)decoratedMessageType {
    return isBitSet(decoratedMessageType, BTCMessageShortBit);
}
+ (bool)isEncryptedMessage:(NSUInteger)decoratedMessageType {
    return isBitSet(decoratedMessageType, BTCMessageEncryptedBit);
}
+ (NSUInteger)undecorateMessageType:(NSUInteger)decoratedMessageType {
    decoratedMessageType = unsetBit(decoratedMessageType, BTCMessageShortBit);
    decoratedMessageType = unsetBit(decoratedMessageType, BTCMessageEncryptedBit);
    return decoratedMessageType;
}
+ (NSUInteger)shortMessageType:(NSUInteger)decoratedMessageType {
    decoratedMessageType = setBit(decoratedMessageType, BTCMessageShortBit);
    return decoratedMessageType;
}
+ (NSUInteger)longMessageType:(NSUInteger)decoratedMessageType {
    decoratedMessageType = unsetBit(decoratedMessageType, BTCMessageShortBit);
    return decoratedMessageType;
}
+ (NSUInteger)getMessageContentsByteLength:(NSData*)wholeMessageData {
    DCHECK(wholeMessageData != nil && [wholeMessageData length] > BTCMessageLength3ByteIndex);
    NSRange lengthRange = NSMakeRange(BTCMessageLength0ByteIndex, BTCMessageLengthIntegerByteLength);
    TKSubdata* lengthSubdata = [[TKSubdata alloc] initWithData:wholeMessageData range:lengthRange];
    return [self bytesToInt:lengthSubdata];
    // return [self bytesToInt:[NSDataNoCopyUtilities subdataNoCopy:wholeMessageData range:lengthRange]];
}

//
// NSUInteger
//

+ (void)intToBytes:(NSUInteger)integer writeTo:(NSMutableData*)mutableSubdata {
    DCHECK(integer <= 4294967295);
    DCHECK(mutableSubdata != nil);
    DCHECK([mutableSubdata length] >= BTCMessageLengthIntegerByteLength);
    
    uint8_t* ptr = (uint8_t*)[mutableSubdata bytes];
    ptr[0] = (uint8_t)(integer & 0xff);
    ptr[1] = (uint8_t)((integer >> 8) & 0xff);
    ptr[2] = (uint8_t)((integer >> 16) & 0xff);
    ptr[3] = (uint8_t)((integer >> 24) & 0xff);
}
+ (NSData*)intToBytes:(NSUInteger)integer {
    NSMutableData* intBytes = [[NSMutableData alloc] initWithLength:BTCMessageLengthIntegerByteLength];
    TKMutableSubdata* subdata = [[TKMutableSubdata alloc] initWithMutableData:intBytes];
    [self intToBytes:integer writeTo:subdata];
    return intBytes;
}
+ (NSUInteger)bytesToInt:(TKSubdata*)subdata {
    DCHECK(subdata != nil && [subdata length] >= BTCMessageLengthIntegerByteLength);
    
    const uint8_t* rawPtr = [subdata bytes];
    NSUInteger integer = (NSUInteger)rawPtr[0];
    integer |= ((NSUInteger)(rawPtr[1])) << 8;
    integer |= ((NSUInteger)(rawPtr[2])) << 16;
    integer |= ((NSUInteger)(rawPtr[3])) << 24;
    return integer;
}

//
// NSUUID
//

+ (NSData*)uuidToBytes:(NSUUID*)UUID {
    NSMutableData* uuidBytes = [[NSMutableData alloc] initWithLength:BTCUUIDByteLength];
    TKMutableSubdata* uuidSubdata = [[TKMutableSubdata alloc] initWithMutableData:uuidBytes];
    [self uuidToBytes:UUID writeTo:uuidSubdata];
    return uuidBytes;
}

+ (void)uuidToBytes:(NSUUID*)UUID writeTo:(NSMutableData*)mutableSubdata {
    return [UUID getUUIDBytes:(uint8_t*)[mutableSubdata bytes]];
}

+ (NSUUID*)bytesToUUID:(NSData*)subdata {
    const uint8_t* rawPtr = (const uint8_t*)[subdata bytes];
    return [[NSUUID alloc] initWithUUIDBytes:rawPtr];
}

+ (bool)requiresResponse:(NSData*)wholeMessageData {
    const uint8_t* rawPtr = (const uint8_t*)[wholeMessageData bytes];
    NSUInteger responseMessageType = rawPtr[BTCResponseMessageTypeByteIndex];
    return responseMessageType != BTCMessageTypeFinish;
}
@end

//@implementation NSDataNoCopyUtilities
//+ (NSData*)subdataNoCopy:(NSData*)data range:(NSRange)range {
//    DCHECK(data != nil && [data length] >= (range.location + range.length));
//    uint8_t* rawPtr = ((uint8_t*)[data bytes]) + range.location;
//    return [NSData dataWithBytesNoCopy:rawPtr length:range.length];
//}
//+ (NSMutableData*)mutableSubdataNoCopy:(NSMutableData*)data range:(NSRange)range {
//    DCHECK(data != nil && [data length] >= (range.location + range.length));
//    uint8_t* rawPtr = ((uint8_t*)[data bytes]) + range.location;
//    return [NSMutableData dataWithBytesNoCopy:rawPtr length:range.length];
//}
//@end

@implementation NSStringUtilities
static NSString* emptyStringInstance = @"";
+ (NSString*)empty { DCHECK(emptyStringInstance && [emptyStringInstance length] == 0); return emptyStringInstance; }
+ (bool)isNilOrEmpty:(NSString*)string { return !string || (0 == [string length]); }

+ (NSString*)stringOrEmptyString:(NSString*)nullableString {
    if (nullableString == nil) { return [NSStringUtilities empty]; }
    return nullableString;
}

+ (NSString*)uuidStringOrEmptyString:(NSUUID*)nullableUUID {
    if (nullableUUID == nil) { return [NSStringUtilities empty]; }
    return [nullableUUID UUIDString];
}
@end

@implementation TKSubdata {
    NSData* _data;
    NSRange _range;
}
- (instancetype)initWithData:(NSData*)data {
    return [self initWithData:data range:NSMakeRange(0, [data length])];
}
- (instancetype)initWithData:(NSData*)data range:(NSRange)range {
    DCHECK(data);
    DCHECK(range.location < [data length]);
    DCHECK((range.location + range.length) <= [data length]);
    
    _data = data;
    _range = range;
    return self;
}
- (const uint8_t*)bytes { return (const uint8_t*)[_data bytes] + _range.location; }
- (NSUInteger)length { return _range.length; }
@end

@implementation TKMutableSubdata {
    NSMutableData* _data;
    NSRange _range;
}
- (instancetype)initWithMutableData:(NSMutableData*)data {
    return [self initWithMutableData:data range:NSMakeRange(0, [data length])];
}
- (instancetype)initWithMutableData:(NSMutableData*)data range:(NSRange)range {
    DCHECK(data);
    DCHECK(range.location < [data length]);
    DCHECK((range.location + range.length) <= [data length]);
    
    _data = data;
    _range = range;
    return self;
}
- (uint8_t*)bytes { return (uint8_t*)[_data bytes] + _range.location; }
- (NSUInteger)length { return _range.length; }
@end

@implementation BluetoothCommunicatorEncoder {
    BluetoothCommunicator* _bluetoothCommunicator;
}
- (BluetoothCommunicator*)bluetoothCommunicator { return _bluetoothCommunicator; }
- (instancetype)initWithBluetoothCommunicator:(BluetoothCommunicator*)bluetoothCommunicator {
    DCHECK(bluetoothCommunicator != nil);
    _bluetoothCommunicator = bluetoothCommunicator;
    return self;
}

- (NSData*)encodeShortMessage:(NSData*)data messageType:(NSUInteger)messageType responseMessageType:(NSUInteger)responseMessageType {
    const NSUInteger dataLength = data != nil ? [data length] : 0;
    const uint8_t* dataBytes = data != nil ? (const uint8_t*)[data bytes] : NULL;
    
    const NSUInteger mutableDataLength = dataLength + BTCShortMessageStartByteIndex;
    NSMutableData* mutableData = [[NSMutableData alloc] initWithLength:mutableDataLength];
    uint8_t* messageBytes = (uint8_t*)[mutableData mutableBytes];
    
    messageBytes[BTCResponseMessageTypeByteIndex] = responseMessageType;
    messageBytes[BTCMessageTypeByteIndex] = [BluetoothCommunicatorMessage shortMessageType:messageType];

    for (NSUInteger i = 0; i < dataLength; ++i) {
        messageBytes[BTCShortMessageStartByteIndex + i] = dataBytes[i];
    }

    return mutableData;
}
- (NSData*)encodeLongMessage:(NSData*)data messageType:(NSUInteger)messageType responseMessageType:(NSUInteger)responseMessageType {
    const NSUInteger dataLength = [data length];
    const uint8_t* dataBytes = (const uint8_t*)[data bytes];
    
    const NSUInteger mutableDataLength = dataLength + BTCLongMessageStartByteIndex;
    NSMutableData* mutableData = [[NSMutableData alloc] initWithLength:mutableDataLength];
    
    uint8_t* messageBytes = (uint8_t*)[mutableData mutableBytes];
    messageBytes[BTCResponseMessageTypeByteIndex] = responseMessageType;
    messageBytes[BTCMessageTypeByteIndex] = [BluetoothCommunicatorMessage longMessageType:messageType];
    
    NSRange lengthRange = NSMakeRange(BTCMessageLength0ByteIndex, BTCMessageLengthIntegerByteLength);
    TKMutableSubdata* lengthMutableSubdata = [[TKMutableSubdata alloc] initWithMutableData:mutableData range:lengthRange];
    // NSMutableData* lengthMutableData = [NSDataNoCopyUtilities mutableSubdataNoCopy:mutableData range:lengthRange];
    [BluetoothCommunicatorMessage intToBytes:[data length] writeTo:lengthMutableSubdata];
    
    for (NSUInteger i = 0; i < dataLength; ++i) {
        messageBytes[BTCLongMessageStartByteIndex + i] = dataBytes[i];
    }

    return mutableData;
}
- (NSData*)encodeMessage:(BluetoothCommunicatorDevice *)device messageContentsData:(NSData*)messageContentsData messageType:(NSUInteger)messageType responseMessageType:(NSUInteger)responseMessageType {
    NSUInteger wholeMessageLength = [messageContentsData length] + BTCShortMessageStartByteIndex;
    return wholeMessageLength > [device mtu] // If it fits, it sits.
        ? [self encodeLongMessage:messageContentsData messageType:messageType responseMessageType:responseMessageType]
        : [self encodeShortMessage:messageContentsData messageType:messageType responseMessageType:responseMessageType];
}

- (NSData*)encodeFileMessage:(BluetoothCommunicatorDevice *)device fileName:(NSString*)fileName fileData:(NSData*)fileData responseMessageType:(NSUInteger)responseMessageType {
    NSData* fileNameData = [fileName dataUsingEncoding:NSUTF8StringEncoding];
    
    const uint8_t stringTermination[] = {0, 0};
    const NSUInteger messageContentsLength = [fileNameData length] + 2 + [fileData length];

    NSMutableData* messageContentsData = [[NSMutableData alloc] initWithCapacity:messageContentsLength];
    [messageContentsData appendData:fileNameData];
    [messageContentsData appendBytes:stringTermination length:sizeof(stringTermination)];
    [messageContentsData appendData:fileData];
    
    return [self encodeMessage:device messageContentsData:messageContentsData messageType:BTCMessageTypeFile responseMessageType:responseMessageType];
}
- (NSData*)encodeConfirmationMessage:(BluetoothCommunicatorDevice *)device responseMessageType:(NSUInteger)responseMessageType {
    return [self encodeMessage:device messageContentsData:nil messageType:BTCMessageTypeConfirm responseMessageType:responseMessageType];
}
- (NSData*)encodeUUIDMessage:(BluetoothCommunicatorDevice *)device responseMessageType:(NSUInteger)responseMessageType {
    NSUUID* property = [_bluetoothCommunicator getUUID];
    return [self encodeMessage:device messageContentsData:[BluetoothCommunicatorMessage uuidToBytes:property] messageType:BTCMessageTypeUUID responseMessageType:responseMessageType];
}
- (NSData*)encodeNameMessage:(BluetoothCommunicatorDevice *)device responseMessageType:(NSUInteger)responseMessageType {
    NSString* property = [_bluetoothCommunicator getName];
    return [self encodeMessage:device messageContentsData:[property dataUsingEncoding:NSUTF8StringEncoding] messageType:BTCMessageTypeName responseMessageType:responseMessageType];
}
- (NSData*)encodeModelMessage:(BluetoothCommunicatorDevice *)device responseMessageType:(NSUInteger)responseMessageType  {
    NSString* property = [_bluetoothCommunicator getModel];
    return [self encodeMessage:device messageContentsData:[property dataUsingEncoding:NSUTF8StringEncoding] messageType:BTCMessageTypeDeviceModel responseMessageType:responseMessageType];
}
- (NSData*)encodeFriendlyModelMessage:(BluetoothCommunicatorDevice *)device responseMessageType:(NSUInteger)responseMessageType {
    NSString* property = [_bluetoothCommunicator getFriendlyModel];
    return [self encodeMessage:device messageContentsData:[property dataUsingEncoding:NSUTF8StringEncoding] messageType:BTCMessageTypeDeviceFriendlyModel responseMessageType:responseMessageType];
}

@end

@implementation BluetoothCommunicatorDecoder {
    BluetoothCommunicator* _bluetoothCommunicator;
}
- (BluetoothCommunicator*)bluetoothCommunicator { return _bluetoothCommunicator; }
- (instancetype)initWithBluetoothCommunicator:(BluetoothCommunicator*)bluetoothCommunicator {
    DCHECK(bluetoothCommunicator != nil);
    _bluetoothCommunicator = bluetoothCommunicator;
    return self;
}

- (void)decodeWholeFileMessageFrom:(BluetoothCommunicatorDevice *)device fileMessageContents:(NSData*)data {
    const uint8_t* rawPtr = (const uint8_t*)[data bytes];
    NSUInteger fileNameLength = 0;
    for (NSUInteger i = 1; i < [data length]; ++i) {
        if (rawPtr[i - 1] == 0 && rawPtr[i] == 0) {
            fileNameLength = i - 1;
            break;
        }
    }
    
    if (fileNameLength == 0) {
        DLOGF(@"%s: Failed to find file name length in the message data, skipping the message.", __PRETTY_FUNCTION__);
        return;
    }

    DLOGF(@"%s: File name length = %u", __PRETTY_FUNCTION__, fileNameLength);
    
    DCHECK([data length] > (fileNameLength + 2));
    if ([data length] <= (fileNameLength + 2)) {
        DLOGF(@"%s: The message data appeared insufficient to store file data, skipping the message.", __PRETTY_FUNCTION__);
        return;
    }

    NSUInteger fileLength = [data length] - fileNameLength - 2;
    DCHECK(fileLength > 0);
    
    NSString* fileName = [[NSString alloc] initWithBytes:rawPtr length:fileNameLength encoding:NSUTF8StringEncoding];
    DCHECK(fileName && [fileName length] > 0);
    
    NSData* fileData = [[NSData alloc] initWithBytes:(rawPtr + fileNameLength + 2) length:fileLength];
    DCHECK(fileData && [fileData length] > 0);
    
    [FileSaver saveFile:fileName fileData:fileData];
}

+ (NSString*)utf8StringInitWithSubdata:(TKSubdata*)subdata {
    NSString* stringProperty = [[NSString alloc] initWithBytes:[subdata bytes] length:[subdata length] encoding:NSUTF8StringEncoding];
    return stringProperty;
}

- (void)decodeWholeMessageFrom:(BluetoothCommunicatorDevice *)device undecoratedMessageType:(NSUInteger)undecoratedMessageType messageContents:(TKSubdata*)messageContents {
    switch (undecoratedMessageType) {
        case BTCMessageTypeFinish: {
            DLOGF(@"%s: Received EOM", __PRETTY_FUNCTION__);
        } break;
        
        case BTCMessageTypeFile: {
            [self decodeWholeFileMessageFrom:device fileMessageContents:messageContents];
        } break;
        
        case BTCMessageTypeUUID: {
            if (nil == [device getUUID]) {
                NSUUID* uuid = [BluetoothCommunicatorMessage bytesToUUID:messageContents];
                [device setUUID:uuid];
                
                DLOGF(@"%s: Assigned UUID: %@", __PRETTY_FUNCTION__, uuid);
            } else {
                DLOGF(@"%s: Skinned UUID, already assigned.", __PRETTY_FUNCTION__);
            }
        } break;
        case BTCMessageTypeName: {
            if ([NSStringUtilities isNilOrEmpty:[device getName]]) {
                NSString* stringProperty = [BluetoothCommunicatorDecoder utf8StringInitWithSubdata:messageContents];
                [device setName:stringProperty];
                
                DLOGF(@"%s: Received name: %@", __PRETTY_FUNCTION__, stringProperty);
            } else {
                DLOGF(@"%s: Skinned name, already assigned.", __PRETTY_FUNCTION__);
            }
        } break;
        case BTCMessageTypeDeviceModel: {
            if ([NSStringUtilities isNilOrEmpty:[device getModel]]) {
                NSString* stringProperty = [BluetoothCommunicatorDecoder utf8StringInitWithSubdata:messageContents];
                [device setModel:stringProperty];
                
                DLOGF(@"%s: Received model: %@", __PRETTY_FUNCTION__, stringProperty);
            } else {
                DLOGF(@"%s: Skinned model name, already assigned.", __PRETTY_FUNCTION__);
            }
        } break;
        case BTCMessageTypeDeviceFriendlyModel: {
            if ([NSStringUtilities isNilOrEmpty:[device getFriendlyModel]]) {
                NSString* stringProperty = [BluetoothCommunicatorDecoder utf8StringInitWithSubdata:messageContents];
                [device setFriendlyModel:stringProperty];
                
                DLOGF(@"%s: Received friendly model: %@", __PRETTY_FUNCTION__, stringProperty);
            } else {
                DLOGF(@"%s: Skinned friendly model name, already assigned.", __PRETTY_FUNCTION__);
            }
        } break;
        
        default: {
            DLOGF(@"%s: Received unexpected message type: %u", __PRETTY_FUNCTION__, undecoratedMessageType);
        } break;
    }
}

- (void)decodeShortMessageFrom:(BluetoothCommunicatorDevice *)device undecoratedMessageType:(NSUInteger)undecoratedMessageType wholeMessageData:(NSData*)wholeMessageData {
    const NSUInteger offset = BTCShortMessageStartByteIndex;
    const NSUInteger length = [wholeMessageData length] - offset;

    NSRange range = NSMakeRange(offset, length);
    TKSubdata* messageContents = [[TKSubdata alloc] initWithData:wholeMessageData range:range];

    [self decodeWholeMessageFrom:device
          undecoratedMessageType:undecoratedMessageType
                 messageContents:messageContents];
}
@end

@implementation BluetoothCommunicatorScheduledOperation {
    NSData* _data;
    bool _requiresResponse;
}

- (NSData*)data { return _data; }
- (bool)requiresResponse { return _requiresResponse; }

- (instancetype)initWithData:(NSData*)data requiresResponse:(bool)requiresResponse {
    _data = data;
    _requiresResponse = requiresResponse;
    return self;
}
@end

@implementation BluetoothCommunicatorScheduler {
    BluetoothCommunicator* _bluetoothCommunicator;
    BluetoothCommunicatorEncoder* _encoder;
    BluetoothCommunicatorDecoder* _decoder;
    dispatch_queue_t _readQueue;
    dispatch_queue_t _writeQueue;
    NSMutableDictionary* _scheduledReads;
    NSMutableDictionary* _scheduledWrites;
    NSMutableDictionary* _longMessages;
}

- (BluetoothCommunicator*)bluetoothCommunicator { return _bluetoothCommunicator; }
- (BluetoothCommunicatorEncoder*)bluetoothCommunicatorEncoder { return _encoder; }
- (BluetoothCommunicatorDecoder*)bluetoothCommunicatorDecoder { return _decoder; }
- (instancetype)initWithBluetoothCommunicator:(BluetoothCommunicator*)bluetoothCommunicator {
    DCHECK(bluetoothCommunicator != nil);
    _bluetoothCommunicator = bluetoothCommunicator;
    _encoder = [[BluetoothCommunicatorEncoder alloc] initWithBluetoothCommunicator:bluetoothCommunicator];
    _decoder = [[BluetoothCommunicatorDecoder alloc] initWithBluetoothCommunicator:bluetoothCommunicator];
    _readQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    _writeQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    _scheduledReads = [[NSMutableDictionary alloc] init];
    _scheduledWrites = [[NSMutableDictionary alloc] init];
    _longMessages = [[NSMutableDictionary alloc] init];
    
    return self;
}

- (NSMutableArray*)nilForEmptyOperations:(NSMutableArray*)operations {
    return operations && [operations count] ? operations : nil;
}

- (NSMutableArray*)synchronizedGetOperations:(BluetoothCommunicatorDevice*)device operationDictionary:(NSMutableDictionary*)operationDictionary {
    if (operationDictionary == nil || device == nil) { return nil; }
    
    NSMutableArray* operations = nil;
    @synchronized (operationDictionary) { operations = [operationDictionary objectForKey:device]; }
    return operations;
}

- (NSMutableArray*)synchronizedGetOrCreateOperations:(BluetoothCommunicatorDevice*)device operationDictionary:(NSMutableDictionary*)operationDictionary {
    if (operationDictionary == nil || device == nil) { return nil; }

    NSMutableArray* operations = [operationDictionary objectForKey:device];
    if (operations == nil) { @synchronized(self) {
        operations = [operationDictionary objectForKey:device];
        if (operations == nil) {
            operations = [[NSMutableArray alloc] init];
            [operationDictionary setObject:operations forKey:device];
        }
    }}
    
    return operations;
}

- (NSMutableArray*)synchronizedGetOperationsOrNil:(BluetoothCommunicatorDevice*)device operationDictionary:(NSMutableDictionary*)operationDictionary {
    return [self nilForEmptyOperations:[self synchronizedGetOperations:device operationDictionary:operationDictionary]];
}

- (BluetoothCommunicatorScheduledOperation*)synchronizedPollFirstOperation:(NSMutableArray*)operations {
    BluetoothCommunicatorScheduledOperation* operation = nil;
    @synchronized (operations) { operation = [operations firstObject]; [operations removeObjectAtIndex:0]; }
    return operation;
}

- (bool)shouldExecuteOperations:(NSMutableDictionary*)operationDictionary {
    NSArray* allKeys = nil;
    @synchronized (operationDictionary) {
        allKeys = [operationDictionary allKeys];
    }
    
    const NSUInteger keyCount = [allKeys count];
    for (NSUInteger i = 0; i < keyCount; ++i) {
        BluetoothCommunicatorDevice* device = [allKeys objectAtIndex:i];
        DCHECK(device != nil);
        if (!device) { continue; }
    
        NSMutableArray* operations = [self synchronizedGetOperationsOrNil:device operationDictionary:operationDictionary];
        if (operations && [operations count]) { return true; }
    }
    
    return false;
}

- (void)executeOperations:(NSMutableDictionary*)operationDictionary operationExecutor:(void (^)(id device, id data))operationExecutor {
    NSArray* allKeys = nil;
    @synchronized (operationDictionary) {
        allKeys = [operationDictionary allKeys];
    }
    
    const NSUInteger keyCount = [allKeys count];
    for (NSUInteger i = 0; i < keyCount; ++i) {
        BluetoothCommunicatorDevice* device = [allKeys objectAtIndex:i];
        DCHECK(device != nil);
        if (!device || [device pendingWriteValue]) { continue; }
        
        NSMutableArray* operations = [self synchronizedGetOperationsOrNil:device operationDictionary:operationDictionary];
        if (!operations) { continue; }
        
        NSUInteger operationCount = 0;
        while ((void)(operationCount = [operations count]), operationCount) {
            BluetoothCommunicatorScheduledOperation* operation = [self synchronizedPollFirstOperation:operations];
            if (!operation) { continue; }
    
            operationExecutor(device, operation);
        }
    }
}

- (NSData*)encodeResponse:(BluetoothCommunicatorDevice*)device messageType:(NSUInteger)messageType {
    NSData* responseData = nil;
    switch (messageType) {
        case BTCMessageTypeUUID: {
            NSUInteger responseMessageType = [device getUUID] ? BTCMessageTypeFinish : BTCMessageTypeUUID;
            responseData = [_encoder encodeUUIDMessage:device responseMessageType:responseMessageType];
        } break;
        case BTCMessageTypeName: {
            bool deviceHasName = ![NSStringUtilities isNilOrEmpty:[device getName]];
            NSUInteger responseMessageType = deviceHasName ? BTCMessageTypeFinish : BTCMessageTypeName;
            responseData = [_encoder encodeNameMessage:device responseMessageType:responseMessageType];
        } break;
        case BTCMessageTypeDeviceModel: {
            bool deviceHasProperty = ![NSStringUtilities isNilOrEmpty:[device getModel]];
            NSUInteger responseMessageType = deviceHasProperty ? BTCMessageTypeFinish : BTCMessageTypeDeviceModel;
            responseData = [_encoder encodeModelMessage:device responseMessageType:responseMessageType];
        } break;
        case BTCMessageTypeDeviceFriendlyModel: {
            bool deviceHasProperty = ![NSStringUtilities isNilOrEmpty:[device getFriendlyModel]];
            NSUInteger responseMessageType = deviceHasProperty ? BTCMessageTypeFinish : BTCMessageTypeDeviceFriendlyModel;
            responseData = [_encoder encodeFriendlyModelMessage:device responseMessageType:responseMessageType];
        } break;
        
        case BTCMessageTypeConfirm:
            responseData = [_encoder encodeConfirmationMessage:device responseMessageType:BTCMessageTypeFinish];
            break;

        case BTCMessageTypeFinish:
        case BTCMessageTypeFile: {
            DLOGF(@"%s: Not responding.", __PRETTY_FUNCTION__);
        } break;

        default: {
            DLOGF(@"%s: Not responding, unknown response type requested.", __PRETTY_FUNCTION__);
        } break;
    }
    
    return responseData;
}

- (void)decodeReceivedMessageAndRespond:(BluetoothCommunicatorDevice*)device receivedMessageData:(NSData*)receivedMessageData {
    NSUInteger responseMessageType = BTCMessageTypeFinish;
    
    BluetoothCommunicatorLongMessage* longMessage = [_longMessages objectForKey:device];
    if (longMessage != nil) {
        DLOGF(@"%s: Resuming the long message.", __PRETTY_FUNCTION__);
        
        if ([longMessage append:receivedMessageData]) {
            DCHECK([longMessage isComplete]);
            DLOGF(@"%s: Completing the long message.", __PRETTY_FUNCTION__);
            
            responseMessageType = [longMessage getResponseMessageType];
        
            const NSUInteger decoratedMessageType = [longMessage getMessageType];
            const NSUInteger undecoratedMessageType = [BluetoothCommunicatorMessage undecorateMessageType:decoratedMessageType];
            NSData* messageContents = [longMessage getMessageContents];
            TKSubdata* messageContentsSubdata = [[TKSubdata alloc] initWithData:messageContents];
            
            [_decoder decodeWholeMessageFrom:device
                      undecoratedMessageType:undecoratedMessageType
                             messageContents:messageContentsSubdata];
            
            [longMessage clear];
            [_longMessages removeObjectForKey:device];
        } else {
            DCHECK(![longMessage isComplete]);
            DLOGF(@"%s: Appending the long message.", __PRETTY_FUNCTION__);
            
            responseMessageType = BTCMessageTypeConfirm;
        }
    } else {
        const NSUInteger decoratedMessageType = [BluetoothCommunicatorMessage getMessageType:receivedMessageData];
        const NSUInteger undecoratedMessageType = [BluetoothCommunicatorMessage undecorateMessageType:decoratedMessageType];
        const bool isMessageShort = [BluetoothCommunicatorMessage isShortMessage:decoratedMessageType];

        if (isMessageShort) {
            DLOGF(@"%s: Sending short message to parser.", __PRETTY_FUNCTION__);
            
            [_decoder decodeShortMessageFrom:device
                      undecoratedMessageType:undecoratedMessageType
                            wholeMessageData:receivedMessageData];

            responseMessageType = [BluetoothCommunicatorMessage getResponseMessageType:receivedMessageData];
        } else {
            DLOGF(@"%s: Starting long message.", __PRETTY_FUNCTION__);
            
            BluetoothCommunicatorLongMessage* longMessage = [[BluetoothCommunicatorLongMessage alloc] initWithMessageData:receivedMessageData];
            [_longMessages setObject:longMessage forKey:device];
            
            responseMessageType = BTCMessageTypeConfirm;
        }
    }
    
    NSData* responseMessageData = [self encodeResponse:device messageType:responseMessageType];
    if (responseMessageData) {
        DLOGF(@"%s: Responding with message type: %u", __PRETTY_FUNCTION__, responseMessageType);
        [self scheduleMessageTo:device wholeMessageData:responseMessageData];
    }
}

- (void)executeReads {
    [self executeOperations:_scheduledReads operationExecutor:^(id deviceId, id operationId) {
        BluetoothCommunicatorDevice* device = deviceId;
        BluetoothCommunicatorScheduledOperation* operation = operationId;
        DCHECK(device && operation);
        
        [device setPendingWriteValue:false];
        [self decodeReceivedMessageAndRespond:device receivedMessageData:[operation data]];
    }];
}

- (void)executeWrites {
    [self executeOperations:_scheduledWrites operationExecutor:^(id deviceId, id operationId) {
        BluetoothCommunicatorDevice* device = deviceId;
        BluetoothCommunicatorScheduledOperation* operation = operationId;
        DCHECK(device && operation);
        
        if ([operation requiresResponse]) { [device setPendingWriteValue:true]; }
        [_bluetoothCommunicator writeValue:[operation data] toDevice:device];
    }];
}

- (void)flush {
    dispatch_async(_readQueue, ^{ [self executeReads]; });
    dispatch_async(_writeQueue, ^{ [self executeWrites]; });
}

- (bool)scheduleMessageFrom:(BluetoothCommunicatorDevice*)device wholeMessageData:(NSData*)wholeMessageData {
    NSMutableArray* mutableArray = [self synchronizedGetOrCreateOperations:device operationDictionary:_scheduledReads];
    if (!mutableArray) {
        assert(false);
        return false;
    }
    
    BluetoothCommunicatorScheduledOperation* op = [[BluetoothCommunicatorScheduledOperation alloc] initWithData:wholeMessageData requiresResponse:true];
    @synchronized(mutableArray) { [mutableArray addObject:op]; }
    [self flush];
    return true;
}

- (bool)scheduleMessageTo:(BluetoothCommunicatorDevice*)device wholeMessageData:(NSData*)wholeMessageData {
    NSMutableArray* mutableArray = [self synchronizedGetOrCreateOperations:device operationDictionary:_scheduledWrites];
    if (!mutableArray) {
        assert(false);
        return false;
    }
    
    if ([device mtu] >= [wholeMessageData length]) {
        bool requiresResponse = [BluetoothCommunicatorMessage requiresResponse:wholeMessageData];
        BluetoothCommunicatorScheduledOperation* op = [[BluetoothCommunicatorScheduledOperation alloc] initWithData:wholeMessageData requiresResponse:requiresResponse];
        @synchronized(mutableArray) { [mutableArray addObject:op]; }
    } else {
        NSUInteger messageChunkFrom = 0;
        while (messageChunkFrom < [wholeMessageData length]) {

            NSUInteger writableLength = [wholeMessageData length] - messageChunkFrom;
            writableLength = MIN([device mtu], writableLength);
            DCHECK(writableLength > 0 && "writableLength > 0");

            NSRange messageChunkRange = NSMakeRange(messageChunkFrom, writableLength);
            NSData* messageChunk = [wholeMessageData subdataWithRange:messageChunkRange];
            messageChunkFrom += writableLength;

            bool requiresResponse = true;
            BluetoothCommunicatorScheduledOperation* op = [[BluetoothCommunicatorScheduledOperation alloc] initWithData:messageChunk requiresResponse:requiresResponse];
            @synchronized(mutableArray) { [mutableArray addObject:op]; }
        }
    }
    
    [self flush];
    return true;
}
@end

@implementation FileSaver
+ (bool)saveFile:(NSString*)fileName fileData:(NSData*)fileData {
    DCHECK(fileName && [fileName length] > 0);
    DCHECK(fileData && [fileData length] > 0);

    NSArray* documentsDirPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    DCHECK(documentsDirPaths && [documentsDirPaths count] > 0);
    
    NSString* documentsDirPath = [documentsDirPaths objectAtIndex:0];
    DCHECK(documentsDirPath && [documentsDirPath length] > 0);
    
    NSString* fullFilePath = [NSString stringWithFormat:@"%@/%@", documentsDirPath, fileName];
    DCHECK(fullFilePath && [fullFilePath length] > 0);
    
    return [fileData writeToFile:fullFilePath atomically:NO];
}
@end

@implementation Debug

static BluetoothCommunicator*              _bluetoothCommunicator;
static id< BluetoothCommunicatorDelegate > _bluetoothCommunicatorDelegate;

+(void)setBluetoothCommunicator:(BluetoothCommunicator*)bluetoothCommunicator { _bluetoothCommunicator = bluetoothCommunicator; }
+(void)setBluetoothCommunicatorDelegate:(id< BluetoothCommunicatorDelegate >)delegate { _bluetoothCommunicatorDelegate = delegate; }

+(void)logf:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    NSString *log = [[NSString alloc] initWithFormat:format arguments:args];
    [Debug log:log];
    va_end(args);
}

+(void)log:(NSString *)msg {
    NSLog(@"%@", msg);
    if (_bluetoothCommunicatorDelegate != nil && _bluetoothCommunicator != nil) {
        [_bluetoothCommunicatorDelegate bluetoothCommunicator:_bluetoothCommunicator didLog:msg];
    }
}

+(void)raise:(NSString *)reason {
    [Debug log:reason];
    [[NSException exceptionWithName:@"RuntimeError" reason:reason userInfo:nil] raise];
}

+(void)checkf:(bool)condition file:(NSString*)file line:(int)line tag:(NSString*)tag format:(NSString*)format, ... {
    va_list args;
    va_start(args, format);
    NSString *msg = [[NSString alloc] initWithFormat:format arguments:args];
    [Debug check:condition file:file line:line tag:tag msg:msg];
    va_end(args);
}

+(void)check:(bool)condition file:(NSString*)file line:(int)line tag:(NSString*)tag msg:(NSString*)msg {
    if (TK_DEBUG && !condition) {
        [Debug raise:[NSString stringWithFormat:@"%@|'%@:%i': %@", tag, file, line, msg]];
    }
}

+(void)dcheckf:(bool)condition file:(const char*)file line:(int)line tag:(const char*)tag format:(const char*)format, ... {
    if (TK_DEBUG && !condition) {
        va_list args;
        va_start(args, format);
        NSString *msg = [[NSString alloc] initWithFormat:[NSString stringWithUTF8String:format] arguments:args];
        [Debug dcheck:condition file:file line:line tag:tag msg:[msg UTF8String]];
        va_end(args);
    }
}

+(void)dcheck:(bool)condition file:(const char*)file line:(int)line tag:(const char*)tag msg:(const char*)msg {
    if (TK_DEBUG && !condition) {
        [Debug raise:[NSString stringWithFormat:@"[%s] dcheck '%s:%i': %s", tag, file, line, msg]];
    }
}

@end
