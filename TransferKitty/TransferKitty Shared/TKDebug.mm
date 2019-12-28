#import "TKDebug.h"

@implementation TKDebug
static NSMutableSet *_debugLoggers;

+ (void)addDebugLogger:(id<TKDebugLogger>)debugLogger {
    if (_debugLoggers == nil) { _debugLoggers = [[NSMutableSet alloc] init]; }
    [_debugLoggers addObject:debugLogger];
}

+ (void)logf:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    NSString *log = [[NSString alloc] initWithFormat:format arguments:args];
    [TKDebug log:log];
    va_end(args);
}

+ (void)log:(NSString *)msg {
    NSLog(@"%@", msg);
    for (id<TKDebugLogger> logger in _debugLoggers) { [logger debugObject:logger didLog:msg]; }
}

+ (void)raise:(NSString *)reason {
    [TKDebug log:reason];
    [[NSException exceptionWithName:@"RuntimeError" reason:reason userInfo:nil] raise];
}

+ (void)checkf:(bool)condition file:(NSString *)file line:(int)line tag:(NSString *)tag format:(NSString *)format, ... {
    va_list args;
    va_start(args, format);
    NSString *msg = [[NSString alloc] initWithFormat:format arguments:args];
    [TKDebug check:condition file:file line:line tag:tag msg:msg];
    va_end(args);
}

+ (void)check:(bool)condition file:(NSString *)file line:(int)line tag:(NSString *)tag msg:(NSString *)msg {
    if (TK_DEBUG && !condition) { [TKDebug raise:[NSString stringWithFormat:@"%@|'%@:%i': %@", tag, file, line, msg]]; }
}

+ (void)dcheckf:(bool)condition
           file:(const char *)file
           line:(int)line
            tag:(const char *)tag
         format:(const char *)format, ... {
    if (TK_DEBUG && !condition) {
        va_list args;
        va_start(args, format);
        NSString *msg = [[NSString alloc] initWithFormat:[NSString stringWithUTF8String:format] arguments:args];
        [TKDebug dcheck:condition file:file line:line tag:tag msg:[msg UTF8String]];
        va_end(args);
    }
}

+ (void)dcheck:(bool)condition file:(const char *)file line:(int)line tag:(const char *)tag msg:(const char *)msg {
    if (TK_DEBUG && !condition) {
        [TKDebug raise:[NSString stringWithFormat:@"[%s] dcheck '%s:%i': %s", tag, file, line, msg]];
    }
}

@end
