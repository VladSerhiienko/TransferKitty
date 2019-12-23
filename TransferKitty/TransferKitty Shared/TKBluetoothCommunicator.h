#ifndef BluetoothCommunicator_h
#define BluetoothCommunicator_h

#include <CoreBluetooth/CoreBluetooth.h>
#include "TKConfig.h"

typedef NS_ENUM(NSUInteger, TKBluetoothCommunicatorStatusBits) {
    TKBluetoothCommunicatorStatusBitInitial = 0,
    TKBluetoothCommunicatorStatusBitStartingCentral = 1 << 0,
    TKBluetoothCommunicatorStatusBitCentral = 1 << 1,
    TKBluetoothCommunicatorStatusBitScanning = 1 << 2,
    TKBluetoothCommunicatorStatusBitReceiving = 1 << 3,
    TKBluetoothCommunicatorStatusBitStartingPeripheral = 1 << 4,
    TKBluetoothCommunicatorStatusBitPeripheral = 1 << 5,
    TKBluetoothCommunicatorStatusBitAdvertising = 1 << 6,
    TKBluetoothCommunicatorStatusBitSending = 1 << 7,
    TKBluetoothCommunicatorStatusBitConnecting = 1 << 8,
    TKBluetoothCommunicatorStatusBitConnected = 1 << 9,
    TKBluetoothCommunicatorStatusBitWaitingForSystem = 1 << 10,
    TKBluetoothCommunicatorStatusBitWaitingForUserInput = 1 << 11,
    TKBluetoothCommunicatorStatusBitUnsupported = 1 << 12,
    TKBluetoothCommunicatorStatusBitPanic = 1 << 13,
    TKBluetoothCommunicatorStatusBitPublishingService = 1 << 14,
    TKBluetoothCommunicatorStatusBitPublishedService = 1 << 15,
    TKBluetoothCommunicatorStatusBitStartingAdvertising = 1 << 16,
};

typedef NS_ENUM(NSUInteger, TKBluetoothCommunicatorMessageType) {
    TKBluetoothCommunicatorResponseMessageTypeByteIndex = 0,
    TKBluetoothCommunicatorMessageTypeByteIndex = 1,
    TKBluetoothCommunicatorShortMessageStartByteIndex = 2,
    TKBluetoothCommunicatorMessageLength0ByteIndex = 2,
    TKBluetoothCommunicatorMessageLength1ByteIndex = 3,
    TKBluetoothCommunicatorMessageLength2ByteIndex = 4,
    TKBluetoothCommunicatorMessageLength3ByteIndex = 5,
    TKBluetoothCommunicatorLongMessageStartByteIndex = 6,
    TKBluetoothCommunicatorMessageLengthIntegerByteLength = 4,
    TKBluetoothCommunicatorUUIDByteLength = 16,
    TKBluetoothCommunicatorMessageEncryptedBit = 1 << 7,
    TKBluetoothCommunicatorMessageShortBit = 1 << 6,
    TKBluetoothCommunicatorMessageTypeFinish = 0,
    TKBluetoothCommunicatorMessageTypeUUID = 1,
    TKBluetoothCommunicatorMessageTypeName = 2,
    TKBluetoothCommunicatorMessageTypeDeviceModel = 3,
    TKBluetoothCommunicatorMessageTypeDeviceFriendlyModel = 4,
    TKBluetoothCommunicatorMessageTypeFailure = 5,
    TKBluetoothCommunicatorMessageTypeConfirm = 6,
    TKBluetoothCommunicatorMessageTypeFile = 7,
};

typedef NS_ENUM(NSUInteger, TKBluetoothCommunicatorWriteValueResult) {
    TKBluetoothCommunicatorWriteValueResultSuccessContinue = 0,
    TKBluetoothCommunicatorWriteValueResultFailedReschedule = 1,
    TKBluetoothCommunicatorWriteValueResultErrorPanic = 2,
};

typedef NS_ENUM(NSUInteger, TKBluetoothCommunicatorOperationExecutionResult) {
    TKBluetoothCommunicatorOperationExecutionResultSuccessContinue = 0,
    TKBluetoothCommunicatorOperationExecutionResultFailedContinue = 1,
    TKBluetoothCommunicatorOperationExecutionResultFailedRetryLater = 2,
};

