#ifndef BluetoothCommunicator_h
#define BluetoothCommunicator_h

#include <CoreBluetooth/CoreBluetooth.h>

#ifndef static_assert
#include <assert.h>
#include <AssertMacros.h>
#define static_assert __Check_Compile_Time
#endif

typedef NS_ENUM( NSUInteger, BTCStatusBits ) {
    BTCStatusBitInitial = 0,
    BTCStatusBitStartingCentral = 1 << 0,
    BTCStatusBitCentral = 1 << 1,
    BTCStatusBitScanning = 1 << 2,
    BTCStatusBitReceiving = 1 << 3,
    BTCStatusBitStartingPeripheral = 1 << 4,
    BTCStatusBitPeripheral = 1 << 5,
    BTCStatusBitAdvertising = 1 << 6,
    BTCStatusBitSending = 1 << 7,
    BTCStatusBitConnecting = 1 << 8,
    BTCStatusBitConnected = 1 << 9,
    BTCStatusBitWaitingForSystem = 1 << 10,
    BTCStatusBitWaitingForUserInput = 1 << 11,
    BTCStatusBitUnsupported = 1 << 12,
    BTCStatusBitPanic = 1 << 13,
};

typedef NS_ENUM( NSUInteger, BluetoothCommunicatorMessageType ) {
    BTCResponseMessageTypeByteIndex = 0,
    BTCMessageTypeByteIndex = 1,
    BTCShortMessageStartByteIndex = 2,
    BTCMessageLength0ByteIndex = 2,
    BTCMessageLength1ByteIndex = 3,
    BTCMessageLength2ByteIndex = 4,
    BTCMessageLength3ByteIndex = 5,
    BTCLongMessageStartByteIndex = 6,
    BTCMessageLengthIntegerByteLength = 4,
    BTCUUIDByteLength = 16,
    BTCMessageEncryptedBit = 1 << 7,
    BTCMessageShortBit = 1 << 6,
    BTCMessageTypeFinish = 0,
    BTCMessageTypeUUID = 1,
    BTCMessageTypeName = 2,
    BTCMessageTypeDeviceModel = 3,
    BTCMessageTypeDeviceFriendlyModel = 4,
    BTCMessageTypeFailure = 5,
    BTCMessageTypeConfirm = 6,
    BTCMessageTypeFile = 7,
};

static_assert(BTCMessageLength1ByteIndex == (BTCMessageLength0ByteIndex + 1));
static_assert(BTCMessageLength2ByteIndex == (BTCMessageLength1ByteIndex + 1));
static_assert(BTCMessageLength3ByteIndex == (BTCMessageLength2ByteIndex + 1));
static_assert(BTCMessageLengthIntegerByteLength == (BTCMessageLength3ByteIndex - BTCMessageLength0ByteIndex + 1));

@interface NSStringUtilities : NSObject
+ (NSString*)empty;
+ (bool)isNilOrEmpty:(NSString*)string;
+ (NSString*)stringOrEmptyString:(NSString*)maybeNullString;
+ (NSString*)uuidStringOrEmptyString:(NSUUID*)maybeNullUUID;
@end

@interface TKSubdata : NSObject
- (instancetype)initWithData:(NSData*)data;
- (instancetype)initWithData:(NSData*)data range:(NSRange)range;
- (const uint8_t*)bytes;
- (NSUInteger)length;
@end

@interface TKMutableSubdata : NSObject
- (instancetype)initWithMutableData:(NSMutableData*)data;
- (instancetype)initWithMutableData:(NSMutableData*)data range:(NSRange)range;
- (uint8_t*)bytes;
- (NSUInteger)length;
@end

//@interface NSDataNoCopyUtilities : NSObject
//+ (NSData*)subdataNoCopy:(NSData*)data range:(NSRange)range;
//+ (NSMutableData*)mutableSubdataNoCopy:(NSMutableData*)data range:(NSRange)range;
//@end

