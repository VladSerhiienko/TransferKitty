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
//    // This is called after the user selects Post. Do the upload of contentText and/or NSExtensionContext attachments.
//
//    // Inform the host that we're done, so it un-blocks its UI. Note: Alternatively you could call super's -didSelectPost, which will similarly complete the extension context.
//    [self.extensionContext completeRequestReturningItems:@[] completionHandler:nil];
//}
//
//- (NSArray *)configurationItems {
//    // To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.
//    return @[];
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
#import "TKNuklearMetalViewDelegate.h"

#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

@interface TKViewController ()  < TKNuklearFrameDelegate >
@end

@implementation TKViewController
{
    MTKView *_view;
    TKNuklearMetalViewDelegate *_renderer;
}

- (void)dealloc {
    [_renderer deinit];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    _view = (MTKView *)self.view;

    _view.device = MTLCreateSystemDefaultDevice();
    _view.backgroundColor = UIColor.blackColor;

    if(!_view.device)
    {
        NSLog(@"Metal is not supported on this device");
        self.view = [[UIView alloc] initWithFrame:self.view.frame];
        return;
    }

    _renderer = [[TKNuklearMetalViewDelegate alloc] initWithMetalKitView:_view];
    [_renderer mtkView:_view drawableSizeWillChange:_view.bounds.size];

    _view.delegate = _renderer;
    _renderer.delegate = self;
    
    [self printExtensionItems];
}

- (void)renderer:(nonnull TKNuklearMetalViewDelegate *)renderer currentFrame:(nonnull TKNuklearFrame *)currentFrame {
    struct nk_context* ctx = currentFrame.contextPtr;

    if (nk_begin(ctx, "Demo (iOS, Shared)", nk_rect(50, 100, 500, 800),
        NK_WINDOW_BORDER|NK_WINDOW_MOVABLE|NK_WINDOW_SCALABLE|
        NK_WINDOW_CLOSABLE|NK_WINDOW_MINIMIZABLE|NK_WINDOW_TITLE)) {

        nk_layout_row_dynamic(ctx, 50, 2);
        if (nk_button_label(ctx, "button")) {
            fprintf(stdout, "button pressed\n");
        }
    }
    
    nk_end(ctx);
}

// Do validation of contentText and/or NSExtensionContext attachments here
- (BOOL)printExtensionItems {
    if (!self || !self.extensionContext) {
        return YES;
    }
    
    // NSLog(@"------ isContentValid ------");
    // NSLog(@"content: %@", self.contentText);
    
    if (self.extensionContext.inputItems) {
        NSLog(@"------");
        NSArray* inputItems = self.extensionContext.inputItems;
        NSLog(@"inputs: %lu", (unsigned long)[self.extensionContext.inputItems count]);
        
        for (NSExtensionItem* inputItem in inputItems) {
            if (inputItem && [inputItem attachments]) {
                NSLog(@"attachments: %lu", [[inputItem attachments] count]);
                
                
                for (NSItemProvider* itemProvider in [inputItem attachments]) {
                
                    if (itemProvider) {
                        NSLog(@"attachment: suggested name: %@", [itemProvider suggestedName]);
                        NSLog(@"          :    description: %@", [itemProvider description]);
                
                        // if ([itemProvider hasItemConformingToTypeIdentifier:@"public.url"]) {
                        //     [itemProvider loadItemForTypeIdentifier:@"public.url" options:nil
                        //                   completionHandler:^(NSURL *url, NSError *error) {
                        //                       NSString *urlString = url.absoluteString;
                        //                       NSLog(@"          :     public url: %@", urlString);
                        //                   }];
                        // }

                        if ([itemProvider hasItemConformingToTypeIdentifier:@"public.image"]) {
                            [itemProvider loadItemForTypeIdentifier:@"public.image" options:nil
                                          completionHandler:^(id<NSSecureCoding> item, NSError *error) {
                                              UIImage *sharedImage = nil;
                                              if([(NSObject*)item isKindOfClass:[NSURL class]]) {
                                                  sharedImage = [UIImage imageWithData:[NSData dataWithContentsOfURL:(NSURL*)item]];
                                                  NSLog(@"          : image from url: %@", sharedImage);
                                              }
                                              
                                              if([(NSObject*)item isKindOfClass:[UIImage class]]) {
                                                  sharedImage = (UIImage*)item;
                                                  NSLog(@"          :    image item: %@", sharedImage);
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
    // This is called after the user selects Post. Do the upload of contentText and/or NSExtensionContext attachments.
    
    // Inform the host that we're done, so it un-blocks its UI. Note: Alternatively you could call super's -didSelectPost, which will similarly complete the extension context.
    [self.extensionContext completeRequestReturningItems:@[] completionHandler:nil];
}

- (NSArray *)configurationItems {
    // To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.
    return @[];
}

@end
