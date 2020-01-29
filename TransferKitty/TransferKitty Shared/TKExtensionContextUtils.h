#pragma once
#include "TKConfig.h"

#ifdef __OBJC__
#if !TARGET_OS_IOS
#import <Cocoa/Cocoa.h>
#else
#import <UIKit/UIKit.h>
#endif

typedef NS_ENUM(NSUInteger, TKAttachmentStatusBits) {
    TKAttachmentStatusBitInitial = 0,
    TKAttachmentStatusBitHasURL = 1 << 0,
    TKAttachmentStatusBitLoadingURL = 1 << 1,
    TKAttachmentStatusBitLoadedURL = 1 << 2,
    TKAttachmentStatusBitErrorURL = 1 << 3,
    TKAttachmentStatusBitHasData = 1 << 4,
    TKAttachmentStatusBitLoadingData = 1 << 5,
    TKAttachmentStatusBitLoadedData = 1 << 6,
    TKAttachmentStatusBitErrorData = 1 << 7,
};

@interface TKAttachment : NSObject
- (void)prepareName;
- (void)prepareBuffer;
- (TKAttachmentStatusBits)itemStatus;
- (NSString*)name;
- (NSData*)data;
@end

@interface TKAttachmentContext : NSObject
+ (instancetype)attachmentContextWithExtensionContext:(NSExtensionContext*)context;
- (void)prepareNames;   // Only debugging
- (void)prepareBuffers; // Only debugging
- (NSArray*)attachments;
@end

#endif // __OBJC__
