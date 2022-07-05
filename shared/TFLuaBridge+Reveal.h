//
//  TFLuaBridge+Reveal.h
//  XXTouch
//
//  Created by Darwin on 10/14/20.
//

#import "TFLuaBridge+IMP.h"
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface TFLuaBridge (Reveal)

+ (nullable UIViewController *)findViewControllerByClassName:(nonnull NSString *)className;
+ (nullable UIViewController *)findViewControllerByClassName:(nonnull NSString *)className fromViewController:(nullable UIViewController *)parentViewController;

@end

NS_ASSUME_NONNULL_END
