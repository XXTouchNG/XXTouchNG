//
//  AHWeakObjectWrapper.m
//  AlertHelper
//
//  Created by Darwin on 12/21/21.
//  Copyright (c) 2021 XXTouch Team. All rights reserved.
//

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import "AHWeakObjectWrapper.h"

@implementation AHWeakObjectWrapper

@synthesize weakObject = _weakObject;

- (instancetype)initWithWeakObject:(NSObject *)weakObject {
    if (self = [super init]) {
        _weakObject = weakObject;
    }
    return self;
}

@end
