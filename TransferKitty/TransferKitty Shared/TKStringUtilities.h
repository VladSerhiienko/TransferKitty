#pragma once

#import <Foundation/Foundation.h>
#include "TKConfig.h"

@interface TKStringUtilities : NSObject
+ (NSString *)empty;
+ (bool)isNilOrEmpty:(NSString *)string;
+ (NSString *)stringOrEmptyString:(NSString *)maybeNullString;
+ (NSString *)uuidStringOrEmptyString:(NSUUID *)maybeNullUUID;
@end
