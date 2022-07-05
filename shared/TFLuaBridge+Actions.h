//
//  TFLuaBridge+Actions.h
//  XXTouch
//
//  Created by Darwin on 10/14/20.
//

#import "TFLuaBridge+IMP.h"

NS_ASSUME_NONNULL_BEGIN

NS_PROTOCOL_REQUIRES_EXPLICIT_IMPLEMENTATION @protocol TFLuaBridgeActionHandler
@required
- (nullable NSDictionary *)handleRemoteActionWithRequest:(NSDictionary *)request;
@end

@interface TFLuaBridge (Actions) <TFLuaBridgeActionHandler>
@end

NS_ASSUME_NONNULL_END
