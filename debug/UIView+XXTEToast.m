//
//  UIView+Toast.m
//  Toast
//
//  Copyright (c) 2011-2015 Charles Scalesse.
//
//  Permission is hereby granted, free of charge, to any person obtaining a
//  copy of this software and associated documentation files (the
//  "Software"), to deal in the Software without restriction, including
//  without limitation the rights to use, copy, modify, merge, publish,
//  distribute, sublicense, and/or sell copies of the Software, and to
//  permit persons to whom the Software is furnished to do so, subject to
//  the following conditions:
//
//  The above copyright notice and this permission notice shall be included
//  in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
//  OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
//  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
//  CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
//  TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
//  SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import "UIView+XXTEToast.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

NSString * XXTEToastPositionTop       = @"XXTEToastPositionTop";
NSString * XXTEToastPositionCenter    = @"XXTEToastPositionCenter";
NSString * XXTEToastPositionBottom    = @"XXTEToastPositionBottom";

// Keys for values associated with toast views
static const NSString * XXTEToastTimerKey             = @"XXTEToastTimerKey";
static const NSString * XXTEToastDurationKey          = @"XXTEToastDurationKey";
static const NSString * XXTEToastPositionKey          = @"XXTEToastPositionKey";
static const NSString * XXTEToastCompletionKey        = @"XXTEToastCompletionKey";

// Keys for values associated with self
static const NSString * XXTEToastActiveToastViewKey   = @"XXTEToastActiveToastViewKey";
static const NSString * XXTEToastActivityViewKey      = @"XXTEToastActivityViewKey";
static const NSString * XXTEToastQueueKey             = @"XXTEToastQueueKey";

static const NSTimeInterval XXTEToastFadeDuration     = 0.2;

@interface UIView (XXTEToastPrivate)

/**
 These private methods are being prefixed with "xxte_" to reduce the likelihood of non-obvious
 naming conflicts with other UIView methods.
 
 @discussion Should the public API also use the xxte_ prefix? Technically it should, but it
 results in code that is less legible. The current public method names seem unlikely to cause
 conflicts so I think we should favor the cleaner API for now.
 */
- (void)xxte_showToast:(UIView *)toast duration:(NSTimeInterval)duration position:(id)position;
- (void)xxte_hideToast:(UIView *)toast;
- (void)xxte_hideToast:(UIView *)toast fromTap:(BOOL)fromTap;
- (void)xxte_toastTimerDidFinish:(NSTimer *)timer;
- (void)xxte_handleToastTapped:(UITapGestureRecognizer *)recognizer;
- (CGPoint)xxte_centerPointForPosition:(id)position withToast:(UIView *)toast;
- (CGSize)xxte_sizeForString:(NSString *)string font:(UIFont *)font constrainedToSize:(CGSize)constrainedSize lineBreakMode:(NSLineBreakMode)lineBreakMode;
- (NSMutableArray *)xxte_toastQueue;

@end

@implementation UIView (XXTEToast)

#pragma mark - Make Toast Methods

- (UIView *)makeToast:(NSString *)message {
    return [self makeToast:message duration:[XXTEToastManager defaultDuration] position:[XXTEToastManager defaultPosition] style:nil];
}

- (UIView *)makeToast:(NSString *)message duration:(NSTimeInterval)duration position:(id)position {
    return [self makeToast:message duration:duration position:position style:nil];
}

- (UIView *)makeToast:(NSString *)message duration:(NSTimeInterval)duration position:(id)position style:(XXTEToastStyle *)style {
    UIView *toast = [self toastViewForMessage:message title:nil image:nil style:style];
    [self showToast:toast duration:duration position:position completion:nil];
    return toast;
}

- (UIView *)makeToast:(NSString *)message duration:(NSTimeInterval)duration position:(id)position title:(NSString *)title image:(UIImage *)image style:(XXTEToastStyle *)style completion:(void(^)(BOOL didTap))completion {
    UIView *toast = [self toastViewForMessage:message title:title image:image style:style];
    [self showToast:toast duration:duration position:position completion:completion];
    return toast;
}

#pragma mark - Show Toast Methods

- (void)showToast:(UIView *)toast {
    [self showToast:toast duration:[XXTEToastManager defaultDuration] position:[XXTEToastManager defaultPosition] completion:nil];
}

