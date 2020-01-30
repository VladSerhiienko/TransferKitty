
#import "TKExtensionContextUtils.h"

#ifdef __OBJC__
#if !TARGET_OS_IOS
#import <AppKit/NSImage.h>
#else
#import <UIKit/UIImage.h>
#endif
#endif

#include <atomic>

using tk::setBit;
using tk::hasBit;
using tk::unsetBit;

@implementation TKStringUtilities (TKAttachmentStatusBits)
+ (NSString *)attachmentBitsToString:(TKAttachmentStatusBits)bits {
    NSMutableString *mutableString = [[NSMutableString alloc] initWithCapacity:128];

    // clang-format off
    if (bits == TKAttachmentStatusBitInitial) { [mutableString appendString:@"Initial|"]; }
    if (bits &  TKAttachmentStatusBitHasURL) { [mutableString appendString:@"HasURL|"]; }
    if (bits &  TKAttachmentStatusBitLoadingURL) { [mutableString appendString:@"LoadingURL|"]; }
    if (bits &  TKAttachmentStatusBitLoadedURL) { [mutableString appendString:@"LoadedURL|"]; }
    if (bits &  TKAttachmentStatusBitErrorURL) { [mutableString appendString:@"ErrorURL|"]; }
    if (bits &  TKAttachmentStatusBitHasData) { [mutableString appendString:@"HasData|"]; }
    if (bits &  TKAttachmentStatusBitLoadingData) { [mutableString appendString:@"LoadingData|"]; }
    if (bits &  TKAttachmentStatusBitLoadedData) { [mutableString appendString:@"LoadedData|"]; }
    if (bits &  TKAttachmentStatusBitErrorData) { [mutableString appendString:@"ErrorData|"]; }
    // clang-format on

    [mutableString deleteCharactersInRange:NSMakeRange([mutableString length] - 1, 1)];
    return mutableString;
}
@end

@implementation TKAttachment {
    NSItemProvider *_itemProvider;
    NSURL *_url;
    NSString *_name;
    NSData *_data;
    id _image;
    std::atomic<NSUInteger> _statusBits;
}

// clang-format off
static NSString *kPublicFileURL = @"public.file-url"; // [NSString stringWithUTF8String:CFStringGetCStringPtr(kUTTypeFileURL, kCFStringEncodingUTF8)];
static NSString *kPublicURL = @"public.url"; // [NSString stringWithUTF8String:CFStringGetCStringPtr(kUTTypeURL, kCFStringEncodingUTF8)];
static NSString *kPublicImage = @"public.image"; // [NSString stringWithUTF8String:CFStringGetCStringPtr(kUTTypeImage, kCFStringEncodingUTF8)];
// clang-format on

+ (NSArray *)supportedTypeIdentifiers {
    // https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/UTIRef/Articles/System-DeclaredUniformTypeIdentifiers.html#//apple_ref/doc/uid/TP40009259-SW1
    return @[ kPublicFileURL, kPublicURL, kPublicImage ];
}

+ (instancetype)attachmentWithItemProvider:(NSItemProvider *)itemProvider {
    return [[TKAttachment alloc] initWithItemProvider:itemProvider];
}

- (instancetype)initWithItemProvider:(NSItemProvider *)itemProvider {
    self = [super init];
    if (self) {
        if (itemProvider) {
            _itemProvider = itemProvider;

            NSUInteger status = [_itemProvider hasItemConformingToTypeIdentifier:kPublicFileURL]
                                    ? TKAttachmentStatusBitHasURL
                                    : TKAttachmentStatusBitInitial;
            status |= [_itemProvider hasItemConformingToTypeIdentifier:kPublicURL] ? TKAttachmentStatusBitHasURL
                                                                                   : TKAttachmentStatusBitInitial;
            status |= [_itemProvider hasItemConformingToTypeIdentifier:kPublicImage] ? TKAttachmentStatusBitHasData
                                                                                     : TKAttachmentStatusBitInitial;

#if TARGET_OS_IOS
            // iOS case: Provides a URL instance for an image request.
            status |= [_itemProvider hasItemConformingToTypeIdentifier:kPublicImage] ? TKAttachmentStatusBitHasURL
                                                                                     : TKAttachmentStatusBitInitial;
#endif

            DLOGF(@"%s: attachment %p, status='%@'",
                  TK_FUNC_NAME,
                  self,
                  [TKStringUtilities attachmentBitsToString:TKAttachmentStatusBits(status)]);
            _statusBits = status;
        }
    }
    return self;
}

- (TKAttachmentStatusBits)itemStatus {
    return TKAttachmentStatusBits(_statusBits.load(std::memory_order_consume));
}

