//
//  TMWeakUserContentControllerWrapper.m
//  TamperMonkey
//
//  Created by Darwin on 12/21/21.
//  Copyright (c) 2021 XXTouch Team. All rights reserved.
//

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import "TMWeakUserContentControllerWrapper.h"

@implementation TMWeakUserContentControllerWrapper {
    NSMutableArray <TMWeakObjectWrapper *> *_weakProxies;
}

@synthesize userContentController = _userContentController;

- (instancetype)initWithUserContentController:(WKUserContentController *)userContentController {
    if (self = [super init]) {
        _userContentController = userContentController;
        _weakProxies = [[NSMutableArray alloc] init];
    }
    return self;
}

- (NSArray <TMWeakObjectWrapper *> *)weakProxies {
    @autoreleasepool {
        return [_weakProxies copy];
    }
}

- (void)addWeakProxy:(TMWeakObjectWrapper *)proxyWrapper {
    if (![_weakProxies containsObject:proxyWrapper]) {
        [_weakProxies addObject:proxyWrapper];
    }
}

- (void)removeNilProxies {
    @autoreleasepool {
        NSMutableArray <TMWeakObjectWrapper *> *proxiesToRemove = [NSMutableArray arrayWithCapacity:_weakProxies.count];
        for (TMWeakObjectWrapper *wrapper in _weakProxies) {
            if (wrapper.weakObject == nil) {
                [proxiesToRemove addObject:wrapper];
            }
        }
        [_weakProxies removeObjectsInArray:proxiesToRemove];
    }
}

@end
