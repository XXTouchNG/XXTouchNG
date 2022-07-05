#import "IOKitSPI.h"

OBJC_EXTERN BOOL HIDRecorderHandleHIDEvent(IOHIDEventRef event);
OBJC_EXTERN void HIDRecorderInitializeDefaults(void);
OBJC_EXTERN BOOL _recorderInsomniaModeEnabled;

@interface SBBacklightController : NSObject
- (void)allowIdleSleep;
- (void)preventIdleSleep;
@end

%group SpringBoard

%hook SpringBoard
- (BOOL)__handleHIDEvent:(IOHIDEventRef)arg1 withUIEvent:(id)arg2
{
    // %log;
	BOOL handled = HIDRecorderHandleHIDEvent(arg1);
	if (handled) {
		return NO;
	}
	return %orig;
}
- (BOOL)__handleHIDEvent:(IOHIDEventRef)arg1
{
    // %log;
	BOOL handled = HIDRecorderHandleHIDEvent(arg1);
	if (handled) {
		return NO;
	}
	return %orig;
}
%end

%hook SBBacklightController
- (void)allowIdleSleep
{
    %log;
    if (_recorderInsomniaModeEnabled) {
        // [self preventIdleSleep];
        return;
    }
    %orig;
}
- (void)preventIdleSleep
{
    %log;
    %orig;
}
%end

%end

%ctor {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
	%init(SpringBoard);
#pragma clang diagnostic pop
}
