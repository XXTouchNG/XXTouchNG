//
//  TMWeakUserContentControllerWrapper.h
//  TamperMonkey
//
//  Created by Darwin on 12/21/21.
//  Copyright (c) 2021 XXTouch Team. All rights reserved.
//

#import <WebKit/WebKit.h>
#import "TMWeakObjectWrapper.h"

NS_ASSUME_NONNULL_BEGIN

@interface TMWeakUserContentControllerWrapper : NSObject
@property (nonatomic, weak, readonly) WKUserContentController *userContentController;
@property (nonatomic, strong, readonly) NSArray <TMWeakObjectWrapper *> *weakProxies;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithUserContentController:(WKUserContentController *)userContentController NS_DESIGNATED_INITIALIZER;
- (void)addWeakProxy:(TMWeakObjectWrapper *)proxyWrapper;
- (void)removeNilProxies;

@end

NS_ASSUME_NONNULL_END
