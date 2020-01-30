//
//  ShareViewController.m
//  TransferKitty ShareExtension macOS
//
//  Created by Vladyslav Serhiienko on 11/2/19.
//  Copyright © 2019 vserhiienko. All rights reserved.
//

#import "TKViewController.h"
#import "TKExtensionContextUtils.h"

@implementation TKViewController {
    TKAttachmentContext *_context;
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
}
- (void)viewDidAppear {
    [super viewDidAppear];

    DCHECK(self.extensionContext);
    if (self.extensionContext) {
        _context = [TKAttachmentContext attachmentContextWithExtensionContext:self.extensionContext];
        [_context prepareNames];
        [_context prepareBuffers];
        DCHECK(_context);
    }

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
