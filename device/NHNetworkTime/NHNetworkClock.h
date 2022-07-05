/**
   NHNetworkClock.h
   Created by Gavin Eadie on Oct17/10 ... Copyright 2010-14 Ramsay Consulting. All rights reserved.
   Modified by Nguyen Cong Huy on 9 Sep 2015
 */

#import "NHNetAssociation.h"


/// The NetworkClock sends notifications of the network time.  It will attempt to provide a very early estimate and then refine that and reduce the number of notifications ...
/// NetworkClock is a singleton class which will provide the best estimate of the difference in time between the device's system clock and the time returned by a collection of time servers. The method <networkTime> returns an NSDate with the network time.
@interface NHNetworkClock : NSObject
    
@property (nonatomic, copy, readonly) NSDate *networkTime;
@property (nonatomic, assign, readonly) NSTimeInterval networkOffset;
@property (nonatomic, assign, readonly) BOOL isSynchronized;
@property (nonatomic, assign, readonly) dispatch_queue_t accessQueue;

#pragma mark -

+ (instancetype)sharedNetworkClock;
- (BOOL)synchronize;

@end
