//
//  TFLuaBridge+Reveal.m
//  XXTouch
//
//  Created by Darwin on 10/14/20.
//

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import "TFLuaBridge+Reveal.h"

@implementation TFLuaBridge (Reveal)

+ (nullable UIViewController *)findViewControllerByClassName:(nonnull NSString *)className {
    @autoreleasepool {
        UIViewController *targetController = nil;
        for (UIWindow *window in [[UIApplication sharedApplication] windows]) {
            @autoreleasepool {
                UIViewController *topController = [window rootViewController];
                if (!topController) {
                    continue;
                }
                NSMutableArray <UIViewController *> *controllers = [NSMutableArray arrayWithObject:topController];
                do {
                    @autoreleasepool {
                        UIViewController *controller = [controllers lastObject];
                        [controllers removeLastObject];
                        for (UIViewController *childController in controller.childViewControllers) {
                            @autoreleasepool {
                                if ([NSStringFromClass([childController class]) isEqualToString:className]) {
                                    return childController;
                                } else if (childController.childViewControllers.count > 0) {
                                    [controllers addObject:childController];
                                }
                            }
                        }
                    }
                } while (controllers.count > 0);
            }
        }
        return targetController;
    }
}

+ (nullable UIViewController *)findViewControllerByClassName:(nonnull NSString *)className fromViewController:(nullable UIViewController *)parentViewController {
    @autoreleasepool {
        UIViewController *topController = parentViewController;
        if (!topController) {
            return nil;
        }
        NSMutableArray <UIViewController *> *controllers = [NSMutableArray arrayWithObject:topController];
        do {
            @autoreleasepool {
                UIViewController *controller = [controllers lastObject];
                [controllers removeLastObject];
                for (UIViewController *childController in controller.childViewControllers) {
                    @autoreleasepool {
                        if ([NSStringFromClass([childController class]) isEqualToString:className]) {
                            return childController;
                        } else if (childController.childViewControllers.count > 0) {
                            [controllers addObject:childController];
                        }
                    }
                }
            }
        } while (controllers.count > 0);
    }
    return nil;
}

@end
