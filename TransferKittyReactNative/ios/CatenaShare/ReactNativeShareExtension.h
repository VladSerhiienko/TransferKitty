#import <UIKit/UIKit.h>
#import <React/RCTBridgeModule.h>

@interface ShareViewController : UIViewController<RCTBridgeModule>
- (UIView*) shareView;
@end