- (void)showToast:(UIView *)toast duration:(NSTimeInterval)duration position:(id)position completion:(void(^)(BOOL didTap))completion {
    // sanity
    if (toast == nil) return;
    
    // store the completion block on the toast view
    objc_setAssociatedObject(toast, &XXTEToastCompletionKey, completion, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    if ([XXTEToastManager isQueueEnabled] && objc_getAssociatedObject(self, &XXTEToastActiveToastViewKey) != nil) {
        // we're about to queue this toast view so we need to store the duration and position as well
        objc_setAssociatedObject(toast, &XXTEToastDurationKey, @(duration), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(toast, &XXTEToastPositionKey, position, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
        // enqueue
        [self.xxte_toastQueue addObject:toast];
    } else {
        // present
        [self xxte_showToast:toast duration:duration position:position];
    }
}

#pragma mark - Hide Toast Methods

- (void)hideToast:(UIView *)toast {
    [self xxte_hideToast:toast];
}

#pragma mark - Private Show/Hide Methods

- (void)xxte_showToast:(UIView *)toast duration:(NSTimeInterval)duration position:(id)position {
    toast.center = [self xxte_centerPointForPosition:position withToast:toast];
    toast.alpha = 0.0;
    
    if ([XXTEToastManager isTapToDismissEnabled]) {
        UITapGestureRecognizer *recognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(xxte_handleToastTapped:)];
        [toast addGestureRecognizer:recognizer];
        toast.userInteractionEnabled = YES;
        toast.exclusiveTouch = YES;
    }
    
    // set the active toast
    objc_setAssociatedObject(self, &XXTEToastActiveToastViewKey, toast, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    [self addSubview:toast];
    
    [UIView animateWithDuration:XXTEToastFadeDuration
                          delay:0.0
                        options:(UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction)
                     animations:^{
        toast.alpha = 1.0;
    } completion:^(BOOL finished) {
        NSTimer *timer = [NSTimer timerWithTimeInterval:duration target:self selector:@selector(xxte_toastTimerDidFinish:) userInfo:toast repeats:NO];
        [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
        objc_setAssociatedObject(toast, &XXTEToastTimerKey, timer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }];
}

- (void)xxte_hideToast:(UIView *)toast {
    [self xxte_hideToast:toast fromTap:NO];
}

- (void)xxte_hideToast:(UIView *)toast fromTap:(BOOL)fromTap {
    [UIView animateWithDuration:XXTEToastFadeDuration
                          delay:0.0
                        options:(UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionBeginFromCurrentState)
                     animations:^{
        toast.alpha = 0.0;
    } completion:^(BOOL finished) {
        [toast removeFromSuperview];
        
        // clear the active toast
        objc_setAssociatedObject(self, &XXTEToastActiveToastViewKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
        // execute the completion block, if necessary
        void (^completion)(BOOL didTap) = objc_getAssociatedObject(toast, &XXTEToastCompletionKey);
        if (completion) {
            completion(fromTap);
        }
        
        if ([self.xxte_toastQueue count] > 0) {
            // dequeue
            UIView *nextToast = [[self xxte_toastQueue] firstObject];
            [[self xxte_toastQueue] removeObjectAtIndex:0];
            
            // present the next toast
            NSTimeInterval duration = [objc_getAssociatedObject(nextToast, &XXTEToastDurationKey) doubleValue];
            id position = objc_getAssociatedObject(nextToast, &XXTEToastPositionKey);
            [self xxte_showToast:nextToast duration:duration position:position];
        }
    }];
}

#pragma mark - View Construction

- (UIView *)toastViewForMessage:(NSString *)message title:(NSString *)title image:(UIImage *)image style:(XXTEToastStyle *)style {
    // sanity
    if(message == nil && title == nil && image == nil) return nil;
    
    // default to the shared style
    if (style == nil) {
        style = [XXTEToastManager sharedStyle];
    }
    
    // dynamically build a toast view with any combination of message, title, & image.
    UILabel *messageLabel = nil;
    UILabel *titleLabel = nil;
    UIImageView *imageView = nil;
    
    // create the parent view
    UIView *wrapperView = [[UIView alloc] init];
    wrapperView.autoresizingMask = (UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin);
    wrapperView.layer.cornerRadius = style.cornerRadius;
    
    if (style.displayShadow) {
        wrapperView.layer.shadowColor = [UIColor blackColor].CGColor;
        wrapperView.layer.shadowOpacity = style.shadowOpacity;
        wrapperView.layer.shadowRadius = style.shadowRadius;
        wrapperView.layer.shadowOffset = style.shadowOffset;
    }
    
    wrapperView.backgroundColor = style.backgroundColor;
    
    if (image != nil) {
        imageView = [[UIImageView alloc] initWithImage:image];
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        imageView.frame = CGRectMake(style.horizontalPadding, style.verticalPadding, style.imageSize.width, style.imageSize.height);
    }
    
    CGFloat imageWidth, imageHeight, imageLeft;
    
    // the imageView frame values will be used to size & position the other views
    if (imageView != nil) {
        imageWidth = imageView.bounds.size.width;
        imageHeight = imageView.bounds.size.height;
        imageLeft = style.horizontalPadding;
    } else {
        imageWidth = imageHeight = imageLeft = 0.0;
    }
    
    if (title != nil) {
        titleLabel = [[UILabel alloc] init];
        titleLabel.numberOfLines = style.titleNumberOfLines;
        titleLabel.font = style.titleFont;
        titleLabel.textAlignment = style.titleAlignment;
        titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
        titleLabel.textColor = style.titleColor;
        titleLabel.backgroundColor = [UIColor clearColor];
        titleLabel.alpha = 1.0;
        titleLabel.text = title;
        
        // size the title label according to the length of the text
        CGSize maxSizeTitle = CGSizeMake((self.bounds.size.width * style.maxWidthPercentage) - imageWidth, self.bounds.size.height * style.maxHeightPercentage);
        CGSize expectedSizeTitle = [self xxte_sizeForString:title font:titleLabel.font constrainedToSize:maxSizeTitle lineBreakMode:titleLabel.lineBreakMode];
        titleLabel.frame = CGRectMake(0.0, 0.0, expectedSizeTitle.width, expectedSizeTitle.height);
    }
    
    if (message != nil) {
        messageLabel = [[UILabel alloc] init];
        messageLabel.numberOfLines = style.messageNumberOfLines;
        messageLabel.font = style.messageFont;
        messageLabel.textAlignment = style.messageAlignment;
        messageLabel.lineBreakMode = NSLineBreakByWordWrapping;
        messageLabel.textColor = style.messageColor;
        messageLabel.backgroundColor = [UIColor clearColor];
        messageLabel.alpha = 1.0;
        messageLabel.text = message;
        
        // size the message label according to the length of the text
        CGSize maxSizeMessage = CGSizeMake((self.bounds.size.width * style.maxWidthPercentage) - imageWidth, self.bounds.size.height * style.maxHeightPercentage);
        CGSize expectedSizeMessage = [self xxte_sizeForString:message font:messageLabel.font constrainedToSize:maxSizeMessage lineBreakMode:messageLabel.lineBreakMode];
        messageLabel.frame = CGRectMake(0.0, 0.0, expectedSizeMessage.width, expectedSizeMessage.height);
    }
    
    // titleLabel frame values
    CGFloat titleWidth, titleHeight, titleTop, titleLeft;
    
    if (titleLabel != nil) {
        titleWidth = titleLabel.bounds.size.width;
        titleHeight = titleLabel.bounds.size.height;
        titleTop = style.verticalPadding;
        titleLeft = imageLeft + imageWidth + style.horizontalPadding;
    } else {
        titleWidth = titleHeight = titleTop = titleLeft = 0.0;
    }
    
    // messageLabel frame values
    CGFloat messageWidth, messageHeight, messageLeft, messageTop;
    
    if (messageLabel != nil) {
        messageWidth = messageLabel.bounds.size.width;
        messageHeight = messageLabel.bounds.size.height;
        messageLeft = imageLeft + imageWidth + style.horizontalPadding;
        messageTop = titleTop + titleHeight + style.verticalPadding;
    } else {
        messageWidth = messageHeight = messageLeft = messageTop = 0.0;
    }
    
    CGFloat longerWidth = MAX(titleWidth, messageWidth);
    CGFloat longerLeft = MAX(titleLeft, messageLeft);
    
    // wrapper width uses the longerWidth or the image width, whatever is larger. same logic applies to the wrapper height
    CGFloat wrapperWidth = MAX((imageWidth + (style.horizontalPadding * 2.0)), (longerLeft + longerWidth + style.horizontalPadding));
    CGFloat wrapperHeight = MAX((messageTop + messageHeight + style.verticalPadding), (imageHeight + (style.verticalPadding * 2.0)));
    
    wrapperView.frame = CGRectMake(0.0, 0.0, wrapperWidth, wrapperHeight);
    
    if (titleLabel != nil) {
        titleLabel.frame = CGRectMake(titleLeft, titleTop, titleWidth, titleHeight);
        [wrapperView addSubview:titleLabel];
    }
    
    if (messageLabel != nil) {
        messageLabel.frame = CGRectMake(messageLeft, messageTop, messageWidth, messageHeight);
        [wrapperView addSubview:messageLabel];
    }
    
    if (imageView != nil) {
        [wrapperView addSubview:imageView];
    }
    
    return wrapperView;
}

#pragma mark - Queue

- (NSMutableArray *)xxte_toastQueue {
    NSMutableArray *xxte_toastQueue = objc_getAssociatedObject(self, &XXTEToastQueueKey);
    if (xxte_toastQueue == nil) {
        xxte_toastQueue = [[NSMutableArray alloc] init];
        objc_setAssociatedObject(self, &XXTEToastQueueKey, xxte_toastQueue, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return xxte_toastQueue;
}

#pragma mark - Events

- (void)xxte_toastTimerDidFinish:(NSTimer *)timer {
    [self xxte_hideToast:(UIView *)timer.userInfo];
}

- (void)xxte_handleToastTapped:(UITapGestureRecognizer *)recognizer {
    UIView *toast = recognizer.view;
    NSTimer *timer = (NSTimer *)objc_getAssociatedObject(toast, &XXTEToastTimerKey);
    [timer invalidate];
    
    [self xxte_hideToast:toast fromTap:YES];
}

#pragma mark - Activity Methods

- (void)makeToastActivity:(id)position {
    // sanity
    UIView *existingActivityView = (UIView *)objc_getAssociatedObject(self, &XXTEToastActivityViewKey);
    if (existingActivityView != nil) return;
    
    XXTEToastStyle *style = [XXTEToastManager sharedStyle];
    
    UIView *activityView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, style.activitySize.width, style.activitySize.height)];
    activityView.center = [self xxte_centerPointForPosition:position withToast:activityView];
    activityView.backgroundColor = style.backgroundColor;
    activityView.alpha = 0.0;
    activityView.autoresizingMask = (UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin);
    activityView.layer.cornerRadius = style.cornerRadius;
    
    if (style.displayShadow) {
        activityView.layer.shadowColor = [UIColor blackColor].CGColor;
        activityView.layer.shadowOpacity = style.shadowOpacity;
        activityView.layer.shadowRadius = style.shadowRadius;
        activityView.layer.shadowOffset = style.shadowOffset;
    }
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    UIActivityIndicatorView *activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
#pragma clang diagnostic pop
    activityIndicatorView.center = CGPointMake(activityView.bounds.size.width / 2, activityView.bounds.size.height / 2);
    [activityView addSubview:activityIndicatorView];
    [activityIndicatorView startAnimating];
    
    // associate the activity view with self
    objc_setAssociatedObject (self, &XXTEToastActivityViewKey, activityView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    [self addSubview:activityView];
    
    [UIView animateWithDuration:XXTEToastFadeDuration
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        activityView.alpha = 1.0;
    } completion:nil];
}

- (void)hideToastActivity {
    UIView *existingActivityView = (UIView *)objc_getAssociatedObject(self, &XXTEToastActivityViewKey);
    if (existingActivityView != nil) {
        [UIView animateWithDuration:XXTEToastFadeDuration
                              delay:0.0
                            options:(UIViewAnimationOptionCurveEaseIn | UIViewAnimationOptionBeginFromCurrentState)
                         animations:^{
            existingActivityView.alpha = 0.0;
        } completion:^(BOOL finished) {
            [existingActivityView removeFromSuperview];
            objc_setAssociatedObject (self, &XXTEToastActivityViewKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }];
    }
}

#pragma mark - Helpers

- (CGPoint)xxte_centerPointForPosition:(id)point withToast:(UIView *)toast {
    XXTEToastStyle *style = [XXTEToastManager sharedStyle];
    
    if ([point isKindOfClass:[NSString class]]) {
        if ([point caseInsensitiveCompare:XXTEToastPositionTop] == NSOrderedSame) {
            return CGPointMake(self.bounds.size.width / 2, (toast.frame.size.height / 2) + self.safeAreaInsets.top + style.verticalPadding + style.verticalMargin);
        } else if ([point caseInsensitiveCompare:XXTEToastPositionCenter] == NSOrderedSame) {
            return CGPointMake(self.bounds.size.width / 2, self.bounds.size.height / 2);
        }
    } else if ([point isKindOfClass:[NSValue class]]) {
        return [point CGPointValue];
    }
    
    // default to bottom
    return CGPointMake(self.bounds.size.width/2, (self.bounds.size.height - (toast.frame.size.height / 2)) - style.verticalPadding - style.verticalMargin);
}

- (CGSize)xxte_sizeForString:(NSString *)string font:(UIFont *)font constrainedToSize:(CGSize)constrainedSize lineBreakMode:(NSLineBreakMode)lineBreakMode {
    if ([string respondsToSelector:@selector(boundingRectWithSize:options:attributes:context:)]) {
        NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
        paragraphStyle.lineBreakMode = lineBreakMode;
        NSDictionary *attributes = @{NSFontAttributeName:font, NSParagraphStyleAttributeName:paragraphStyle};
        CGRect boundingRect = [string boundingRectWithSize:constrainedSize options:NSStringDrawingUsesLineFragmentOrigin attributes:attributes context:nil];
        return CGSizeMake(ceilf(boundingRect.size.width), ceilf(boundingRect.size.height));
    }
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [string sizeWithFont:font constrainedToSize:constrainedSize lineBreakMode:lineBreakMode];
#pragma clang diagnostic pop
}

@end

@implementation XXTEToastStyle

#pragma mark - Constructors

- (instancetype)initWithDefaultStyle {
    self = [super init];
    if (self) {
        self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.6];
        self.titleColor = [UIColor whiteColor];
        self.messageColor = [UIColor whiteColor];
        self.maxWidthPercentage = 0.8;
        self.maxHeightPercentage = 0.8;
        self.horizontalPadding = 10.0;
        self.verticalPadding = 10.0;
        self.cornerRadius = 10.0;
        self.titleFont = [UIFont boldSystemFontOfSize:14.0];
        self.messageFont = [UIFont systemFontOfSize:14.0];
        self.titleAlignment = NSTextAlignmentLeft;
        self.messageAlignment = NSTextAlignmentLeft;
        self.titleNumberOfLines = 0;
        self.messageNumberOfLines = 0;
        self.displayShadow = NO;
        self.shadowOpacity = 0.8;
        self.shadowRadius = 6.0;
        self.shadowOffset = CGSizeMake(4.0, 4.0);
        self.imageSize = CGSizeMake(80.0, 80.0);
        self.activitySize = CGSizeMake(80.0, 80.0);
        self.verticalMargin = 16.f;
    }
    return self;
}

- (void)setMaxWidthPercentage:(CGFloat)maxWidthPercentage {
    _maxWidthPercentage = MAX(MIN(maxWidthPercentage, 1.0), 0.0);
}

- (void)setMaxHeightPercentage:(CGFloat)maxHeightPercentage {
    _maxHeightPercentage = MAX(MIN(maxHeightPercentage, 1.0), 0.0);
}

- (instancetype)init NS_UNAVAILABLE {
    return nil;
}

@end

@interface XXTEToastManager ()

@property (strong, nonatomic) XXTEToastStyle *sharedStyle;
@property (assign, nonatomic, getter=isTapToDismissEnabled) BOOL tapToDismissEnabled;
@property (assign, nonatomic, getter=isQueueEnabled) BOOL queueEnabled;
@property (assign, nonatomic) NSTimeInterval defaultDuration;
@property (strong, nonatomic) id defaultPosition;

@end

@implementation XXTEToastManager

#pragma mark - Constructors

+ (instancetype)sharedManager {
    static XXTEToastManager *_sharedManager = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        _sharedManager = [[self alloc] init];
    });
    
    return _sharedManager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.sharedStyle = [[XXTEToastStyle alloc] initWithDefaultStyle];
        self.tapToDismissEnabled = YES;
        self.queueEnabled = NO;
        self.defaultDuration = 2.0;
        self.defaultPosition = XXTEToastPositionCenter;
    }
    return self;
}

#pragma mark - Singleton Methods

+ (void)setSharedStyle:(XXTEToastStyle *)sharedStyle {
    [[self sharedManager] setSharedStyle:sharedStyle];
}

+ (XXTEToastStyle *)sharedStyle {
    return [[self sharedManager] sharedStyle];
}

+ (void)setTapToDismissEnabled:(BOOL)tapToDismissEnabled {
    [[self sharedManager] setTapToDismissEnabled:tapToDismissEnabled];
}

+ (BOOL)isTapToDismissEnabled {
    return [[self sharedManager] isTapToDismissEnabled];
}

+ (void)setQueueEnabled:(BOOL)queueEnabled {
    [[self sharedManager] setQueueEnabled:queueEnabled];
}

+ (BOOL)isQueueEnabled {
    return [[self sharedManager] isQueueEnabled];
}

+ (void)setDefaultDuration:(NSTimeInterval)duration {
    [[self sharedManager] setDefaultDuration:duration];
}

+ (NSTimeInterval)defaultDuration {
    return [[self sharedManager] defaultDuration];
}

+ (void)setDefaultPosition:(id)position {
    if ([position isKindOfClass:[NSString class]] || [position isKindOfClass:[NSValue class]]) {
        [[self sharedManager] setDefaultPosition:position];
    }
}

+ (id)defaultPosition {
    return [[self sharedManager] defaultPosition];
}

@end
