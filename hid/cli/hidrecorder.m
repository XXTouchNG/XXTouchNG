//
//  hidrecorder.m
//  HIDRecorder
//
//  Created by Darwin on 2022/3/9.
//

#import <Foundation/Foundation.h>
#import <unistd.h>
#import <signal.h>
#import <dlfcn.h>

#import "kern_memorystatus.h"

#import "ProcQueue.h"
#import "IOKitSPI.h"


#pragma mark - Types

typedef NS_ENUM(NSUInteger, HIDRecorderRecordOption) {
    HIDRecorderRecordOptionRecordNone = 0,
    HIDRecorderRecordOptionRecordVolumeUp,
    HIDRecorderRecordOptionRecordVolumeDown,
    HIDRecorderRecordOptionRecordVolumeBoth,
};

typedef IOReturn IOMobileFramebufferReturn;
typedef void *IOMobileFramebufferRef;

OBJC_EXTERN
IOMobileFramebufferReturn IOMobileFramebufferGetMainDisplay(IOMobileFramebufferRef *pointer);

OBJC_EXTERN
void IOMobileFramebufferGetDisplaySize(IOMobileFramebufferRef connect, CGSize *size);


#pragma mark - Variables

static CGSize _screenSize;
static CGRect _screenBounds;
static dispatch_queue_t _outputQueue;
static NSMutableIndexSet *_touchIndexes = nil;
static NSMutableIndexSet *_keyIndexes = nil;
static uint64_t _lastAbsStamp = 0;
static NSTimeInterval _lastTimeStamp = -1;
static BOOL _requiresBreak = NO;
static HIDRecorderRecordOption _recorderOption = HIDRecorderRecordOptionRecordNone;


#pragma mark - Helper Functions

NS_INLINE NSTimeInterval IOHIDAbsoluteTimeToTimeInterval(uint64_t abs) {
    static mach_timebase_info_data_t timebase;
    if (!timebase.denom) {
        mach_timebase_info(&timebase);
    }
    return (abs * timebase.numer) / (double)(timebase.denom) / 1e9;
}

static void _PrintNSString(NSString *line, BOOL sync)
{
    if (sync) {
        dispatch_sync(_outputQueue, ^{
            fputs([line UTF8String], stdout);
            fflush(stdout);
        });
    } else {
        dispatch_async(_outputQueue, ^{
            fputs([line UTF8String], stdout);
            fflush(stdout);
        });
    }
}

