//
//  AHWeakObjectWrapper.h
//  AlertHelper
//
//  Created by Darwin on 12/21/21.
//  Copyright (c) 2021 XXTouch Team. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface AHWeakObjectWrapper : NSObject
@property (nonatomic, weak, readonly) NSObject *weakObject;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithWeakObject:(NSObject *)weakObject NS_DESIGNATED_INITIALIZER;
@end

NS_ASSUME_NONNULL_END
