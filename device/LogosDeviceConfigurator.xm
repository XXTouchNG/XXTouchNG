#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

@class BBServer;

BBServer *_sharedBBServer = nil;
dispatch_queue_t _sharedBBServerQueue = nil;

%group BulletinBoard

%hook BBServer

- (id)initWithQueue:(id)arg1
{
    %log;
    _sharedBBServer = %orig;
    _sharedBBServerQueue = arg1;
    return _sharedBBServer;
}

- (id)initWithQueue:(id)arg1 dataProviderManager:(id)arg2 syncService:(id)arg3 dismissalSyncCache:(id)arg4 observerListener:(id)arg5 conduitListener:(id)arg6 settingsListener:(id)arg7
{
    %log;
    _sharedBBServer = %orig;
    _sharedBBServerQueue = arg1;
    return _sharedBBServer;
}

- (void)_publishBulletinRequest:(id)arg1 forSectionID:(id)arg2 forDestinations:(unsigned long long)arg3
{
    %log;
    %orig;
}

%end

%end

%group SpringBoard

SBRingerControl *_globalRingerControl = nil;
SBDisplayBrightnessController *_globalBrightnessController = nil;

%hook SBRingerControl
- (instancetype)initWithHUDController:(id)arg1 soundController:(id)arg2 {
    %log;
	_globalRingerControl = %orig;
	return _globalRingerControl;
}
%end

%hook SBDisplayBrightnessController
- (instancetype)init {
    %log;
	_globalBrightnessController = %orig;
	return _globalBrightnessController;
}
%end

%end

%group AvoidCrash

%hook AXMotionController
- (void)_updateReduceSlideTransitionsSpecifiersAnimated:(BOOL)arg1 {
    %log;
}
%end

%end

OBJC_EXTERN void reinitializeHooks(void);
OBJC_EXTERN void reinitializeHooks()
{
    %init(AvoidCrash);
}

%ctor {
    %init(BulletinBoard);
    %init(SpringBoard);
}