TK_STATIC_ASSERT(sizeof(NSUInteger) ==
                 sizeof(TKBluetoothCommunicatorStatusBits));
TK_STATIC_ASSERT(sizeof(NSUInteger) ==
                 sizeof(TKBluetoothCommunicatorMessageType));
TK_STATIC_ASSERT(sizeof(NSUInteger) ==
                 sizeof(TKBluetoothCommunicatorWriteValueResult));
TK_STATIC_ASSERT(sizeof(NSUInteger) ==
                 sizeof(TKBluetoothCommunicatorOperationExecutionResult));

static_assert(TKBluetoothCommunicatorMessageLength1ByteIndex ==
                  (TKBluetoothCommunicatorMessageLength0ByteIndex + 1),
              "");
static_assert(TKBluetoothCommunicatorMessageLength2ByteIndex ==
                  (TKBluetoothCommunicatorMessageLength1ByteIndex + 1),
              "");
static_assert(TKBluetoothCommunicatorMessageLength3ByteIndex ==
                  (TKBluetoothCommunicatorMessageLength2ByteIndex + 1),
              "");
static_assert(TKBluetoothCommunicatorMessageLengthIntegerByteLength ==
                  (TKBluetoothCommunicatorMessageLength3ByteIndex -
                   TKBluetoothCommunicatorMessageLength0ByteIndex + 1),
              "");

@interface NSStringUtilities : NSObject
+ (NSString *)empty;
+ (bool)isNilOrEmpty:(NSString *)string;
+ (NSString *)stringOrEmptyString:(NSString *)maybeNullString;
+ (NSString *)uuidStringOrEmptyString:(NSUUID *)maybeNullUUID;
@end

@interface TKSubdata : NSObject
- (instancetype)initWithData:(NSData *)data;
- (instancetype)initWithData:(NSData *)data range:(NSRange)range;
- (const uint8_t *)bytes;
- (NSUInteger)length;
@end

@interface TKMutableSubdata : NSObject
- (instancetype)initWithMutableData:(NSMutableData *)data;
- (instancetype)initWithMutableData:(NSMutableData *)data range:(NSRange)range;
- (uint8_t *)bytes;
- (NSUInteger)length;
@end

//@interface NSDataNoCopyUtilities : NSObject
//+ (NSData*)subdataNoCopy:(NSData*)data range:(NSRange)range;
//+ (NSMutableData*)mutableSubdataNoCopy:(NSMutableData*)data
// range:(NSRange)range;
//@end

@interface TKBluetoothCommunicatorMessage : NSObject
+ (NSUInteger)getMessageType:(NSData *)wholeMessageBytes;
+ (NSUInteger)getResponseMessageType:(NSData *)wholeMessageBytes;
+ (bool)isShortMessage:(NSUInteger)decoratedMessageType;
+ (bool)isEncryptedMessage:(NSUInteger)decoratedMessageType;
+ (NSUInteger)undecorateMessageType:(NSUInteger)decoratedMessageType;
+ (NSUInteger)shortMessageType:(NSUInteger)decoratedMessageType;
+ (NSUInteger)longMessageType:(NSUInteger)decoratedMessageType;
+ (NSUInteger)getMessageContentsByteLength:(NSData *)wholeMessageData;
+ (NSData *)intToBytes:(NSUInteger)integer;
+ (void)intToBytes:(NSUInteger)integer
           writeTo:(TKMutableSubdata *)mutableSubdata;
+ (NSUInteger)bytesToInt:(TKSubdata *)subdata;
+ (NSData *)uuidToBytes:(NSUUID *)UUID;
+ (void)uuidToBytes:(NSUUID *)UUID writeTo:(TKMutableSubdata *)mutableSubdata;
+ (NSUUID *)bytesToUUID:(TKSubdata *)subdata;
+ (bool)requiresResponse:(NSData *)wholeMessageData;
@end

@interface TKBluetoothCommunicatorLongMessage : NSObject
- (instancetype)initWithMessageData:(NSData *)messageData;
- (NSUInteger)getMessageType;
- (NSUInteger)getResponseMessageType;
- (NSUInteger)getMessageContentsOffset;
- (NSUInteger)getMessageContentsLength;
- (NSData *)getMessageContents;
- (void)start:(NSData *)wholeMessageData;
- (bool)canAppend:(NSUInteger)byteArrayLength;
- (bool)isComplete;
- (bool)append:(NSData *)wholeMessageData;
- (bool)isEmpty;
- (void)clear;
@end