@interface BluetoothCommunicatorMessage : NSObject
+ (NSUInteger)getMessageType:(NSData*)wholeMessageBytes;
+ (NSUInteger)getResponseMessageType:(NSData*)wholeMessageBytes;
+ (bool)isShortMessage:(NSUInteger)decoratedMessageType;
+ (bool)isEncryptedMessage:(NSUInteger)decoratedMessageType;
+ (NSUInteger)undecorateMessageType:(NSUInteger)decoratedMessageType;
+ (NSUInteger)shortMessageType:(NSUInteger)decoratedMessageType;
+ (NSUInteger)longMessageType:(NSUInteger)decoratedMessageType;
+ (NSUInteger)getMessageContentsByteLength:(NSData*)wholeMessageData;
+ (NSData*)intToBytes:(NSUInteger)integer;
+ (void)intToBytes:(NSUInteger)integer writeTo:(TKMutableSubdata*)mutableSubdata;
+ (NSUInteger)bytesToInt:(TKSubdata*)subdata;
+ (NSData*)uuidToBytes:(NSUUID*)UUID;
+ (void)uuidToBytes:(NSUUID*)UUID writeTo:(TKMutableSubdata*)mutableSubdata;
+ (NSUUID*)bytesToUUID:(TKSubdata*)subdata;
+ (bool)requiresResponse:(NSData*)wholeMessageData;
@end

@interface BluetoothCommunicatorLongMessage : NSObject
- (instancetype)initWithMessageData:(NSData*)messageData;
- (NSUInteger)getMessageType;
- (NSUInteger)getResponseMessageType;
- (NSUInteger)getMessageContentsOffset;
- (NSUInteger)getMessageContentsLength;
- (NSData*)getMessageContents;
- (void)start:(NSData *)wholeMessageData;
- (bool)canAppend:(NSUInteger)byteArrayLength;
- (bool)isComplete;
- (bool)append:(NSData *)wholeMessageData;
- (bool)isEmpty;
- (void)clear;
@end

@interface BluetoothCommunicatorDevice : NSObject<NSCopying>
- (NSInteger)getId;
- (NSInteger)getMTU;
- (NSString *)getName;
- (NSString *)getModel;
- (NSString *)getFriendlyModel;
- (NSUUID *)getUUID;
- (void)setUUID:(NSUUID *)uuid;
- (void)setName:(NSString *)name;
- (void)setModel:(NSString *)model;
- (void)setFriendlyModel:(NSString *)friendlyModel;
- (id)copyWithZone:(NSZone *)zone;
- (BOOL)isEqual:(id)object;
- (NSUInteger)hash;
@end

@protocol BluetoothCommunicatorDelegate;

@interface BluetoothCommunicator : NSObject
+ (id)instance;
- (void)initCentralWithDelegate:(id< BluetoothCommunicatorDelegate >)delegate;
- (void)startDiscoveringDevices;
- (void)stopDiscoveringDevices;
- (void)bluetoothCommunicatorDeviceDidUpdateProperty:(BluetoothCommunicatorDevice *)device;
- (NSArray *)connectedDevices;
- (NSUUID *)getUUID;
- (NSString *)getName;
- (NSString *)getModel;
- (NSString *)getFriendlyModel;
- (NSUInteger)statusBits;
- (bool)schedulerScheduleMessageFrom:(BluetoothCommunicatorDevice*)device wholeMessageData:(NSData*)wholeMessageData;
- (bool)schedulerScheduleMessageTo:(BluetoothCommunicatorDevice*)device wholeMessageData:(NSData*)wholeMessageData;
@end

@interface BluetoothCommunicatorEncoder : NSObject
- (BluetoothCommunicator*)bluetoothCommunicator;
- (instancetype)initWithBluetoothCommunicator:(BluetoothCommunicator*)bluetoothCommunicator;
- (NSData*)encodeConfirmationMessage:(BluetoothCommunicatorDevice *)device responseMessageType:(NSUInteger)responseMessageType;
- (NSData*)encodeUUIDMessage:(BluetoothCommunicatorDevice *)device responseMessageType:(NSUInteger)responseMessageType;
- (NSData*)encodeNameMessage:(BluetoothCommunicatorDevice *)device responseMessageType:(NSUInteger)responseMessageType;
- (NSData*)encodeModelMessage:(BluetoothCommunicatorDevice *)device responseMessageType:(NSUInteger)responseMessageType;
- (NSData*)encodeFriendlyModelMessage:(BluetoothCommunicatorDevice *)device responseMessageType:(NSUInteger)responseMessageType;
- (NSData*)encodeFileMessage:(BluetoothCommunicatorDevice *)device fileName:(NSString*)fileName fileData:(NSData*)fileData responseMessageType:(NSUInteger)responseMessageType;
@end

