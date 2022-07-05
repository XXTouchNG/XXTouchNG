//
//  TMScriptMessageProxy.h
//  TamperMonkey
//
//  Created by Darwin on 12/21/21.
//  Copyright (c) 2021 XXTouch Team. All rights reserved.
//

#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface TMScriptMessageProxy : NSObject <WKScriptMessageHandler>
@property (nonatomic, strong, readonly) NSArray <NSDictionary *> *receivedMessages;
- (void)removeAllReceivedMessages;
@end

NS_ASSUME_NONNULL_END
