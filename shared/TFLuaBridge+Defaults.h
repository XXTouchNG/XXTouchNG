//
//  TFLuaBridge+Defaults.h
//  XXTouch
//
//  Created by Darwin on 10/14/20.
//

#import "TFLuaBridge+IMP.h"

NS_ASSUME_NONNULL_BEGIN

@protocol TFLuaBridgeDefaultsReloading <NSObject>

@optional
- (void)defaultsDidReload;

@end

@interface TFLuaBridge (Defaults) <TFLuaBridgeDefaultsReloading>

- (void)setupDefaultsReloadNotifications;

- (NSDictionary *)readDefaultsWithError:(NSError *__autoreleasing*)error;
- (BOOL)writeDefaults:(NSDictionary *)defaults withError:(NSError *__autoreleasing*)error;
- (BOOL)addEnteriesToDefaults:(NSDictionary *)defaults withError:(NSError *__autoreleasing*)error;

- (NSDictionary *)clientReadDefaults:(NSString *)messageName userInfo:(NSDictionary *)userInfo;
- (NSDictionary *)serverWriteDefaults:(NSString *)messageName userInfo:(NSDictionary *)userInfo;

@end

NS_ASSUME_NONNULL_END
