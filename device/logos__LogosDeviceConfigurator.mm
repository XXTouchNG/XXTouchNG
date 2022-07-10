#line 1 "LogosDeviceConfigurator.xm"
#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

@class BBServer;

BBServer *_sharedBBServer = nil;
dispatch_queue_t _sharedBBServerQueue = nil;


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

@class SBRingerControl; @class AXMotionController; @class BBServer; @class SBDisplayBrightnessController; 


#line 10 "LogosDeviceConfigurator.xm"
static BBServer* (*_logos_orig$BulletinBoard$BBServer$initWithQueue$)(_LOGOS_SELF_TYPE_INIT BBServer*, SEL, id) _LOGOS_RETURN_RETAINED; static BBServer* _logos_method$BulletinBoard$BBServer$initWithQueue$(_LOGOS_SELF_TYPE_INIT BBServer*, SEL, id) _LOGOS_RETURN_RETAINED; static BBServer* (*_logos_orig$BulletinBoard$BBServer$initWithQueue$dataProviderManager$syncService$dismissalSyncCache$observerListener$conduitListener$settingsListener$)(_LOGOS_SELF_TYPE_INIT BBServer*, SEL, id, id, id, id, id, id, id) _LOGOS_RETURN_RETAINED; static BBServer* _logos_method$BulletinBoard$BBServer$initWithQueue$dataProviderManager$syncService$dismissalSyncCache$observerListener$conduitListener$settingsListener$(_LOGOS_SELF_TYPE_INIT BBServer*, SEL, id, id, id, id, id, id, id) _LOGOS_RETURN_RETAINED; static void (*_logos_orig$BulletinBoard$BBServer$_publishBulletinRequest$forSectionID$forDestinations$)(_LOGOS_SELF_TYPE_NORMAL BBServer* _LOGOS_SELF_CONST, SEL, id, id, unsigned long long); static void _logos_method$BulletinBoard$BBServer$_publishBulletinRequest$forSectionID$forDestinations$(_LOGOS_SELF_TYPE_NORMAL BBServer* _LOGOS_SELF_CONST, SEL, id, id, unsigned long long); 




static BBServer* _logos_method$BulletinBoard$BBServer$initWithQueue$(_LOGOS_SELF_TYPE_INIT BBServer* __unused self, SEL __unused _cmd, id arg1) _LOGOS_RETURN_RETAINED {
    NSLog(@"-[<BBServer: %p> initWithQueue:%@]", self, arg1);
    _sharedBBServer = _logos_orig$BulletinBoard$BBServer$initWithQueue$(self, _cmd, arg1);
    _sharedBBServerQueue = arg1;
    return _sharedBBServer;
}


static BBServer* _logos_method$BulletinBoard$BBServer$initWithQueue$dataProviderManager$syncService$dismissalSyncCache$observerListener$conduitListener$settingsListener$(_LOGOS_SELF_TYPE_INIT BBServer* __unused self, SEL __unused _cmd, id arg1, id arg2, id arg3, id arg4, id arg5, id arg6, id arg7) _LOGOS_RETURN_RETAINED {
    NSLog(@"-[<BBServer: %p> initWithQueue:%@ dataProviderManager:%@ syncService:%@ dismissalSyncCache:%@ observerListener:%@ conduitListener:%@ settingsListener:%@]", self, arg1, arg2, arg3, arg4, arg5, arg6, arg7);
    _sharedBBServer = _logos_orig$BulletinBoard$BBServer$initWithQueue$dataProviderManager$syncService$dismissalSyncCache$observerListener$conduitListener$settingsListener$(self, _cmd, arg1, arg2, arg3, arg4, arg5, arg6, arg7);
    _sharedBBServerQueue = arg1;
    return _sharedBBServer;
}


static void _logos_method$BulletinBoard$BBServer$_publishBulletinRequest$forSectionID$forDestinations$(_LOGOS_SELF_TYPE_NORMAL BBServer* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, id arg1, id arg2, unsigned long long arg3) {
    NSLog(@"-[<BBServer: %p> _publishBulletinRequest:%@ forSectionID:%@ forDestinations:%llu]", self, arg1, arg2, arg3);
    _logos_orig$BulletinBoard$BBServer$_publishBulletinRequest$forSectionID$forDestinations$(self, _cmd, arg1, arg2, arg3);
}





static SBRingerControl* (*_logos_orig$SpringBoard$SBRingerControl$initWithHUDController$soundController$)(_LOGOS_SELF_TYPE_INIT SBRingerControl*, SEL, id, id) _LOGOS_RETURN_RETAINED; static SBRingerControl* _logos_method$SpringBoard$SBRingerControl$initWithHUDController$soundController$(_LOGOS_SELF_TYPE_INIT SBRingerControl*, SEL, id, id) _LOGOS_RETURN_RETAINED; static SBDisplayBrightnessController* (*_logos_orig$SpringBoard$SBDisplayBrightnessController$init)(_LOGOS_SELF_TYPE_INIT SBDisplayBrightnessController*, SEL) _LOGOS_RETURN_RETAINED; static SBDisplayBrightnessController* _logos_method$SpringBoard$SBDisplayBrightnessController$init(_LOGOS_SELF_TYPE_INIT SBDisplayBrightnessController*, SEL) _LOGOS_RETURN_RETAINED; 

