#import "UIApplicationRotationFollowingWindow.h"

@interface UIAutoRotatingWindow : UIApplicationRotationFollowingWindow {
    long long _interfaceOrientation;
    BOOL _unknownOrientation;
}

+ (id)sharedPopoverHostingWindow;
- (void)commonInit;
- (id)hitTest:(CGPoint)arg1 withEvent:(id)arg2;
- (void)_didRemoveSubview:(id)arg1;
- (id)_initWithFrame:(CGRect)arg1 attached:(BOOL)arg2;
- (void)updateForOrientation:(long long)arg1;
- (id)_initWithFrame:(CGRect)arg1 debugName:(id)arg2 windowScene:(id)arg3;

@end
