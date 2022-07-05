//
//  TMWeakViewWrapper.m
//  TamperMonkey
//
//  Created by Darwin on 12/21/21.
//  Copyright (c) 2021 XXTouch Team. All rights reserved.
//

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import "TMWeakViewWrapper.h"

@implementation TMWeakViewWrapper

@synthesize weakView = _weakView;
@synthesize uniqueIdentifier = _uniqueIdentifier;

- (instancetype)initWithWeakView:(UIView *)weakView forUniqueIdentifier:(NSString *)uniqueIdentifier {
    if (self = [super init]) {
        _weakView = weakView;
        _uniqueIdentifier = uniqueIdentifier;
    }
    return self;
}

@end
