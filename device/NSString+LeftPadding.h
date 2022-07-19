#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSString (LeftPadding)
- (NSString *)xxte_stringByPaddingTheLeftToLength:(NSUInteger)newLength withString:(NSString *)padString startingAtIndex:(NSUInteger)padIndex;
@end

NS_ASSUME_NONNULL_END
