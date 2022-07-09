#import <libactivator/libactivator.h>

#import "HIDRecorderEnums.h"
#import "ProcQueue.h"


#pragma mark -

OBJC_EXTERN
void __HIDRecorderPerformAction(HIDRecorderAction action);

OBJC_EXTERN
void __HIDRecorderPerformOperation(HIDRecorderOperation operation);

OBJC_EXTERN
void __HIDRecorderDismissAlertConfirm(void);


#pragma mark -

@interface HIDRecorderActivator : NSObject <LAListener>
@property (nonatomic, copy, readonly) NSString *listenerName;
- (instancetype)initWithListenerName:(NSString *)listenerName;
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
@end

@implementation HIDRecorderActivator

- (instancetype)initWithListenerName:(NSString *)listenerName
{
    self = [super init];
    if (self)
    {
        _listenerName = listenerName;
    }
    return self;
}

- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event {
    BOOL handled = NO;
    if ([self.listenerName isEqualToString:@"ch.xxtou.activator.ask.both"])
    {
        __HIDRecorderPerformOperation(HIDRecorderOperationBothWithAlert);
        handled = YES;
    }
    else if ([self.listenerName isEqualToString:@"ch.xxtou.activator.ask.launch"])
    {
        __HIDRecorderPerformOperation(HIDRecorderOperationPlayWithAlert);
        handled = YES;
    }
    else if ([self.listenerName isEqualToString:@"ch.xxtou.activator.ask.record"])
    {
        __HIDRecorderPerformOperation(HIDRecorderOperationRecordWithAlert);
        handled = YES;
    }
    
    else if ([self.listenerName isEqualToString:@"ch.xxtou.activator.toggle"])
    {
        __HIDRecorderPerformOperation(HIDRecorderOperationPlay);
        handled = YES;
    }
    
    else if ([self.listenerName isEqualToString:@"ch.xxtou.activator.launch"])
    {
        __HIDRecorderPerformAction(HIDRecorderActionLaunch);
        handled = YES;
    }
    else if ([self.listenerName isEqualToString:@"ch.xxtou.activator.record"])
    {
        __HIDRecorderPerformAction(HIDRecorderActionRecord);
        handled = YES;
    }
    
    else if ([self.listenerName isEqualToString:@"ch.xxtou.activator.pause"])
    {
        __HIDRecorderPerformAction(HIDRecorderActionPause);
        handled = YES;
    }
    else if ([self.listenerName isEqualToString:@"ch.xxtou.activator.pause"])
    {
        __HIDRecorderPerformAction(HIDRecorderActionPause);
        handled = YES;
    }
    else if ([self.listenerName isEqualToString:@"ch.xxtou.activator.continue"])
    {
        __HIDRecorderPerformAction(HIDRecorderActionContinue);
        handled = YES;
    }
    else if ([self.listenerName isEqualToString:@"ch.xxtou.activator.stop"])
    {
        __HIDRecorderPerformAction(HIDRecorderActionStop);
        handled = YES;
    }
    
    else if ([self.listenerName isEqualToString:@"ch.xxtou.activator.remote.off"])
    {
        [[ProcQueue sharedInstance] setObject:@(NO) forKey:@"ch.xxtou.defaults.remote-access"];
        handled = YES;
    }
    
    else if ([self.listenerName isEqualToString:@"ch.xxtou.activator.remote.on"])
    {
        [[ProcQueue sharedInstance] setObject:@(YES) forKey:@"ch.xxtou.defaults.remote-access"];
        handled = YES;
    }

    else if ([self.listenerName isEqualToString:@"ch.xxtou.activator.remote.toggle"])
    {
        BOOL remoteAccessEnabled = [[[ProcQueue sharedInstance] objectForKey:@"ch.xxtou.defaults.remote-access"] boolValue];
        [[ProcQueue sharedInstance] setObject:@(!remoteAccessEnabled) forKey:@"ch.xxtou.defaults.remote-access"];
        handled = YES;
    }
    
	[event setHandled:handled];  // To prevent the default OS implementation
}

- (void)activator:(LAActivator *)activator abortEvent:(LAEvent *)event {
	// Dismiss your plugin
    if ([self.listenerName hasPrefix:@"ch.xxtou.activator.ask."])
    {
        __HIDRecorderDismissAlertConfirm();
    }
}

+ (void)load {
    Class la = objc_getClass("LAActivator");
    if ([[la sharedInstance] isRunningInsideSpringBoard]) {
        NSArray <NSString *> *availableListenerNames = @[
            @"ch.xxtou.activator.ask.both",
            @"ch.xxtou.activator.ask.launch",
            @"ch.xxtou.activator.ask.record",
            
            @"ch.xxtou.activator.toggle",
            
            @"ch.xxtou.activator.launch",
            @"ch.xxtou.activator.record",
            
            @"ch.xxtou.activator.pause",
            @"ch.xxtou.activator.continue",
            @"ch.xxtou.activator.stop",

            @"ch.xxtou.activator.remote.off",
            @"ch.xxtou.activator.remote.on",
            @"ch.xxtou.activator.remote.toggle",
        ];
        
        for (NSString *listenerName in availableListenerNames) {
            HIDRecorderActivator *listener = [[HIDRecorderActivator alloc] initWithListenerName:listenerName];
            [[la sharedInstance] registerListener:listener forName:listenerName];
        }
    }
}

@end