@interface TKBluetoothCommunicatorDevice : NSObject <NSCopying>
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

@protocol TKBluetoothCommunicatorDelegate;

@interface TKBluetoothCommunicator : NSObject
+ (id)instance;
- (void)initCentralWithDelegate:(id<TKBluetoothCommunicatorDelegate>)delegate;
- (void)initPeripheralWithDelegate:
    (id<TKBluetoothCommunicatorDelegate>)delegate;
- (void)startAdvertising;
- (void)stopAdvertising;
- (void)startDiscoveringDevices;
- (void)stopDiscoveringDevices;
- (void)bluetoothCommunicatorDeviceDidUpdateProperty:
    (TKBluetoothCommunicatorDevice *)device;
- (NSArray *)connectedDevices;
- (NSUUID *)getUUID;
- (NSString *)getName;
- (NSString *)getModel;
- (NSString *)getFriendlyModel;
- (NSUInteger)statusBits;
- (bool)schedulerScheduleMessageFrom:(TKBluetoothCommunicatorDevice *)device
                    wholeMessageData:(NSData *)wholeMessageData;
- (bool)schedulerScheduleMessageTo:(TKBluetoothCommunicatorDevice *)device
                  wholeMessageData:(NSData *)wholeMessageData;
@end

@interface TKBluetoothCommunicatorEncoder : NSObject
- (TKBluetoothCommunicator *)bluetoothCommunicator;
- (instancetype)initWithBluetoothCommunicator:
    (TKBluetoothCommunicator *)bluetoothCommunicator;
- (NSData *)encodeConfirmationMessage:(TKBluetoothCommunicatorDevice *)device
                  responseMessageType:(NSUInteger)responseMessageType;
- (NSData *)encodeUUIDMessage:(TKBluetoothCommunicatorDevice *)device
          responseMessageType:(NSUInteger)responseMessageType;
- (NSData *)encodeNameMessage:(TKBluetoothCommunicatorDevice *)device
          responseMessageType:(NSUInteger)responseMessageType;
- (NSData *)encodeModelMessage:(TKBluetoothCommunicatorDevice *)device
           responseMessageType:(NSUInteger)responseMessageType;
- (NSData *)encodeFriendlyModelMessage:(TKBluetoothCommunicatorDevice *)device
                   responseMessageType:(NSUInteger)responseMessageType;
- (NSData *)encodeFileMessage:(TKBluetoothCommunicatorDevice *)device
                     fileName:(NSString *)fileName
                     fileData:(NSData *)fileData
          responseMessageType:(NSUInteger)responseMessageType;
@end

@interface TKBluetoothCommunicatorDecoder : NSObject
- (TKBluetoothCommunicator *)bluetoothCommunicator;
- (instancetype)initWithBluetoothCommunicator:
    (TKBluetoothCommunicator *)bluetoothCommunicator;
- (void)decodeShortMessageFrom:(TKBluetoothCommunicatorDevice *)device
        undecoratedMessageType:(NSUInteger)undecoratedMessageType
              wholeMessageData:(NSData *)wholeMessageData;
- (void)decodeWholeMessageFrom:(TKBluetoothCommunicatorDevice *)device
        undecoratedMessageType:(NSUInteger)undecoratedMessageType
               messageContents:(TKSubdata *)messageContents;
- (void)decodeWholeFileMessageFrom:(TKBluetoothCommunicatorDevice *)device
               fileMessageContents:(TKSubdata *)data;
@end

@interface TKBluetoothCommunicatorScheduledOperation : NSObject
- (instancetype)initWithData:(NSData *)data
            requiresResponse:(bool)requiresResponse;
- (NSData *)data;
- (bool)requiresResponse;
@end

@interface TKBluetoothCommunicatorScheduler : NSObject
- (TKBluetoothCommunicator *)bluetoothCommunicator;
- (TKBluetoothCommunicatorEncoder *)bluetoothCommunicatorEncoder;
- (TKBluetoothCommunicatorDecoder *)bluetoothCommunicatorDecoder;
- (instancetype)initWithBluetoothCommunicator:
    (TKBluetoothCommunicator *)bluetoothCommunicator;