static NSDictionary *HIDRecorderDictionaryFromIOHIDEvent(IOHIDEventRef event, CGRect refBounds, HIDRecorderRecordOption option)
{
    @autoreleasepool {
        if (IOHIDEventGetType(event) == kIOHIDEventTypeKeyboard)
        {
            uint64_t timestamp = IOHIDEventGetTimeStamp(event);
            
            CFIndex keyboardUsagePage = IOHIDEventGetIntegerValue(event, kIOHIDEventFieldKeyboardUsagePage);
            CFIndex keyboardUsage = IOHIDEventGetIntegerValue(event, kIOHIDEventFieldKeyboardUsage);
            CFIndex keyboardIsDown = IOHIDEventGetIntegerValue(event, kIOHIDEventFieldKeyboardDown);
            
            if (option == HIDRecorderRecordOptionRecordNone) {
                // no volume up & down
                if (keyboardUsagePage == kHIDPage_Consumer &&
                    (keyboardUsage == kHIDUsage_Csmr_VolumeDecrement ||
                     keyboardUsage == kHIDUsage_Csmr_VolumeIncrement))
                {
                    return nil;
                }
            }
            else if (option == HIDRecorderRecordOptionRecordVolumeUp) {
                // no volume down
                if (keyboardUsagePage == kHIDPage_Consumer && keyboardUsage == kHIDUsage_Csmr_VolumeDecrement)
                {
                    return nil;
                }
            }
            else if (option == HIDRecorderRecordOptionRecordVolumeDown) {
                // no volume up
                if (keyboardUsagePage == kHIDPage_Consumer && keyboardUsage == kHIDUsage_Csmr_VolumeIncrement)
                {
                    return nil;
                }
            }
            
            return @{
                @"type": @"key",
                @"timestamp": @(timestamp),
                @"data": @{
                    @"page": @(keyboardUsagePage),
                    @"usage": @(keyboardUsage),
                    @"down": @((BOOL)keyboardIsDown),
                },
            };
        }
        else if (IOHIDEventGetType(event) == kIOHIDEventTypeDigitizer)
        {
            CFIndex isBuiltIn = IOHIDEventGetIntegerValue(event, kIOHIDEventFieldIsBuiltIn);
            if (!isBuiltIn) {
                return nil;
            }
            
            CFIndex isDisplayIntegrated = IOHIDEventGetIntegerValue(event, kIOHIDEventFieldDigitizerIsDisplayIntegrated);
            if (!isDisplayIntegrated) {
                return nil;
            }
            
            CFIndex digitizerType = IOHIDEventGetIntegerValue(event, kIOHIDEventFieldDigitizerType);
            if (digitizerType != kIOHIDDigitizerTransducerTypeHand) {
                return nil;
            }
            
            uint64_t timestamp = IOHIDEventGetTimeStamp(event);
            
            CFArrayRef subevents = IOHIDEventGetChildren(event);
            if (!subevents) {
                CHDebugLogSource(@"%@", event);
                return nil;
            }
            
            CFIndex eventCount = CFArrayGetCount(subevents);
            NSMutableArray <NSDictionary *> *childEvents = [NSMutableArray arrayWithCapacity:eventCount];
            
            for (CFIndex i = 0; i < eventCount; i++) {
                IOHIDEventRef childEvent = (IOHIDEventRef)CFArrayGetValueAtIndex(subevents, i);
                
                CFIndex childDigitizerType = IOHIDEventGetIntegerValue(childEvent, kIOHIDEventFieldDigitizerType);
                if (childDigitizerType != kIOHIDDigitizerTransducerTypeFinger)
                    continue;
                
                CFIndex index = IOHIDEventGetIntegerValue(childEvent, kIOHIDEventFieldDigitizerIndex);
                CFIndex isTouch = IOHIDEventGetIntegerValue(childEvent, kIOHIDEventFieldDigitizerTouch);
                CFIndex isRange = IOHIDEventGetIntegerValue(childEvent, kIOHIDEventFieldDigitizerRange);
                
                /* IMPORTANT: screen edge swipe event mask */
                CFIndex eventMask = (uint32_t)IOHIDEventGetIntegerValue(childEvent, kIOHIDEventFieldDigitizerEventMask);
                CFIndex swipeMask = (eventMask & kIOHIDDigitizerEventSwipeMask) >> 16;
                
                IOHIDFloat positionX = IOHIDEventGetFloatValue(childEvent, kIOHIDEventFieldDigitizerX);
                IOHIDFloat positionY = IOHIDEventGetFloatValue(childEvent, kIOHIDEventFieldDigitizerY);
                
                IOHIDFloat pressure = IOHIDEventGetFloatValue(childEvent, kIOHIDEventFieldDigitizerPressure);
                IOHIDFloat twist = IOHIDEventGetFloatValue(childEvent, kIOHIDEventFieldDigitizerTwist);
                
                if (CGRectIsNull(refBounds)) {
                    [childEvents addObject:@{
                        @"index": @(index),
                        @"touch": @((BOOL)isTouch),
                        @"range": @((BOOL)isRange),
                        @"x": @(positionX),
                        @"y": @(positionY),
                        @"pressure": @(pressure),
                        @"twist": @(twist),
                        @"smsk": @(swipeMask),
                        @"emsk": @(eventMask),
                    }];
                } else {
                    [childEvents addObject:@{
                        @"index": @(index),
                        @"touch": @((BOOL)isTouch),
                        @"range": @((BOOL)isRange),
                        @"x": @(refBounds.origin.x + positionX * refBounds.size.width),
                        @"y": @(refBounds.origin.y + positionY * refBounds.size.height),
                        @"pressure": @(pressure),
                        @"twist": @(twist),
                        @"smsk": @(swipeMask),
                        @"emsk": @(eventMask),
                    }];
                }
            }
            
            return @{
                @"type": @"touch",
                @"timestamp": @(timestamp),
                @"data": childEvents,
            };
        }
        
        return nil;
    }
}


