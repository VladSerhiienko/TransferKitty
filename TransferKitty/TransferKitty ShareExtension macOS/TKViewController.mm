//
//  ShareViewController.m
//  TransferKitty ShareExtension macOS
//
//  Created by Vladyslav Serhiienko on 11/2/19.
//  Copyright © 2019 vserhiienko. All rights reserved.
//

#import "TKViewController.h"

@implementation TKViewController
- (void)viewDidLoad {
    [super viewDidLoad];
}

// Do validation of contentText and/or NSExtensionContext attachments here
- (BOOL)printExtensionItems {
    if (!self || !self.extensionContext) { return YES; }

    // NSLog(@"------ isContentValid ------");
    // NSLog(@"content: %@", self.contentText);

    if (self.extensionContext.inputItems) {
        NSLog(@"------");
        NSArray *inputItems = self.extensionContext.inputItems;
        NSLog(@"inputs: %lu", (unsigned long)[self.extensionContext.inputItems count]);

        for (NSExtensionItem *inputItem in inputItems) {
            if (inputItem && [inputItem attachments]) {
                NSLog(@"attachments: %lu", [[inputItem attachments] count]);
                NSLog(@"input iteam: %@", inputItem);

                for (NSItemProvider *itemProvider in [inputItem attachments]) {
                    if (itemProvider) {
                        NSLog(@"attachment: suggested name: %@", [itemProvider suggestedName]);
                        NSLog(@"attachment: (d)description: %@", [itemProvider debugDescription]);
                        NSLog(@"          :    description: %@", [itemProvider description]);

                        if ([itemProvider hasItemConformingToTypeIdentifier:@"public.file-url"]) {
                            [itemProvider loadItemForTypeIdentifier:@"public.file-url"
                                                            options:nil
                                                  completionHandler:^(id<NSSecureCoding> item, NSError *error) {
                                                    if (error) {
                                                        NSLog(@"          : file url error: %@", error);
                                                        return;
                                                    }

                                                    if ([(NSObject *)item isKindOfClass:[NSURL class]]) {
                                                        NSURL *url = (NSURL *)item;
                                                        NSLog(@"          : file url: %@", url);
                                                    } else {
                                                        NSLog(@"          : file url item: %@, unexpected class", item);
                                                    }
                                                  }];
                        }

                        if ([itemProvider hasItemConformingToTypeIdentifier:@"public.url"]) {
                            [itemProvider loadItemForTypeIdentifier:@"public.url"
                                                            options:nil
                                                  completionHandler:^(id<NSSecureCoding> item, NSError *error) {
                                                    if (error) {
                                                        NSLog(@"          : url error: %@", error);
                                                        return;
                                                    }

                                                    if ([(NSObject *)item isKindOfClass:[NSURL class]]) {
                                                        NSURL *url = (NSURL *)item;
                                                        NSLog(@"          : url: %@", url);
                                                    } else {
                                                        NSLog(@"          : url item: %@, unexpected class", item);
                                                    }
                                                  }];
                        }

                        if ([itemProvider hasItemConformingToTypeIdentifier:@"public.image"]) {
                            [itemProvider loadItemForTypeIdentifier:@"public.image"
                                                            options:nil
                                                  completionHandler:^(id<NSSecureCoding> item, NSError *error) {
                                                    if (error) {
                                                        NSLog(@"          : error: %@", error);
                                                        return;
                                                    }

                                                    NSImage *sharedImage = nil;
                                                    if ([(NSObject *)item isKindOfClass:[NSURL class]]) {
                                                        NSData *data = [NSData dataWithContentsOfURL:(NSURL *)item];
                                                        sharedImage = [[NSImage alloc] initWithData:data];
                                                        NSLog(@"          : image from url: %@", sharedImage);
                                                    } else if ([(NSObject *)item isKindOfClass:[NSData class]]) {
                                                        NSData *data = (NSData *)item;
                                                        sharedImage = [[NSImage alloc] initWithData:data];
                                                        NSLog(@"          : image from url: %@", sharedImage);
                                                    } else if ([(NSObject *)item isKindOfClass:[NSImage class]]) {
                                                        sharedImage = (NSImage *)item;
                                                        NSLog(@"          : image item: %@", sharedImage);
                                                    } else {
                                                        NSLog(@"          : image item: %@, unexpected class", item);
                                                    }
                                                  }];
                        }
                    }
                }
            }
        }
    }

    NSLog(@"------ xxxxxxxxxxxxxx ------");
    return YES;
}

- (void)viewDidAppear {
    [super viewDidAppear];
    [self printExtensionItems];
    [self prepareViewController];
}

- (NSString *)nibName {
    return @"Main";
}
@end

@implementation TKView
- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    return self;
}
@end