@interface BluetoothCommunicatorDecoder : NSObject
- (BluetoothCommunicator*)bluetoothCommunicator;
- (instancetype)initWithBluetoothCommunicator:(BluetoothCommunicator*)bluetoothCommunicator;
- (void)decodeShortMessageFrom:(BluetoothCommunicatorDevice *)device undecoratedMessageType:(NSUInteger)undecoratedMessageType wholeMessageData:(NSData*)wholeMessageData;
- (void)decodeWholeMessageFrom:(BluetoothCommunicatorDevice *)device undecoratedMessageType:(NSUInteger)undecoratedMessageType messageContents:(TKSubdata*)messageContents;
- (void)decodeWholeFileMessageFrom:(BluetoothCommunicatorDevice *)device fileMessageContents:(TKSubdata*)data;
@end

@interface BluetoothCommunicatorScheduledOperation : NSObject
- (instancetype)initWithData:(NSData*)data requiresResponse:(bool)requiresResponse;
- (NSData*)data;
- (bool)requiresResponse;
@end

@interface BluetoothCommunicatorScheduler : NSObject
- (BluetoothCommunicator*)bluetoothCommunicator;
- (BluetoothCommunicatorEncoder*)bluetoothCommunicatorEncoder;
- (BluetoothCommunicatorDecoder*)bluetoothCommunicatorDecoder;
- (instancetype)initWithBluetoothCommunicator:(BluetoothCommunicator*)bluetoothCommunicator;
- (bool)scheduleMessageFrom:(BluetoothCommunicatorDevice*)device wholeMessageData:(NSData*)wholeMessageData;
- (bool)scheduleMessageTo:(BluetoothCommunicatorDevice*)device wholeMessageData:(NSData*)wholeMessageData;
@end

@protocol BluetoothCommunicatorDelegate < NSObject >
- (void)bluetoothCommunicator:(BluetoothCommunicator *)bluetoothCommunicator
              didChangeStatus:(BTCStatusBits)statusBits;

- (void)bluetoothCommunicator:(BluetoothCommunicator *)bluetoothCommunicator
           didConnectToDevice:(BluetoothCommunicatorDevice *)device;

- (void)bluetoothCommunicator:(BluetoothCommunicator *)bluetoothCommunicator
              didUpdateDevice:(BluetoothCommunicatorDevice *)device;

- (void)bluetoothCommunicator:(BluetoothCommunicator *)bluetoothCommunicator
         didSubscribeToDevice:(BluetoothCommunicatorDevice *)device;

- (void)bluetoothCommunicator:(BluetoothCommunicator *)bluetoothCommunicator
          didDisconnectDevice:(BluetoothCommunicatorDevice *)device;

- (void)bluetoothCommunicator:(BluetoothCommunicator *)bluetoothCommunicator
              didReceiveValue:(NSData *)value
                      orError:(NSError *)error
                   fromDevice:(BluetoothCommunicatorDevice *)device;

- (void)bluetoothCommunicator:(BluetoothCommunicator *)bluetoothCommunicator
         didWriteValueOrError:(NSError *)error
                     toDevice:(BluetoothCommunicatorDevice *)device;

- (void)bluetoothCommunicator:(BluetoothCommunicator *)bluetoothCommunicator
                       didLog:(NSString *)log;
@end

@interface FileSaver : NSObject
+ (bool)saveFile:(NSString*)fileName fileData:(NSData*)fileData;
@end

@interface Debug : NSObject
+(void)setBluetoothCommunicator:(BluetoothCommunicator*)bluetoothCommunicator;
+(void)setBluetoothCommunicatorDelegate:(id< BluetoothCommunicatorDelegate >)delegate;
+(void)logf:(NSString *)format, ...;
+(void)log:(NSString *)msg;
+(void)checkf:(bool)condition file:(NSString*)file line:(int)line tag:(NSString*)tag format:(NSString*)format, ...;
+(void)check:(bool)condition file:(NSString*)file line:(int)line tag:(NSString*)tag msg:(NSString*)msg;
+(void)dcheckf:(bool)condition file:(const char*)file line:(int)line tag:(const char*)tag format:(const char*)format, ...;
+(void)dcheck:(bool)condition file:(const char*)file line:(int)line tag:(const char*)tag msg:(const char*)msg;
@end

#define DCHECKF(condition, format, ...) [Debug dcheckf:(condition) file:__FILE__ line:__LINE__ tag:__PRETTY_FUNCTION__ msg:format, __VA_ARGS__]
#define DCHECK(condition) [Debug dcheck:(condition) file:__FILE__ line:__LINE__ tag:__PRETTY_FUNCTION__ msg:#condition]
#define DLOGF(format, ...) [Debug logf:format, __VA_ARGS__]
#define DLOG(log) [Debug log:log]

#endif /* BluetoothCommunicator */
