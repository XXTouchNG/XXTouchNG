#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import <arpa/inet.h>
#import "NHNetworkClock.h"


@interface NHNetworkClock () <NHNetAssociationDelegate>

@property (nonatomic, strong) NSMutableArray <NHNetAssociation *> *timeAssociations;
@property (nonatomic, strong) NSArray <NSSortDescriptor *> *sortDescriptors;
@property (nonatomic, assign, readwrite) BOOL isSynchronized;

@end

@implementation NHNetworkClock {
    dispatch_queue_t _syncQueue;
}

+ (instancetype)sharedNetworkClock {
    static NHNetworkClock *clockInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        clockInstance = [[self alloc] init];
    });
    return clockInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        _sortDescriptors = @[[[NSSortDescriptor alloc] initWithKey:@"dispersion" ascending:YES]];
        _timeAssociations = [[NSMutableArray alloc] initWithCapacity:64];
        _syncQueue = dispatch_queue_create("ch.xxtou.queue.device.clock", DISPATCH_QUEUE_SERIAL);
    }
    
    return self;
}

- (void)reset {
    dispatch_sync(_syncQueue, ^{
        self.isSynchronized = NO;
        [self unsafe_finishAssociations];
        [self.timeAssociations removeAllObjects];
    });
}

/// Return the offset to network-derived UTC.
- (NSTimeInterval)networkOffset {
    __block double timeInterval = 0.0;
    __block short usefulCount = 0;
    dispatch_sync(_syncQueue, ^{
        if (self.timeAssociations.count > 0) {
            NSArray *sortedArray = [[self.timeAssociations sortedArrayUsingDescriptors:self.sortDescriptors] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL (id _Nonnull evaluatedObject, NSDictionary <NSString *, id> * _Nullable bindings) {
                return [evaluatedObject isKindOfClass:[NHNetAssociation class]];
            }]];
            
            for (NHNetAssociation *timeAssociation in sortedArray) {
                if (timeAssociation.active) {
                    if (timeAssociation.trusty) {
                        usefulCount++;
                        timeInterval = timeInterval + timeAssociation.offset;
                    }
                    else {
                        if ([self.timeAssociations count] > 8) {
                            [self.timeAssociations removeObject:timeAssociation];
                            [timeAssociation finish];
                        }
                    }
                    
                    if (usefulCount == 8) break;                // use 8 best dispersions
                }
            }
        }
        
        if (usefulCount > 0) {
            timeInterval = timeInterval / usefulCount;
        }
    });
    return timeInterval;
}

- (dispatch_queue_t)accessQueue {
    return _syncQueue;
}


#pragma mark - Get time

- (NSDate *)networkTime {
    return [[NSDate date] dateByAddingTimeInterval:-self.networkOffset];
}


#pragma mark - Associations

/// Use the following time servers or, if it exists, read the "ntp.hosts" file from the application resources and derive all the IP addresses referred to, remove any duplicates and create an 'association' (individual host client) for each one.
- (BOOL)unsafe_createAssociations {
    NSArray *ntpDomains = @[@"time.apple.com"];
    CHDebugLogSource(@"Domains %@", ntpDomains);
    
    // for each NTP service domain name in the 'ntp.hosts' file : "0.pool.ntp.org" etc ...
    NSMutableSet *hostAddresses = [NSMutableSet setWithCapacity:64];
    
    for (NSString *ntpDomainName in ntpDomains) {
        if ([ntpDomainName length] == 0 ||
            [ntpDomainName characterAtIndex:0] == ' ' ||
            [ntpDomainName characterAtIndex:0] == '#') {
            continue;
        }
        
        // ... resolve the IP address of the named host : "0.pool.ntp.org" --> [123.45.67.89], ...
        CFHostRef ntpHostName = CFHostCreateWithName(nil, (__bridge CFStringRef)ntpDomainName);
        if (nil == ntpHostName) {
            CHDebugLogSource(@"CFHostCreateWithName <nil> for %@", ntpDomainName);
            continue;  // couldn't create 'host object' ...
        }
        
        CFStreamError nameError;
        if (!CFHostStartInfoResolution(ntpHostName, kCFHostAddresses, &nameError)) {
            CHDebugLogSource(@"CFHostStartInfoResolution error %i for %@", (int)nameError.error, ntpDomainName);
            CFRelease(ntpHostName);
            continue;  // couldn't start resolution ...
        }
        
        Boolean nameFound;
        CFArrayRef ntpHostAddrs = CFHostGetAddressing(ntpHostName, &nameFound);
        
        if (!nameFound) {
            CHDebugLogSource(@"CFHostGetAddressing: %@ NOT resolved", ntpHostName);
            CFRelease(ntpHostName);
            continue;  // resolution failed ...
        }
        
        if (ntpHostAddrs == nil) {
            CHDebugLogSource(@"CFHostGetAddressing: no addresses resolved for %@", ntpHostName);
            CFRelease(ntpHostName);
            continue;  // NO addresses were resolved ...
        }
        
        // for each (sockaddr structure wrapped by a CFDataRef/NSData *) associated with the hostname, drop the IP address string into a Set to remove duplicates.
        for (NSData *ntpHost in (__bridge NSArray *)ntpHostAddrs) {
            [hostAddresses addObject:[GCDAsyncUdpSocket hostFromAddress:ntpHost]];
        }
        
        CFRelease(ntpHostName);
    }
    
    CHDebugLogSource(@"Resolved addresses %@", hostAddresses);  // all the addresses resolved
    
    // ... now start one 'association' (network clock server) for each address.
    for (NSString *server in hostAddresses) {
        NHNetAssociation *timeAssociation = [[NHNetAssociation alloc] initWithServerName:server];
        timeAssociation.delegate = self;
        
        [self.timeAssociations addObject:timeAssociation];
        [timeAssociation enable];  // starts are randomized internally
    }
    
    return hostAddresses.count > 0;
}

/// Stop all the individual ntp clients associations ..
- (void)unsafe_finishAssociations {
    for (NHNetAssociation *timeAssociation in self.timeAssociations) {
        timeAssociation.delegate = nil;
        [timeAssociation finish];
    }
}


#pragma mark - Sync

- (BOOL)synchronize {
    [self reset];
    
    __block BOOL didBeginSynchronize = NO;
    dispatch_sync(_syncQueue, ^{
        didBeginSynchronize = [self unsafe_createAssociations];
    });
    return didBeginSynchronize;
}


#pragma mark - NHNetAssociationDelegate

- (void)netAssociationDidFinishGetTime:(NHNetAssociation *)netAssociation {
    if (netAssociation.active && netAssociation.trusty) {
        dispatch_async(_syncQueue, ^{
            if (!self.isSynchronized) {
                self.isSynchronized = YES;
            }
        });
    } else {
        CHDebugLogSource(@"Failed synchronize time: active = %@, trusted = %@",
                         netAssociation.active ? @"YES" : @"NO",
                         netAssociation.trusty ? @"YES" : @"NO");
    }
}

@end
