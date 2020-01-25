#import "ReactNativeShareExtension.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <React/RCTBundleURLProvider.h>
#import <React/RCTRootView.h>

#define URL_IDENTIFIER @"public.url"
#define IMAGE_IDENTIFIER @"public.image"
#define TEXT_IDENTIFIER (NSString *)kUTTypePlainText

NSExtensionContext* extensionContext;

@implementation ReactNativeShareExtension {
    NSTimer *autoTimer;
    NSString* type;
    NSString* value;
}

- (UIView*) shareView {
    NSURL *jsCodeLocation;

    jsCodeLocation = [[RCTBundleURLProvider sharedSettings] jsBundleURLForBundleRoot:@"share.ios" fallbackResource:nil];

    NSDictionary *initialProps = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool: TRUE] forKey:@"isShareExtension"];
    RCTRootView *rootView = [[RCTRootView alloc] initWithBundleURL:jsCodeLocation
                                                        moduleName:@"CatenaShare"
                                                 initialProperties:initialProps
                                                     launchOptions:nil];
    rootView.backgroundColor = nil;

    // Uncomment for console output in Xcode console for release mode on device:
//     RCTSetLogThreshold(RCTLogLevelInfo - 1);
    
    return rootView;
}

RCT_EXPORT_MODULE();

- (void)viewDidLoad {
  [super viewDidLoad];
  extensionContext = self.extensionContext;
  UIView *rootView = [self shareView];
  if (rootView.backgroundColor == nil) {
    rootView.backgroundColor = [[UIColor alloc] initWithRed:1 green:1 blue:1 alpha:0.1];
  }
  
  self.view = rootView;
}

- (BOOL) requiresMainQueueSetup
{
  return NO;
}


RCT_EXPORT_METHOD(close) {
  [extensionContext completeRequestReturningItems:nil
                                completionHandler:nil];
}

@end
