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
#import "TKExtensionContextUtils.h"

@implementation TKViewController {
    TKAttachmentContext* _attachmentContext;
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
    
    DCHECK(self.extensionContext);
    _attachmentContext = [TKAttachmentContext attachmentContextWithExtensionContext:self.extensionContext];
    
    DCHECK(_attachmentContext);
    [self prepareViewControllerWithAttachmentContext:_attachmentContext];
}
@end

@implementation TKView
- (instancetype)initWithFrame:(CGRect)frameRect device:(nullable id<MTLDevice>)device {
    self = [super initWithFrame:frameRect device:device];
    return self;
}
@end