- (NSString *)goodName:(NSURL *)url {
    DLOGF(@"%s: url={%@}, isFileURL=%i, isFileReferenceURL=%i, hasDirectoryPath=%i",
          TK_FUNC_NAME,
          url,
          [url isFileURL],
          [url isFileReferenceURL],
          [url hasDirectoryPath]);

    NSArray *pathComponents = url.pathComponents;
    if (pathComponents && pathComponents.count >= 2) {
        NSString *name = pathComponents[pathComponents.count - 1];
        NSString *directory = pathComponents[pathComponents.count - 2];
        return [NSString stringWithFormat:@"%@-%@", directory, name];
    }

    NSString *lastPathComponent = url.lastPathComponent;
    if (lastPathComponent) { return lastPathComponent; }

    return [[[NSUUID UUID] UUIDString] stringByAppendingString:@"-TK.bin"];
}

- (void)didLoadURL:(id<NSSecureCoding>)item orError:(NSError *)error forTypeIdentifier:(NSString *)typeIdentifier {
    if (error) {
        _statusBits.fetch_or(TKAttachmentStatusBitErrorURL, std::memory_order_release);
        _statusBits.fetch_and(~TKAttachmentStatusBitLoadedURL, std::memory_order_release);
        _statusBits.fetch_and(~TKAttachmentStatusBitLoadingURL, std::memory_order_release);
        DLOGF(@"%s: type='%@', error='%@'", TK_FUNC_NAME, typeIdentifier, error);
        return;
    }

    NSObject *itemObj = (NSObject *)item;
    if (!itemObj) {
        _statusBits.fetch_or(TKAttachmentStatusBitErrorURL, std::memory_order_release);
        _statusBits.fetch_and(~TKAttachmentStatusBitLoadedURL, std::memory_order_release);
        DLOGF(@"%s: type='%@', item is not an object or nil.", TK_FUNC_NAME, typeIdentifier);
        return;
    }

    if ([itemObj isKindOfClass:[NSURL class]]) {
        _url = (NSURL *)item;
        _name = [self goodName:_url];
        DLOGF(@"%s: type='%@', name='%@', url={%@}", TK_FUNC_NAME, typeIdentifier, _name, _url);

        _statusBits.fetch_or(TKAttachmentStatusBitHasURL, std::memory_order_release);
        _statusBits.fetch_or(TKAttachmentStatusBitLoadedURL, std::memory_order_release);
        _statusBits.fetch_and(~TKAttachmentStatusBitLoadingURL, std::memory_order_release);
    } else {
        DLOGF(@"%s: type='%@', item={%@}, unexpected class", TK_FUNC_NAME, typeIdentifier, item);

        _statusBits.fetch_or(TKAttachmentStatusBitErrorURL, std::memory_order_release);
        _statusBits.fetch_and(~TKAttachmentStatusBitLoadedURL, std::memory_order_release);
    }
}

- (id)imageFromData:(NSData *)data {
    return
#if !TARGET_OS_IOS
        [[NSImage alloc] initWithData:_data];
#else
        [UIImage imageWithData:_data];
#endif
}

