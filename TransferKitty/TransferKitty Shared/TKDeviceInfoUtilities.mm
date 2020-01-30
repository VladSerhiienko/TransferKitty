
#import "TKDeviceInfoUtilities.h"

#if TARGET_OS_IOS
#import <UIKit/UIDevice.h>
#else
#include <stdio.h>
#include <stdlib.h>
#include <sys/sysctl.h>
#include <sys/types.h>
#endif

#import <sys/utsname.h>

@implementation TKDeviceInfoUtilities

+ (NSString *)name {
#if TARGET_OS_IOS
    return [[UIDevice currentDevice] name];
#else
    return NSUserName();
#endif
}

+ (NSString *)modelName {
#if 1 // TARGET_OS_IOS
    struct utsname systemInfo;
    uname(&systemInfo);
    return [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
#else
    char model[256] = {0};
    size_t len = 0;
    sysctlbyname("hw.model", model, &len, NULL, 0);
    TK_ASSERT(len && len == strlen(model));
    return [NSString stringWithCString:model encoding:NSUTF8StringEncoding];
#endif
}

+ (NSString *)friendlyModelName {
    NSString *model = [TKDeviceInfoUtilities modelName];

    constexpr auto same = NSOrderedSame;
    TK_STATIC_ASSERT(decltype(same)(kCFCompareEqualTo) == same);

#if TARGET_OS_IOS
    if ([model compare:@"iPhone3,1"] == same) return @"iPhone 4";
    if ([model compare:@"iPhone3,2"] == same) return @"iPhone 4";
    if ([model compare:@"iPhone3,3"] == same) return @"iPhone 4";
    if ([model compare:@"iPhone4,1"] == same) return @"iPhone 4s";
    if ([model compare:@"iPhone5,1"] == same) return @"iPhone 5";
    if ([model compare:@"iPhone5,2"] == same) return @"iPhone 5";
    if ([model compare:@"iPhone5,3"] == same) return @"iPhone 5c";
    if ([model compare:@"iPhone5,4"] == same) return @"iPhone 5c";
    if ([model compare:@"iPhone6,1"] == same) return @"iPhone 5s";
    if ([model compare:@"iPhone6,2"] == same) return @"iPhone 5s";
    if ([model compare:@"iPhone7,2"] == same) return @"iPhone 6";
    if ([model compare:@"iPhone7,1"] == same) return @"iPhone 6 Plus";
    if ([model compare:@"iPhone8,1"] == same) return @"iPhone 6s";
    if ([model compare:@"iPhone8,2"] == same) return @"iPhone 6s Plus";
    if ([model compare:@"iPhone9,1"] == same) return @"iPhone 7";
    if ([model compare:@"iPhone9,3"] == same) return @"iPhone 7";
    if ([model compare:@"iPhone9,2"] == same) return @"iPhone 7 Plus";
    if ([model compare:@"iPhone9,4"] == same) return @"iPhone 7 Plus";
    if ([model compare:@"iPhone8,4"] == same) return @"iPhone SE";
    if ([model compare:@"iPhone10,1"] == same) return @"iPhone 8";
    if ([model compare:@"iPhone10,4"] == same) return @"iPhone 8";
    if ([model compare:@"iPhone10,2"] == same) return @"iPhone 8 Plus";
    if ([model compare:@"iPhone10,5"] == same) return @"iPhone 8 Plus";
    if ([model compare:@"iPhone10,3"] == same) return @"iPhone X";
    if ([model compare:@"iPhone10,6"] == same) return @"iPhone X";
    if ([model compare:@"iPhone11,2"] == same) return @"iPhone XS";
    if ([model compare:@"iPhone11,4"] == same) return @"iPhone XS Max";
    if ([model compare:@"iPhone11,6"] == same) return @"iPhone XS Max";
    if ([model compare:@"iPhone11,8"] == same) return @"iPhone XR";

    if ([model compare:@"iPad2,1"] == same) return @"iPad 2";
    if ([model compare:@"iPad2,2"] == same) return @"iPad 2";
    if ([model compare:@"iPad2,3"] == same) return @"iPad 2";
    if ([model compare:@"iPad2,4"] == same) return @"iPad 2";
    if ([model compare:@"iPad3,1"] == same) return @"iPad 3";
    if ([model compare:@"iPad3,2"] == same) return @"iPad 3";
    if ([model compare:@"iPad3,3"] == same) return @"iPad 3";
    if ([model compare:@"iPad3,4"] == same) return @"iPad 4";
    if ([model compare:@"iPad3,5"] == same) return @"iPad 4";
    if ([model compare:@"iPad3,6"] == same) return @"iPad 4";
    if ([model compare:@"iPad4,1"] == same) return @"iPad Air";
    if ([model compare:@"iPad4,2"] == same) return @"iPad Air";
    if ([model compare:@"iPad4,3"] == same) return @"iPad Air";
    if ([model compare:@"iPad5,3"] == same) return @"iPad Air 2";
    if ([model compare:@"iPad5,4"] == same) return @"iPad Air 2";
    if ([model compare:@"iPad6,11"] == same) return @"iPad 5";
    if ([model compare:@"iPad6,12"] == same) return @"iPad 5";
    if ([model compare:@"iPad7,5"] == same) return @"iPad 6";
    if ([model compare:@"iPad7,6"] == same) return @"iPad 6";
    if ([model compare:@"iPad2,5"] == same) return @"iPad Mini";
    if ([model compare:@"iPad2,6"] == same) return @"iPad Mini";
    if ([model compare:@"iPad2,7"] == same) return @"iPad Mini";
    if ([model compare:@"iPad4,4"] == same) return @"iPad Mini 2";
    if ([model compare:@"iPad4,5"] == same) return @"iPad Mini 2";
    if ([model compare:@"iPad4,6"] == same) return @"iPad Mini 2";
    if ([model compare:@"iPad4,7"] == same) return @"iPad Mini 3";
    if ([model compare:@"iPad4,8"] == same) return @"iPad Mini 3";
    if ([model compare:@"iPad4,9"] == same) return @"iPad Mini 3";
    if ([model compare:@"iPad5,1"] == same) return @"iPad Mini 4";
    if ([model compare:@"iPad5,2"] == same) return @"iPad Mini 4";
    if ([model compare:@"iPad6,3"] == same) return @"iPad Pro (9.7-inch)";
    if ([model compare:@"iPad6,4"] == same) return @"iPad Pro (9.7-inch)";
    if ([model compare:@"iPad6,7"] == same) return @"iPad Pro (12.9-inch)";
    if ([model compare:@"iPad6,8"] == same) return @"iPad Pro (12.9-inch)";
    if ([model compare:@"iPad7,1"] == same) return @"iPad Pro (12.9-inch) (2nd generation)";
    if ([model compare:@"iPad7,2"] == same) return @"iPad Pro (12.9-inch) (2nd generation)";
    if ([model compare:@"iPad7,3"] == same) return @"iPad Pro (10.5-inch)";
    if ([model compare:@"iPad7,4"] == same) return @"iPad Pro (10.5-inch)";
    if ([model compare:@"iPad8,1"] == same) return @"iPad Pro (11-inch)";
    if ([model compare:@"iPad8,2"] == same) return @"iPad Pro (11-inch)";
    if ([model compare:@"iPad8,3"] == same) return @"iPad Pro (11-inch)";
    if ([model compare:@"iPad8,4"] == same) return @"iPad Pro (11-inch)";
    if ([model compare:@"iPad8,5"] == same) return @"iPad Pro (12.9-inch) (3rd generation)";
    if ([model compare:@"iPad8,6"] == same) return @"iPad Pro (12.9-inch) (3rd generation)";
    if ([model compare:@"iPad8,7"] == same) return @"iPad Pro (12.9-inch) (3rd generation)";
    if ([model compare:@"iPad8,8"] == same) return @"iPad Pro (12.9-inch) (3rd generation)";

    if ([model compare:@"iPod5,1"] == same) return @"iPod Touch 5";
    if ([model compare:@"iPod7,1"] == same) return @"iPod Touch 6";

    if ([model compare:@"AppleTV5,3"] == same) return @"Apple TV";
    if ([model compare:@"AppleTV6,2"] == same) return @"Apple TV 4K";

    if ([model compare:@"AudioAccessory1,1"] == same) return @"HomePod";

    if ([model compare:@"i386"] == same) return @"Simulator";
    if ([model compare:@"x86_64"] == same) return @"Simulator";

    if ([model compare:@"iPhone" options:NSCaseInsensitiveSearch range:NSMakeRange(0, 6)] == same) return @"iPhone";
    if ([model compare:@"iPad" options:NSCaseInsensitiveSearch range:NSMakeRange(0, 4)] == same) return @"iPad";
    if ([model compare:@"iPod" options:NSCaseInsensitiveSearch range:NSMakeRange(0, 4)] == same) return @"iPod";
    if ([model compare:@"AppleTV" options:NSCaseInsensitiveSearch range:NSMakeRange(0, 7)] == same) return @"AppleTV";
    if ([model compare:@"AudioAccessory" options:NSCaseInsensitiveSearch range:NSMakeRange(0, 14)] == same)
        return @"HomePod";
#endif

    return model;
}

//+ (NSString *)getName;
//+ (NSString *)getModelName;
//+ (NSString *)getFriendlyModelName;
@end
