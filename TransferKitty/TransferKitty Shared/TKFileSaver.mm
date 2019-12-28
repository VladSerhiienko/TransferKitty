#import "TKFileSaver.h"
#import "TKDebug.h"

@implementation TKFileSaver
+ (bool)saveFile:(NSString *)fileName fileData:(NSData *)fileData {
    DCHECK(fileName && [fileName length] > 0);
    DCHECK(fileData && [fileData length] > 0);

    NSArray *documentsDirPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    DCHECK(documentsDirPaths && [documentsDirPaths count] > 0);

    NSString *documentsDirPath = [documentsDirPaths objectAtIndex:0];
    DCHECK(documentsDirPath && [documentsDirPath length] > 0);

    NSString *fullFilePath = [NSString stringWithFormat:@"%@/%@", documentsDirPath, fileName];
    DCHECK(fullFilePath && [fullFilePath length] > 0);

    return [fileData writeToFile:fullFilePath atomically:NO];
}
@end