- (void)didLoadImage:(id<NSSecureCoding>)item orError:(NSError *)error forTypeIdentifier:(NSString *)typeIdentifier {
    if (error) {
        _statusBits.fetch_or(TKAttachmentStatusBitErrorData, std::memory_order_release);
        _statusBits.fetch_and(~TKAttachmentStatusBitLoadedData, std::memory_order_release);
        DLOGF(@"%s: type='%@', error='%@'.", TK_FUNC_NAME, typeIdentifier, error);
        return;
    }

    NSObject *itemObj = (NSObject *)item;
    if (!itemObj) {
        _statusBits.fetch_or(TKAttachmentStatusBitErrorData, std::memory_order_release);
        _statusBits.fetch_and(~TKAttachmentStatusBitLoadedData, std::memory_order_release);
        DLOGF(@"%s: type='%@', item is not an object or nil.", TK_FUNC_NAME, typeIdentifier);
        return;
    }

    if ([itemObj isKindOfClass:[NSURL class]]) {
        // iOS case: Received a URL instance for an image request.
        NSURL *url = (NSURL *)item;
        DCHECK([url isEqual:_url] && _name);
        _data = [NSData dataWithContentsOfURL:url];

        // TODO: Only for preview generation/debugging, we transfer only the data (buffer) objects.
        _image = [self imageFromData:_data];

        DLOGF(@"%s: type='%@', image={%@}', data={%@}", TK_FUNC_NAME, typeIdentifier, _image, _data);

        _statusBits.fetch_or(TKAttachmentStatusBitHasURL, std::memory_order_release);
        _statusBits.fetch_or(TKAttachmentStatusBitLoadedURL, std::memory_order_release);
        _statusBits.fetch_or(TKAttachmentStatusBitLoadedData, std::memory_order_release);
        _statusBits.fetch_and(~TKAttachmentStatusBitLoadingData, std::memory_order_release);
    } else if ([itemObj isKindOfClass:[NSData class]]) {
        // macOS case: Already receives a data instance, that can be transferred.
        _data = (NSData *)item;

        // TODO: Only for preview generation/debugging, we transfer only the data (buffer) objects.
        _image = [self imageFromData:_data];

        DLOGF(@"%s: type='%@', image={%@}', data={%@}", TK_FUNC_NAME, typeIdentifier, _image, _data);

        _statusBits.fetch_or(TKAttachmentStatusBitLoadedData, std::memory_order_release);
        _statusBits.fetch_and(~TKAttachmentStatusBitLoadingData, std::memory_order_release);
    }
#if !TARGET_OS_IOS
    else if ([itemObj isKindOfClass:[NSImage class]]) {
        NSImage *image = (NSImage *)item;
        _image = image;
        _name = [image name];
        _data = [_image TIFFRepresentation];

        DLOGF(@"%s: type='%@', image={%@}', data={%@}", TK_FUNC_NAME, typeIdentifier, _image, _data);

        _statusBits.fetch_or(TKAttachmentStatusBitLoadedData, std::memory_order_release);
        _statusBits.fetch_and(~TKAttachmentStatusBitLoadingData, std::memory_order_release);
    }
#endif
    else {
        DLOGF(@"%s: type='%@', item={%@}, unexpected class", TK_FUNC_NAME, typeIdentifier, item);

        _statusBits.fetch_or(TKAttachmentStatusBitErrorData, std::memory_order_release);
        _statusBits.fetch_and(~TKAttachmentStatusBitLoadedData, std::memory_order_release);
    }
}

// If the completion block signature contains a parameter that is not the same class as `item`, some coercion may
// occur:
//    Original class       Requested class          Coercion action
//    -------------------  -----------------------  -------------------
//    NSURL                NSData                   The contents of the URL is read and returned as NSData
//    NSData               NSImage/UIImage          An NSImage (macOS) or UIImage (iOS) is constructed from the data
//    NSURL                UIImage                  A UIImage is constructed from the file at the URL (iOS)
//    NSImage              NSData                   A TIFF representation of the image is returned
- (void)didLoadItem:(id<NSSecureCoding>)item
              orError:(NSError *)error
    forTypeIdentifier:(nonnull NSString *)typeIdentifier {
    DCHECK(typeIdentifier);

    if ([typeIdentifier isEqualToString:kPublicURL]) {
        [self didLoadURL:item orError:error forTypeIdentifier:typeIdentifier];
    } else if ([typeIdentifier isEqualToString:kPublicImage]) {
        [self didLoadImage:item orError:error forTypeIdentifier:typeIdentifier];
    }

    DLOGF(@"%s: attachment %p, status='%@'",
          TK_FUNC_NAME,
          self,
          [TKStringUtilities attachmentBitsToString:TKAttachmentStatusBits(_statusBits.load())]);
}

- (void)prepareName {
    NSUInteger statusBits = _statusBits.load(std::memory_order_acquire);
    if (hasBit(statusBits, TKAttachmentStatusBitLoadingURL) || hasBit(statusBits, TKAttachmentStatusBitLoadedURL) ||
        hasBit(statusBits, TKAttachmentStatusBitErrorURL)) {
        DLOGF(@"%s: a name/url for attachment %p is already loading/loaded.", TK_FUNC_NAME, self);
        return;
    }
    statusBits = _statusBits.fetch_or(TKAttachmentStatusBitLoadingURL, std::memory_order_acq_rel);
    if (!hasBit(statusBits, TKAttachmentStatusBitLoadingURL)) {
        if ([_itemProvider hasItemConformingToTypeIdentifier:kPublicFileURL]) {
            [_itemProvider loadItemForTypeIdentifier:kPublicFileURL
                                             options:nil
                                   completionHandler:^(id<NSSecureCoding> item, NSError *error) {
                                       [self didLoadItem:item orError:error forTypeIdentifier:kPublicURL];
                                   }];
        } else if ([_itemProvider hasItemConformingToTypeIdentifier:kPublicURL]) {
            [_itemProvider loadItemForTypeIdentifier:kPublicURL
                                             options:nil
                                   completionHandler:^(id<NSSecureCoding> item, NSError *error) {
                                       [self didLoadItem:item orError:error forTypeIdentifier:kPublicURL];
                                   }];
        } else if ([_itemProvider hasItemConformingToTypeIdentifier:kPublicImage]) {
            // iOS case: instead of two providers (URL, image) we receive only an image provider.
            // For an image provider we receive a URL instance.
            [_itemProvider loadItemForTypeIdentifier:kPublicImage
                                             options:nil
                                   completionHandler:^(id<NSSecureCoding> item, NSError *error) {
                                       [self didLoadItem:item orError:error forTypeIdentifier:kPublicURL];
                                   }];
        }
    }
}

