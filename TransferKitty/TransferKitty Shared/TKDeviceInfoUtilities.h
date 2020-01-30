#pragma once

#import <Foundation/Foundation.h>
#include "TKConfig.h"

@interface TKDeviceInfoUtilities : NSObject
+ (NSString *)name;
+ (NSString *)modelName;
+ (NSString *)friendlyModelName;
@end
