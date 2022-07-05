//
//  TMWeakViewWrapper.h
//  TamperMonkey
//
//  Created by Darwin on 12/21/21.
//  Copyright (c) 2021 XXTouch Team. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface TMWeakViewWrapper : NSObject
@property (nonatomic, weak, readonly) UIView *weakView;
@property (nonatomic, copy, readonly) NSString *uniqueIdentifier;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithWeakView:(UIView *)weakView forUniqueIdentifier:(NSString *)uniqueIdentifier NS_DESIGNATED_INITIALIZER;
@end

NS_ASSUME_NONNULL_END
