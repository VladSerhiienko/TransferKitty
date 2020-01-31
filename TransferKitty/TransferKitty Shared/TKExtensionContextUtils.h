#pragma once
#include "TKConfig.h"
#import "TKStringUtilities.h"

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

@interface TKStringUtilities (TKAttachmentStatusBits)
+ (NSString *)attachmentBitsToString:(TKAttachmentStatusBits)bits;
@end

@interface TKAttachment : NSObject
- (NSUInteger)index;
- (void)prepareBuffer;
- (void)releaseBuffer;
- (TKAttachmentStatusBits)status;
- (NSString *)name;
- (NSData *)data;
@end

@protocol TKAttachmentContextDelegate;

@interface TKAttachmentContext : NSObject
+ (instancetype)attachmentContextWithExtensionContext:(NSExtensionContext *)context;
- (void)prepareAttachmentsWithDelegate:(id<TKAttachmentContextDelegate>)delegate;
- (NSArray *)attachments;
TK_DEBUG_CODE(-(void)prepareBuffers;)
TK_DEBUG_CODE(-(void)releaseBuffers;)
@end

@protocol TKAttachmentContextDelegate <NSObject>
- (void)attachmentContext:(TKAttachmentContext *)attachmentContext
    didPrepareNameForAttachment:(TKAttachment *)attachment
                        orError:(NSError *)error;
- (void)attachmentContext:(TKAttachmentContext *)attachmentContext
    didPrepareBufferForAttachment:(TKAttachment *)attachment
                          orError:(NSError *)error;
@end

#endif // __OBJC__
