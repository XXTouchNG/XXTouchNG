#import "PassWindow.h"

@implementation PassWindow

+ (BOOL)_isSystemWindow {
    return YES;
}

- (BOOL)_ignoresHitTest {
    return YES;
}

- (BOOL)_usesWindowServerHitTesting {
    return NO;
}

@end