- (bool)scheduleMessageFrom:(TKBluetoothCommunicatorDevice *)device
           wholeMessageData:(NSData *)wholeMessageData;
- (bool)scheduleMessageTo:(TKBluetoothCommunicatorDevice *)device
         wholeMessageData:(NSData *)wholeMessageData;
- (void)scheduleIntroductionMessagesTo:(TKBluetoothCommunicatorDevice *)device;
@end

@protocol TKBluetoothCommunicatorDelegate <NSObject>
- (void)bluetoothCommunicator:(TKBluetoothCommunicator *)bluetoothCommunicator
          didChangeStatusFrom:(TKBluetoothCommunicatorStatusBits)statusBits
                           to:(TKBluetoothCommunicatorStatusBits)
                                  currentStatusBits;

- (void)bluetoothCommunicator:(TKBluetoothCommunicator *)bluetoothCommunicator
           didConnectToDevice:(TKBluetoothCommunicatorDevice *)device;

- (void)bluetoothCommunicator:(TKBluetoothCommunicator *)bluetoothCommunicator
              didUpdateDevice:(TKBluetoothCommunicatorDevice *)device;

- (void)bluetoothCommunicator:(TKBluetoothCommunicator *)bluetoothCommunicator
         didSubscribeToDevice:(TKBluetoothCommunicatorDevice *)device;

- (void)bluetoothCommunicator:(TKBluetoothCommunicator *)bluetoothCommunicator
          didDisconnectDevice:(TKBluetoothCommunicatorDevice *)device;

- (void)bluetoothCommunicator:(TKBluetoothCommunicator *)bluetoothCommunicator
              didReceiveValue:(NSData *)value
                      orError:(NSError *)error
                   fromDevice:(TKBluetoothCommunicatorDevice *)device;

- (void)bluetoothCommunicator:(TKBluetoothCommunicator *)bluetoothCommunicator
         didWriteValueOrError:(NSError *)error
                     toDevice:(TKBluetoothCommunicatorDevice *)device;

- (void)bluetoothCommunicator:(TKBluetoothCommunicator *)bluetoothCommunicator
                       didLog:(NSString *)log;
@end

@interface TKFileSaver : NSObject
+ (bool)saveFile:(NSString *)fileName fileData:(NSData *)fileData;
@end

@interface TKDebug : NSObject
+ (void)setBluetoothCommunicator:
    (TKBluetoothCommunicator *)bluetoothCommunicator;
+ (void)setBluetoothCommunicatorDelegate:
    (id<TKBluetoothCommunicatorDelegate>)delegate;
+ (void)logf:(NSString *)format, ...;
+ (void)log:(NSString *)msg;
+ (void)checkf:(bool)condition
          file:(NSString *)file
          line:(int)line
           tag:(NSString *)tag
        format:(NSString *)format, ...;
+ (void)check:(bool)condition
         file:(NSString *)file
         line:(int)line
          tag:(NSString *)tag
          msg:(NSString *)msg;
+ (void)dcheckf:(bool)condition
           file:(const char *)file
           line:(int)line
            tag:(const char *)tag
         format:(const char *)format, ...;
+ (void)dcheck:(bool)condition
          file:(const char *)file
          line:(int)line
           tag:(const char *)tag
           msg:(const char *)msg;
@end

#define DCHECKF(condition, format, ...)  \
    [TKDebug dcheckf:(condition)         \
                file:__FILE__            \
                line:__LINE__            \
                 tag:__PRETTY_FUNCTION__ \
                 msg:format, __VA_ARGS__]
#define DCHECK(condition)               \
    [TKDebug dcheck:(condition)         \
               file:__FILE__            \
               line:__LINE__            \
                tag:__PRETTY_FUNCTION__ \
                msg:#condition]
#define DLOGF(format, ...) [TKDebug logf:format, __VA_ARGS__]
#define DLOG(log) [TKDebug log:log]

#ifndef TK_FUNC_NAME
#define TK_FUNC_NAME __PRETTY_FUNCTION__
#endif

#ifndef TK_DEBUG
#ifdef DEBUG
#define TK_DEBUG 1
#else
#define TK_DEBUG 0
#endif
#endif

#endif /* BluetoothCommunicator */
