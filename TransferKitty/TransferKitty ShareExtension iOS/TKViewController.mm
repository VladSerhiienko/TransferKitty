//
//  ShareViewController.m
//  TransferKitty iOS ShareExtension
//
//  Created by Vlad Serhiienko on 10/14/19.
//  Copyright © 2019 vserhiienko. All rights reserved.
//

//#import "TKShareViewController.h"
//
//@interface TKShareViewController ()
//
//@end
//
//@implementation TKShareViewController
//
//- (BOOL)isContentValid {
//    // Do validation of contentText and/or NSExtensionContext attachments here
//    return YES;
//}
//
//- (void)didSelectPost {
//    // This is called after the user selects Post. Do the upload of
//    contentText and/or NSExtensionContext attachments.
//
//    // Inform the host that we're done, so it un-blocks its UI. Note:
//    Alternatively you could call super's -didSelectPost, which will similarly
//    complete the extension context. [self.extensionContext
//    completeRequestReturningItems:@[] completionHandler:nil];
//}
//
//- (NSArray *)configurationItems {
//    // To add configuration options via table cells at the bottom of the
//    sheet, return an array of SLComposeSheetConfigurationItem here. return
//    @[];
//}
//
//@end

//
//  ShareViewController.m
//  ShareExtension
//
//  Created by Vlad Serhiienko on 9/29/19.
//  Copyright © 2019 vserhiienko. All rights reserved.
//

#import "TKViewController.h"

@implementation TKViewController

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

                for (NSItemProvider *itemProvider in [inputItem attachments]) {
                    if (itemProvider) {
                        NSLog(@"attachment: suggested name: %@", [itemProvider suggestedName]);
                        NSLog(@"          :    description: %@", [itemProvider description]);

                        // if ([itemProvider
                        // hasItemConformingToTypeIdentifier:@"public.url"]) {
                        //     [itemProvider
                        //     loadItemForTypeIdentifier:@"public.url"
                        //     options:nil
                        //                   completionHandler:^(NSURL *url,
                        //                   NSError *error)
                        //                   {
                        //                       NSString *urlString =
                        //                       url.absoluteString; NSLog(@" :
                        //                       public url: %@", urlString);
                        //                   }];
                        // }

                        if ([itemProvider hasItemConformingToTypeIdentifier:@"public.image"]) {
                            [itemProvider loadItemForTypeIdentifier:@"public.image"
                                                            options:nil
                                                  completionHandler:^(id<NSSecureCoding> item, NSError *error) {
                                                    UIImage *sharedImage = nil;
                                                    if ([(NSObject *)item isKindOfClass:[NSURL class]]) {
                                                        sharedImage = [UIImage
                                                            imageWithData:[NSData dataWithContentsOfURL:(NSURL *)item]];
                                                        NSLog(@"          : image from "
                                                              @"url: %@",
                                                              sharedImage);
                                                    }

                                                    if ([(NSObject *)item isKindOfClass:[UIImage class]]) {
                                                        sharedImage = (UIImage *)item;
                                                        NSLog(@"          :    image "
                                                              @"item: %@",
                                                              sharedImage);
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

- (BOOL)isContentValid {
    // Do validation of contentText and/or NSExtensionContext attachments here
    return YES;
}

- (void)didSelectPost {
    // This is called after the user selects Post. Do the upload of contentText
    // and/or NSExtensionContext attachments.

    // Inform the host that we're done, so it un-blocks its UI. Note:
    // Alternatively you could call super's -didSelectPost, which will similarly
    // complete the extension context.
    [self.extensionContext completeRequestReturningItems:@[] completionHandler:nil];
}

- (NSArray *)configurationItems {
    // To add configuration options via table cells at the bottom of the sheet,
    // return an array of SLComposeSheetConfigurationItem here.
    return @[];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self prepareViewController];
    [self printExtensionItems];
}
@end

@implementation TKView
- (instancetype)initWithFrame:(CGRect)frameRect device:(nullable id<MTLDevice>)device {
    self = [super initWithFrame:frameRect device:device];
    return self;
}
@end
