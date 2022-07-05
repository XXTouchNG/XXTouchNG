#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import "NSDate+NetworkClock.h"

@implementation NSDate (NetworkClock)

+ (NSDate *)networkDate {
    return [[NHNetworkClock sharedNetworkClock] networkTime];
}

@end