#pragma mark - Event Loop

static void _HandleHIDSystemEvent(void* target, void* refcon, IOHIDEventQueueRef queue, IOHIDEventRef event)
{
    @autoreleasepool {
        NSDictionary *eventDict = HIDRecorderDictionaryFromIOHIDEvent(event, _screenBounds, _recorderOption);
        if (!eventDict) {
            return;
        }
        
        CHLog(@"%@", eventDict);
        
        if (![eventDict[@"type"] isKindOfClass:[NSString class]])
            return;
        
        if (![eventDict[@"timestamp"] isKindOfClass:[NSNumber class]])
            return;
        
        if (![eventDict[@"data"] isKindOfClass:[NSDictionary class]] &&
            ![eventDict[@"data"] isKindOfClass:[NSArray class]])
            return;
        
        uint64_t absStamp = [eventDict[@"timestamp"] unsignedLongLongValue];
        
        // skip event at the exactly same time
        if (_lastAbsStamp > 0 && absStamp == _lastAbsStamp)
            return;
        
        NSTimeInterval currentStamp = IOHIDAbsoluteTimeToTimeInterval(absStamp);
        
        // touch event
        if ([eventDict[@"type"] isEqualToString:@"touch"])
        {
            NSArray <NSDictionary *> *eventData = eventDict[@"data"];
            if (![eventData isKindOfClass:[NSArray class]])
                return;
            
            BOOL hasValidTouch = NO;
            for (NSDictionary *subeventData in eventData) {
                if (![subeventData isKindOfClass:[NSDictionary class]])
                    continue;
                
                NSUInteger touchIndex = [subeventData[@"index"] unsignedIntegerValue];
                uint32_t extraMask = [subeventData[@"emsk"] unsignedIntValue] & 0xFFFF0000;
                
                if ([subeventData[@"touch"] boolValue])
                {
                    // have a rest
                    if (_lastTimeStamp > 0 && currentStamp - _lastTimeStamp >= 1e-3) {
                        _PrintNSString([NSString stringWithFormat:@"sys.msleep(%llu)\n",
                                        (unsigned long long)round((currentStamp - _lastTimeStamp) * 1e3)], NO);
                        _requiresBreak = YES;
                    }
                    
                    if (![_touchIndexes containsIndex:touchIndex])
                    {
                        // on
                        if (extraMask == 0) {
                            _PrintNSString([NSString stringWithFormat:@"touch.on(%lu, %d, %d)\n", touchIndex,
                                            (int)round([subeventData[@"x"] doubleValue]),
                                            (int)round([subeventData[@"y"] doubleValue])], NO);
                        } else {
                            _PrintNSString([NSString stringWithFormat:@"touch.on(%lu, %d, %d, 0x%08X)\n", touchIndex,
                                            (int)round([subeventData[@"x"] doubleValue]),
                                            (int)round([subeventData[@"y"] doubleValue]),
                                            extraMask], NO);
                        }
                        
                        [_touchIndexes addIndex:touchIndex];
                        _requiresBreak = YES;
                        hasValidTouch = YES;
                    }
                    else
                    {
                        BOOL hasPressure = [subeventData[@"pressure"] isKindOfClass:[NSNumber class]];
                        BOOL hasTwist = [subeventData[@"twist"] isKindOfClass:[NSNumber class]];
                        
                        // move
                        if (hasPressure && hasTwist)
                        {
                            _PrintNSString([NSString stringWithFormat:@"touch.move(%lu, %d, %d, %d, %d)\n", touchIndex,
                                            (int)round([subeventData[@"x"] doubleValue]),
                                            (int)round([subeventData[@"y"] doubleValue]),
                                            (int)round([subeventData[@"pressure"] doubleValue] / 600.f * 1e4),
                                            (int)round([subeventData[@"twist"] doubleValue] / 180.f * 1e2)], NO);
                            _requiresBreak = YES;
                            hasValidTouch = YES;
                        }
                        else if (hasPressure)
                        {
                            _PrintNSString([NSString stringWithFormat:@"touch.move(%lu, %d, %d, %d)\n", touchIndex,
                                            (int)round([subeventData[@"x"] doubleValue]),
                                            (int)round([subeventData[@"y"] doubleValue]),
                                            (int)round([subeventData[@"pressure"] doubleValue] / 600.f * 1e4)], NO);
                            _requiresBreak = YES;
                            hasValidTouch = YES;
                        }
                        else
                        {
                            _PrintNSString([NSString stringWithFormat:@"touch.move(%lu, %d, %d)\n", touchIndex,
                                            (int)round([subeventData[@"x"] doubleValue]),
                                            (int)round([subeventData[@"y"] doubleValue])], NO);
                            _requiresBreak = YES;
                            hasValidTouch = YES;
                        }
                    }
                }
                else
                {
                    // off
                    if (![_touchIndexes containsIndex:touchIndex])
                        continue;
                    
                    // have a rest
                    if (_lastTimeStamp > 0 && currentStamp - _lastTimeStamp >= 1e-3) {
                        _PrintNSString([NSString stringWithFormat:@"sys.msleep(%llu)\n",
                                        (unsigned long long)round((currentStamp - _lastTimeStamp) * 1e3)], NO);
                        _requiresBreak = YES;
                    }
                    
                    _PrintNSString([NSString stringWithFormat:@"touch.off(%lu, %d, %d)\n", touchIndex,
                                    (int)round([subeventData[@"x"] doubleValue]),
                                    (int)round([subeventData[@"y"] doubleValue])], NO);
                    [_touchIndexes removeIndex:touchIndex];
                    _requiresBreak = YES;
                    hasValidTouch = YES;
                }
            }
            
            if (!hasValidTouch) {
                return;
            }
        }
        
        // key event
        else if ([eventDict[@"type"] isEqualToString:@"key"])
        {
            NSDictionary *eventData = eventDict[@"data"];
            if (![eventData isKindOfClass:[NSDictionary class]])
                return;
            
            NSInteger pageValue = [eventData[@"page"] integerValue];
            NSInteger usageValue = [eventData[@"usage"] integerValue];
            NSInteger pageUsageValue = (pageValue << 16) + usageValue;
            
            if ([eventData[@"down"] boolValue])
            {
                if ([_keyIndexes containsIndex:pageUsageValue])
                    return;
                
                // have a rest
                if (_lastTimeStamp > 0 && currentStamp - _lastTimeStamp >= 1e-3) {
                    _PrintNSString([NSString stringWithFormat:@"sys.msleep(%llu)\n",
                                    (unsigned long long)round((currentStamp - _lastTimeStamp) * 1e3)], NO);
                    _requiresBreak = YES;
                }
                
                _PrintNSString([NSString stringWithFormat:@"key.down(%ld, %ld)",
                                pageValue,
                                usageValue], NO);
                [_keyIndexes addIndex:pageUsageValue];
                _requiresBreak = YES;
            }
            else
            {
                if (![_keyIndexes containsIndex:pageUsageValue])
                    return;
                
                // have a rest
                if (_lastTimeStamp > 0 && currentStamp - _lastTimeStamp >= 1e-3) {
                    _PrintNSString([NSString stringWithFormat:@"sys.msleep(%llu)\n",
                                    (unsigned long long)round((currentStamp - _lastTimeStamp) * 1e3)], NO);
                    _requiresBreak = YES;
                }
                
                _PrintNSString([NSString stringWithFormat:@"key.up(%ld, %ld)",
                                pageValue,
                                usageValue], NO);
                [_keyIndexes removeIndex:pageUsageValue];
                _requiresBreak = YES;
            }
            
            if ([eventData[@"page"] intValue] == 0xC && [eventData[@"usage"] intValue] == 0x30)
            {
                _PrintNSString(@"  -- POWER", NO);
            }
            else if ([eventData[@"page"] intValue] == 0xC && [eventData[@"usage"] intValue] == 0xE9)
            {
                _PrintNSString(@"  -- VOLUME UP", NO);
            }
            else if ([eventData[@"page"] intValue] == 0xC && [eventData[@"usage"] intValue] == 0xEA)
            {
                _PrintNSString(@"  -- VOLUME DOWN", NO);
            }
            else if ([eventData[@"page"] intValue] == 0xC && [eventData[@"usage"] intValue] == 0x40)
            {
                _PrintNSString(@"  -- HOME", NO);
            }
            
            _PrintNSString(@"\n", NO);
        }
        
        // unsupported
        else
        {
            return;
        }
        
        if ([_touchIndexes count] == 0 && [_keyIndexes count] == 0)
        {
            if (_requiresBreak) {
                _PrintNSString(@"\n", NO);
                _requiresBreak = NO;
            }
        }
        
        _lastAbsStamp = absStamp;
        _lastTimeStamp = currentStamp;
    }
}


