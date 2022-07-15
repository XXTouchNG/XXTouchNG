#line 1 "HIDRecorder.x"
#import "IOKitSPI.h"

OBJC_EXTERN BOOL HIDRecorderHandleHIDEvent(IOHIDEventRef event);
OBJC_EXTERN void HIDRecorderInitializeDefaults(void);
OBJC_EXTERN BOOL _recorderInsomniaModeEnabled;

@interface SBBacklightController : NSObject
- (void)allowIdleSleep;
- (void)preventIdleSleep;
@end


#include <substrate.h>
#if defined(__clang__)
#if __has_feature(objc_arc)
#define _LOGOS_SELF_TYPE_NORMAL __unsafe_unretained
#define _LOGOS_SELF_TYPE_INIT __attribute__((ns_consumed))
#define _LOGOS_SELF_CONST const
#define _LOGOS_RETURN_RETAINED __attribute__((ns_returns_retained))
#else
#define _LOGOS_SELF_TYPE_NORMAL
#define _LOGOS_SELF_TYPE_INIT
#define _LOGOS_SELF_CONST
#define _LOGOS_RETURN_RETAINED
#endif
#else
#define _LOGOS_SELF_TYPE_NORMAL
#define _LOGOS_SELF_TYPE_INIT
#define _LOGOS_SELF_CONST
#define _LOGOS_RETURN_RETAINED
#endif

@class SBBacklightController; @class SpringBoard; 


#line 12 "HIDRecorder.x"
static BOOL (*_logos_orig$SpringBoard$SpringBoard$__handleHIDEvent$withUIEvent$)(_LOGOS_SELF_TYPE_NORMAL SpringBoard* _LOGOS_SELF_CONST, SEL, IOHIDEventRef, id); static BOOL _logos_method$SpringBoard$SpringBoard$__handleHIDEvent$withUIEvent$(_LOGOS_SELF_TYPE_NORMAL SpringBoard* _LOGOS_SELF_CONST, SEL, IOHIDEventRef, id); static BOOL (*_logos_orig$SpringBoard$SpringBoard$__handleHIDEvent$)(_LOGOS_SELF_TYPE_NORMAL SpringBoard* _LOGOS_SELF_CONST, SEL, IOHIDEventRef); static BOOL _logos_method$SpringBoard$SpringBoard$__handleHIDEvent$(_LOGOS_SELF_TYPE_NORMAL SpringBoard* _LOGOS_SELF_CONST, SEL, IOHIDEventRef); static void (*_logos_orig$SpringBoard$SBBacklightController$allowIdleSleep)(_LOGOS_SELF_TYPE_NORMAL SBBacklightController* _LOGOS_SELF_CONST, SEL); static void _logos_method$SpringBoard$SBBacklightController$allowIdleSleep(_LOGOS_SELF_TYPE_NORMAL SBBacklightController* _LOGOS_SELF_CONST, SEL); static void (*_logos_orig$SpringBoard$SBBacklightController$preventIdleSleep)(_LOGOS_SELF_TYPE_NORMAL SBBacklightController* _LOGOS_SELF_CONST, SEL); static void _logos_method$SpringBoard$SBBacklightController$preventIdleSleep(_LOGOS_SELF_TYPE_NORMAL SBBacklightController* _LOGOS_SELF_CONST, SEL); 



static BOOL _logos_method$SpringBoard$SpringBoard$__handleHIDEvent$withUIEvent$(_LOGOS_SELF_TYPE_NORMAL SpringBoard* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, IOHIDEventRef arg1, id arg2) {
    
	BOOL handled = HIDRecorderHandleHIDEvent(arg1);
	if (handled) {
		return NO;
	}
	return _logos_orig$SpringBoard$SpringBoard$__handleHIDEvent$withUIEvent$(self, _cmd, arg1, arg2);
}

static BOOL _logos_method$SpringBoard$SpringBoard$__handleHIDEvent$(_LOGOS_SELF_TYPE_NORMAL SpringBoard* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, IOHIDEventRef arg1) {
    
	BOOL handled = HIDRecorderHandleHIDEvent(arg1);
	if (handled) {
		return NO;
	}
	return _logos_orig$SpringBoard$SpringBoard$__handleHIDEvent$(self, _cmd, arg1);
}




static void _logos_method$SpringBoard$SBBacklightController$allowIdleSleep(_LOGOS_SELF_TYPE_NORMAL SBBacklightController* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd) {
    NSLog(@"-[<SBBacklightController: %p> allowIdleSleep]", self);
    if (_recorderInsomniaModeEnabled) {
        
        return;
    }
    _logos_orig$SpringBoard$SBBacklightController$allowIdleSleep(self, _cmd);
}

static void _logos_method$SpringBoard$SBBacklightController$preventIdleSleep(_LOGOS_SELF_TYPE_NORMAL SBBacklightController* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd) {
    NSLog(@"-[<SBBacklightController: %p> preventIdleSleep]", self);
    _logos_orig$SpringBoard$SBBacklightController$preventIdleSleep(self, _cmd);
}




static __attribute__((constructor)) void _logosLocalCtor_0ee48178(int __unused argc, char __unused **argv, char __unused **envp) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
	{Class _logos_class$SpringBoard$SpringBoard = objc_getClass("SpringBoard"); { MSHookMessageEx(_logos_class$SpringBoard$SpringBoard, @selector(__handleHIDEvent:withUIEvent:), (IMP)&_logos_method$SpringBoard$SpringBoard$__handleHIDEvent$withUIEvent$, (IMP*)&_logos_orig$SpringBoard$SpringBoard$__handleHIDEvent$withUIEvent$);}{ MSHookMessageEx(_logos_class$SpringBoard$SpringBoard, @selector(__handleHIDEvent:), (IMP)&_logos_method$SpringBoard$SpringBoard$__handleHIDEvent$, (IMP*)&_logos_orig$SpringBoard$SpringBoard$__handleHIDEvent$);}Class _logos_class$SpringBoard$SBBacklightController = objc_getClass("SBBacklightController"); { MSHookMessageEx(_logos_class$SpringBoard$SBBacklightController, @selector(allowIdleSleep), (IMP)&_logos_method$SpringBoard$SBBacklightController$allowIdleSleep, (IMP*)&_logos_orig$SpringBoard$SBBacklightController$allowIdleSleep);}{ MSHookMessageEx(_logos_class$SpringBoard$SBBacklightController, @selector(preventIdleSleep), (IMP)&_logos_method$SpringBoard$SBBacklightController$preventIdleSleep, (IMP*)&_logos_orig$SpringBoard$SBBacklightController$preventIdleSleep);}}
#pragma clang diagnostic pop
}
