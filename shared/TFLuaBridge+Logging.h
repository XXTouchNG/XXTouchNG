//
//  TFLuaBridge+Logging.h
//  XXTouch
//
//  Created by Darwin on 10/14/20.
//

#import "TFLuaBridge+IMP.h"

NS_ASSUME_NONNULL_BEGIN

@interface TFLuaBridge (Logging)

- (void)logObject:(id)object;

#if DEBUG
+ (unsigned long)__getMemoryUsedInBytes;
#endif

@end

NS_ASSUME_NONNULL_END
