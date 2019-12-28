#pragma once

#ifdef __OBJC__
#import <Foundation/Foundation.h>

@interface TKFileSaver : NSObject
+ (bool)saveFile:(NSString *)fileName fileData:(NSData *)fileData;
@end

#endif // __OBJC__
