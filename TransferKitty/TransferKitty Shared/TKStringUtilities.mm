#import "TKStringUtilities.h"

@implementation TKStringUtilities
static NSString *emptyStringInstance = @"";
+ (NSString *)empty {
    DCHECK(emptyStringInstance && [emptyStringInstance length] == 0);
    return emptyStringInstance;
}
+ (bool)isNilOrEmpty:(NSString *)string {
    return !string || (0 == [string length]);
}

+ (NSString *)stringOrEmptyString:(NSString *)nullableString {
    if (nullableString == nil) { return [TKStringUtilities empty]; }
    return nullableString;
}

+ (NSString *)uuidStringOrEmptyString:(NSUUID *)nullableUUID {
    if (nullableUUID == nil) { return [TKStringUtilities empty]; }
    return [nullableUUID UUIDString];
}

@end