- (void)prepareBuffer {
    NSUInteger statusBits = _statusBits.load(std::memory_order_acquire);
    if (hasBit(statusBits, TKAttachmentStatusBitLoadingData) || hasBit(statusBits, TKAttachmentStatusBitLoadedData) ||
        hasBit(statusBits, TKAttachmentStatusBitErrorData)) {
        return;
    }

    statusBits = _statusBits.fetch_or(TKAttachmentStatusBitLoadingData, std::memory_order_acq_rel);
    if (!hasBit(statusBits, TKAttachmentStatusBitLoadingData)) {
        if ([_itemProvider hasItemConformingToTypeIdentifier:kPublicImage]) {
            [_itemProvider loadItemForTypeIdentifier:kPublicImage
                                             options:nil
                                   completionHandler:^(id<NSSecureCoding> item, NSError *error) {
                                       [self didLoadItem:item orError:error forTypeIdentifier:kPublicImage];
                                   }];
        } else if ([_itemProvider hasItemConformingToTypeIdentifier:kPublicFileURL]) {
            [_itemProvider loadItemForTypeIdentifier:kPublicFileURL
                                             options:nil
                                   completionHandler:^(id<NSSecureCoding> item, NSError *error) {
                                       [self didLoadItem:item orError:error forTypeIdentifier:kPublicImage];
                                   }];
        } else if ([_itemProvider hasItemConformingToTypeIdentifier:kPublicURL]) {
            [_itemProvider loadItemForTypeIdentifier:kPublicURL
                                             options:nil
                                   completionHandler:^(id<NSSecureCoding> item, NSError *error) {
                                       [self didLoadItem:item orError:error forTypeIdentifier:kPublicImage];
                                   }];
        }
    }
}

- (NSString *)name {
    TK_ASSERT(hasBit([self itemStatus], TKAttachmentStatusBitLoadedURL));
    return _name;
}
- (NSData *)data {
    TK_ASSERT(hasBit([self itemStatus], TKAttachmentStatusBitLoadedData));
    return _data;
}
@end

@implementation TKAttachmentContext {
    NSExtensionContext *_context;
    NSMutableArray *_attachments;
}

+ (instancetype)attachmentContextWithExtensionContext:(NSExtensionContext *)context {
    DCHECK(context);
    return [[TKAttachmentContext alloc] initWithContext:context];
}

- (instancetype)initWithContext:(NSExtensionContext *)context {
    self = [super init];
    if (self) {
        DCHECK(context);
        _context = context;
        [self initAttachments];
    }
    return self;
}

- (void)initAttachments {
    DCHECK(_context);

    _attachments = [[NSMutableArray alloc] init];
    DCHECK(_attachments);

    NSArray *inputItems = _context.inputItems;
    DCHECK(inputItems);

    for (NSExtensionItem *inputItem in inputItems) {
        DCHECK(inputItem && [inputItem attachments] && [inputItem attachments].count);
        if (inputItem && [inputItem attachments] && [inputItem attachments].count) {
            for (NSItemProvider *itemProvider in [inputItem attachments]) {
                if (itemProvider && itemProvider.registeredTypeIdentifiers &&
                    itemProvider.registeredTypeIdentifiers.count) {
                    DCHECK(itemProvider && itemProvider.registeredTypeIdentifiers &&
                           itemProvider.registeredTypeIdentifiers.count);

                    for (NSString *supportedTypeIdentifier in [TKAttachment supportedTypeIdentifiers]) {
                        if ([itemProvider hasItemConformingToTypeIdentifier:supportedTypeIdentifier]) {
                            [_attachments addObject:[TKAttachment attachmentWithItemProvider:itemProvider]];
                            break;
                        }
                    }
                }
            }
        }
    }
}

- (void)prepareNames {
    DCHECK(_attachments);
    for (TKAttachment *attachment in _attachments) { [attachment prepareName]; }
}

- (void)prepareBuffers {
    DCHECK(_attachments);
    for (TKAttachment *attachment in _attachments) { [attachment prepareBuffer]; }
}

- (NSArray *)attachments {
    DCHECK(_attachments);
    return _attachments;
}
@end
