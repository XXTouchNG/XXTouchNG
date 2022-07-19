#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import "NSString+LeftPadding.h"

@implementation NSString (LeftPadding)

// taken from http://stackoverflow.com/questions/964322/padding-string-to-left-with-objective-c

- (NSString *)xxte_stringByPaddingTheLeftToLength:(NSUInteger)newLength withString:(NSString *)padString startingAtIndex:(NSUInteger)padIndex
{
    if ([self length] <= newLength)
        return [[@"" stringByPaddingToLength:newLength - [self length] withString:padString startingAtIndex:padIndex] stringByAppendingString:self];
    else
        return [self copy];
}

@end
