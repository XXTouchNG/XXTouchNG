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

- (void)setupOrientation:(UIInterfaceOrientation)arg1 {
    [super updateForOrientation:arg1];
}

- (void)updateForOrientation:(UIInterfaceOrientation)arg1 {
    /* To use auto rotation, assign a root view controller to UIWindow, and add subviews to that view. */
    /* Otherwise, add subviews directly to the UIWindow. */
}

@end
