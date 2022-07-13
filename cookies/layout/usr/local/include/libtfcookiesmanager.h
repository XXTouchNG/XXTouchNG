#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TFCookiesManager : NSObject

@property (nonatomic, copy, readonly) NSString *binaryCookiesPath;

+ (instancetype)sharedSafariManager;
+ (NSDateFormatter *)sharedCookiesDateFormatter;

+ (nullable instancetype)managerWithBundleIdentifier:(NSString *)bundleIdentifier;
+ (nullable instancetype)managerWithBundleIdentifier:(NSString *)bundleIdentifier groupIdentifier:(NSString *)groupIdentifier;
+ (nullable instancetype)managerWithBundleIdentifier:(NSString *)bundleIdentifier pluginIdentifier:(NSString *)pluginIdentifier;
+ (nullable instancetype)managerWithAnyIdentifier:(NSString *)anyIdentifier;

- (instancetype)initWithBinaryCookiesPath:(NSString *)binaryCookiesPath;

- (nullable NSArray <NSDictionary <NSHTTPCookiePropertyKey, id> *> *)readCookiesWithError:(NSError * _Nullable __autoreleasing * _Nullable)error;
- (nullable NSArray <NSDictionary <NSHTTPCookiePropertyKey, id> *> *)filterCookiesWithDomain:(NSString *)domain
                                                                                        path:(NSString *)path
                                                                                       error:(NSError * _Nullable __autoreleasing * _Nullable)error;

- (nullable NSDictionary <NSHTTPCookiePropertyKey, id> *)getCookiesWithDomain:(NSString *)domain
                                                                         path:(NSString *)path
                                                                         name:(NSString *)name
                                                                        error:(NSError * _Nullable __autoreleasing * _Nullable)error;

- (BOOL)setCookies:(NSArray <NSDictionary <NSHTTPCookiePropertyKey, id> *> *)cookies
             error:(NSError * _Nullable __autoreleasing * _Nullable)error;

- (BOOL)writeCookies:(NSArray <NSDictionary <NSHTTPCookiePropertyKey, id> *> *)cookies
               error:(NSError * _Nullable __autoreleasing * _Nullable)error;

- (BOOL)removeCookiesWithDomain:(NSString *)domain
                           path:(NSString *)path
                           name:(NSString *)name
                          error:(NSError * _Nullable __autoreleasing * _Nullable)error;

- (BOOL)removeCookiesExpiredBeforeDate:(NSDate *)date error:(NSError * _Nullable __autoreleasing * _Nullable)error;

- (BOOL)clearCookiesWithError:(NSError * _Nullable __autoreleasing * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