#pragma mark - Signal Handlers

static IOHIDEventSystemClientRef _sharedHIDSystemClient;
static BOOL _didPauseRecording = NO;

static void sigint_handler(int signal)
{
    CHDebugLogSource(@"%d", signal);
    
    IOHIDEventSystemClientUnregisterEventCallback(_sharedHIDSystemClient);
    IOHIDEventSystemClientUnscheduleWithRunLoop(_sharedHIDSystemClient, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    
    {
        NSMutableString *recordingContent = [NSMutableString string];
        
        [recordingContent appendString:@"\nend\n\n"];
        [recordingContent appendString:@"touch.init(old_init_orien)\n"];
        [recordingContent appendString:@"end)(touch.init(0));  -- record end\n"];
        
        _PrintNSString(recordingContent, YES);
    }
    
    exit(EXIT_SUCCESS);
    return;
}

static void sigstop_handler(int signal)
{
    CHDebugLogSource(@"%d", signal);
    
    if (!_didPauseRecording) {
        IOHIDEventSystemClientUnscheduleWithRunLoop(_sharedHIDSystemClient, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
        _didPauseRecording = YES;
    }
}

static void sigcont_handler(int signal)
{
    CHDebugLogSource(@"%d", signal);
    
    if (_didPauseRecording) {
        IOHIDEventSystemClientScheduleWithRunLoop(_sharedHIDSystemClient, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
        _didPauseRecording = NO;
    }
}


#pragma mark - User Defaults

@interface ProcQueue (Notification)
- (void)remoteDefaultsChanged;
@end
@implementation ProcQueue (Notification)
- (void)remoteDefaultsChanged
{
    @autoreleasepool {
        
        NSDictionary *defaults = [self unsafeDefaultsDictionary];
        if (![defaults isKindOfClass:[NSDictionary class]]) {
            return;  // remote defaults not ready, abort.
        }
        
        {
            NSDictionary *recordDefaults = [defaults objectForKey:@"ch.xxtou.defaults.recording"];
            if ([recordDefaults isKindOfClass:[NSDictionary class]])
            {
                BOOL recodeVolumeUp = [[recordDefaults objectForKey:@"record_volume_up"] boolValue];
                BOOL recodeVolumeDown = [[recordDefaults objectForKey:@"record_volume_down"] boolValue];
                
                if (recodeVolumeUp && recodeVolumeDown) {
                    _recorderOption = HIDRecorderRecordOptionRecordVolumeBoth;
                } else if (recodeVolumeUp) {
                    _recorderOption = HIDRecorderRecordOptionRecordVolumeUp;
                } else if (recodeVolumeDown) {
                    _recorderOption = HIDRecorderRecordOptionRecordVolumeDown;
                } else {
                    _recorderOption = HIDRecorderRecordOptionRecordNone;
                }
            }
        }
    }
}
@end


#pragma mark -

OBJC_EXTERN
void plugin_i_love_xxtouch(void);
void plugin_i_love_xxtouch(void) {}


#pragma mark - Entry Point

int main(int argc, char *argv[])
{
    /* increase memory usage */
    int rc;
    
    memorystatus_priority_properties_t props = {0, JETSAM_PRIORITY_CRITICAL};
    rc = memorystatus_control(MEMORYSTATUS_CMD_SET_PRIORITY_PROPERTIES, getpid(), 0, &props, sizeof(props));
    if (rc < 0) { perror ("memorystatus_control"); exit(rc); }
    
    rc = memorystatus_control(MEMORYSTATUS_CMD_SET_JETSAM_HIGH_WATER_MARK, getpid(), -1, NULL, 0);
    if (rc < 0) { perror ("memorystatus_control"); exit(rc); }
    
    rc = memorystatus_control(MEMORYSTATUS_CMD_SET_PROCESS_IS_MANAGED, getpid(), 0, NULL, 0);
    if (rc < 0) { perror ("memorystatus_control"); exit(rc); }
    
    rc = memorystatus_control(MEMORYSTATUS_CMD_SET_PROCESS_IS_FREEZABLE, getpid(), 0, NULL, 0);
    if (rc < 0) { perror ("memorystatus_control"); exit(rc); }
    
    @autoreleasepool {
        _outputQueue = dispatch_queue_create("ch.xxtou.queue.hidrecorder.output", DISPATCH_QUEUE_SERIAL);
        
        _touchIndexes = [NSMutableIndexSet indexSet];
        _keyIndexes = [NSMutableIndexSet indexSet];
        
        {
            NSMutableString *recordingContent = [NSMutableString stringWithString:@";(function(old_init_orien)  -- record begin\n\n"];
            
            [recordingContent appendString:@"local play_speed = 1.0  -- Speed\n"];
            [recordingContent appendString:@"local play_times = 1    -- Repeat Times\n\n"];
            [recordingContent appendString:@"local sys_ = {}\n"];
            [recordingContent appendString:@"for k, v in pairs(sys) do\n"];
            [recordingContent appendString:@"\tif k == 'msleep' or k == 'sleep' then\n"];
            [recordingContent appendString:@"\t\tsys_[k] = function(s) v(s / play_speed) end\n"];
            [recordingContent appendString:@"\telse\n"];
            [recordingContent appendString:@"\t\tsys_[k] = v\n"];
            [recordingContent appendString:@"\tend\n"];
            [recordingContent appendString:@"end\n\n"];
            [recordingContent appendString:@"local sys = sys_\n"];
            [recordingContent appendString:@"local mSleep = sys.msleep\n"];
            [recordingContent appendString:@"for l____________i = 1, play_times do\n\n\n"];
            
            _PrintNSString(recordingContent, YES);
        }
        
        IOMobileFramebufferRef framebufferConnection = NULL;
        IOMobileFramebufferGetMainDisplay(&framebufferConnection);
        IOMobileFramebufferGetDisplaySize(framebufferConnection, &_screenSize);
        _screenBounds = CGRectMake(0, 0, _screenSize.width, _screenSize.height);
        
        _sharedHIDSystemClient = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
        IOHIDEventSystemClientScheduleWithRunLoop(_sharedHIDSystemClient, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
        IOHIDEventSystemClientRegisterEventCallback(_sharedHIDSystemClient, _HandleHIDSystemEvent, 0, 0);
        
        {
            struct sigaction act, oldact;
            act.sa_handler = &sigint_handler;
            sigaction(SIGINT, &act, &oldact);
        }
        
        {
            struct sigaction act, oldact;
            act.sa_handler = &sigstop_handler;
            sigaction(SIGUSR1, &act, &oldact);  // conflicts with SIGSTOP
        }
        
        {
            struct sigaction act, oldact;
            act.sa_handler = &sigcont_handler;
            sigaction(SIGUSR2, &act, &oldact);  // conflicts with SIGCONT
        }
        
        CFRunLoopRun();
        return EXIT_SUCCESS;
    }
}