SBRingerControl *_globalRingerControl = nil;
SBDisplayBrightnessController *_globalBrightnessController = nil;


static SBRingerControl* _logos_method$SpringBoard$SBRingerControl$initWithHUDController$soundController$(_LOGOS_SELF_TYPE_INIT SBRingerControl* __unused self, SEL __unused _cmd, id arg1, id arg2) _LOGOS_RETURN_RETAINED {
    NSLog(@"-[<SBRingerControl: %p> initWithHUDController:%@ soundController:%@]", self, arg1, arg2);
	_globalRingerControl = _logos_orig$SpringBoard$SBRingerControl$initWithHUDController$soundController$(self, _cmd, arg1, arg2);
	return _globalRingerControl;
}



static SBDisplayBrightnessController* _logos_method$SpringBoard$SBDisplayBrightnessController$init(_LOGOS_SELF_TYPE_INIT SBDisplayBrightnessController* __unused self, SEL __unused _cmd) _LOGOS_RETURN_RETAINED {
    NSLog(@"-[<SBDisplayBrightnessController: %p> init]", self);
	_globalBrightnessController = _logos_orig$SpringBoard$SBDisplayBrightnessController$init(self, _cmd);
	return _globalBrightnessController;
}




static void (*_logos_orig$AvoidCrash$AXMotionController$_updateReduceSlideTransitionsSpecifiersAnimated$)(_LOGOS_SELF_TYPE_NORMAL AXMotionController* _LOGOS_SELF_CONST, SEL, BOOL); static void _logos_method$AvoidCrash$AXMotionController$_updateReduceSlideTransitionsSpecifiersAnimated$(_LOGOS_SELF_TYPE_NORMAL AXMotionController* _LOGOS_SELF_CONST, SEL, BOOL); 


static void _logos_method$AvoidCrash$AXMotionController$_updateReduceSlideTransitionsSpecifiersAnimated$(_LOGOS_SELF_TYPE_NORMAL AXMotionController* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, BOOL arg1) {
    NSLog(@"-[<AXMotionController: %p> _updateReduceSlideTransitionsSpecifiersAnimated:%d]", self, arg1);
}




OBJC_EXTERN void reinitializeHooks(void);
OBJC_EXTERN void reinitializeHooks()
{
    {Class _logos_class$AvoidCrash$AXMotionController = objc_getClass("AXMotionController"); { MSHookMessageEx(_logos_class$AvoidCrash$AXMotionController, @selector(_updateReduceSlideTransitionsSpecifiersAnimated:), (IMP)&_logos_method$AvoidCrash$AXMotionController$_updateReduceSlideTransitionsSpecifiersAnimated$, (IMP*)&_logos_orig$AvoidCrash$AXMotionController$_updateReduceSlideTransitionsSpecifiersAnimated$);}}
}

static __attribute__((constructor)) void _logosLocalCtor_0688566e(int __unused argc, char __unused **argv, char __unused **envp) {
    {Class _logos_class$BulletinBoard$BBServer = objc_getClass("BBServer"); { MSHookMessageEx(_logos_class$BulletinBoard$BBServer, @selector(initWithQueue:), (IMP)&_logos_method$BulletinBoard$BBServer$initWithQueue$, (IMP*)&_logos_orig$BulletinBoard$BBServer$initWithQueue$);}{ MSHookMessageEx(_logos_class$BulletinBoard$BBServer, @selector(initWithQueue:dataProviderManager:syncService:dismissalSyncCache:observerListener:conduitListener:settingsListener:), (IMP)&_logos_method$BulletinBoard$BBServer$initWithQueue$dataProviderManager$syncService$dismissalSyncCache$observerListener$conduitListener$settingsListener$, (IMP*)&_logos_orig$BulletinBoard$BBServer$initWithQueue$dataProviderManager$syncService$dismissalSyncCache$observerListener$conduitListener$settingsListener$);}{ MSHookMessageEx(_logos_class$BulletinBoard$BBServer, @selector(_publishBulletinRequest:forSectionID:forDestinations:), (IMP)&_logos_method$BulletinBoard$BBServer$_publishBulletinRequest$forSectionID$forDestinations$, (IMP*)&_logos_orig$BulletinBoard$BBServer$_publishBulletinRequest$forSectionID$forDestinations$);}}
    {Class _logos_class$SpringBoard$SBRingerControl = objc_getClass("SBRingerControl"); { MSHookMessageEx(_logos_class$SpringBoard$SBRingerControl, @selector(initWithHUDController:soundController:), (IMP)&_logos_method$SpringBoard$SBRingerControl$initWithHUDController$soundController$, (IMP*)&_logos_orig$SpringBoard$SBRingerControl$initWithHUDController$soundController$);}Class _logos_class$SpringBoard$SBDisplayBrightnessController = objc_getClass("SBDisplayBrightnessController"); { MSHookMessageEx(_logos_class$SpringBoard$SBDisplayBrightnessController, @selector(init), (IMP)&_logos_method$SpringBoard$SBDisplayBrightnessController$init, (IMP*)&_logos_orig$SpringBoard$SBDisplayBrightnessController$init);}}
}
