#import "UIApplicationRotationFollowingController.h"

@interface UIApplicationRotationFollowingControllerNoTouches : UIApplicationRotationFollowingController

- (void)loadView;
- (void)_prepareForRotationToOrientation:(long long)arg1 duration:(double)arg2;
- (void)_rotateToOrientation:(long long)arg1 duration:(double)arg2;
- (void)_finishRotationFromInterfaceOrientation:(long long)arg1;
@end
