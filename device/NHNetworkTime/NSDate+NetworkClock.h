/**
   Author: Juan Batiz-Benet
   Category on NSDate to provide convenience access to NetworkClock.
   To use, simply call [NSDate networkDate];
 */

#import <Foundation/Foundation.h>
#import "NHNetworkClock.h"


@interface NSDate (NetworkClock)
+ (NSDate *)networkDate;
@end
