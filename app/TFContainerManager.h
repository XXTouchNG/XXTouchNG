//
//  TFContainerManager.h
//  TFContainerManager
//
//  Created by Darwin on 2/21/22.
//  Copyright (c) 2022 XXTouch Team. All rights reserved.
//

#ifndef TFContainerManager_h
#define TFContainerManager_h

#import <Foundation/Foundation.h>
#import <AppSupport/CPDistributedMessagingCenter.h>


#define TFContainerErrorDomain   "ch.xxtou.error.container"

#define NP_APP_INSTALLED         "com.apple.mobile.application_installed"
#define NP_APP_UNINSTALLED       "com.apple.mobile.application_uninstalled"

#ifdef __OBJC__

NS_ASSUME_NONNULL_BEGIN
@interface TFAppItem : NSObject

@property (nonatomic, copy)             NSString                                *identifier;
@property (nullable, nonatomic, copy)   NSString                                *version;
@property (nullable, nonatomic, copy)   NSString                                *type;
@property (nullable, nonatomic, copy)   NSString                                *name;
@property (nullable, nonatomic, strong) NSData                                  *iconData;
@property (nullable, nonatomic, copy)   NSString                                *appleId;
@property (nullable, nonatomic, copy)   NSString                                *bundlePath;
@property (nullable, nonatomic, copy)   NSString                                *bundleContainer;
@property (nullable, nonatomic, copy)   NSString                                *dataContainer;
@property (nullable, nonatomic, strong) NSDictionary <NSString *, NSString *>   *groupContainers;
@property (nullable, nonatomic, strong) NSDictionary <NSString *, NSString *>   *pluginDataContainers;
@property (nullable, nonatomic, copy)   NSURL                                   *bundleURL;
@property (nullable, nonatomic, copy)   NSURL                                   *bundleContainerURL;
@property (nullable, nonatomic, copy)   NSURL                                   *dataContainerURL;
@property (nullable, nonatomic, strong) NSDictionary <NSString *, NSURL *>      *groupContainerURLs;
@property (nullable, nonatomic, strong) NSDictionary <NSString *, NSURL *>      *pluginDataContainerURLs;
@property (nullable, nonatomic, strong) NSDictionary <NSString *, id>           *entitlements;
@property (nonatomic, assign)           pid_t                                    processIdentifier;

- (NSDictionary *)toDictionaryWithIconData:(BOOL)needsIcon;
- (NSDictionary *)toDictionaryWithIconData:(BOOL)needsIcon entitlements:(BOOL)needsEntitlements;
- (NSDictionary *)toDictionaryWithIconData:(BOOL)needsIcon
                              entitlements:(BOOL)needsEntitlements
                                    legacy:(BOOL)needsLegacyFields;

- (instancetype)initWithDictionary:(NSDictionary *)otherDictionary;

- (BOOL)launch;
- (BOOL)launchWithError:(NSError *__autoreleasing*)error;
- (BOOL)launchInBackground:(BOOL)inBackground;
- (BOOL)launchInBackground:(BOOL)inBackground error:(NSError *__autoreleasing*)error;
- (BOOL)terminate;
- (BOOL)isRunning;
- (BOOL)isFrontmostApp;
- (BOOL)isFrontmostAppWithError:(NSError *__autoreleasing*)error;
- (pid_t)getProcessIdentifier;

@end


typedef NS_ENUM(NSUInteger, TFContainerManagerRole) {
    TFContainerManagerRoleClient = 0,
    TFContainerManagerRoleServer,
};

typedef NS_OPTIONS(NSUInteger, TFContainerManagerFetchOptions) {
    TFContainerManagerFetchDefault = 0,
    TFContainerManagerFetchWithIconData = 1 << 0,
    TFContainerManagerFetchWithEntitlements = 1 << 1,
    TFContainerManagerFetchWithSystemApplications = 1 << 29,
    TFContainerManagerFetchUsesAppList = 1 << 30,
};

@interface TFContainerManager : NSObject

@property (nonatomic, strong, readonly) CPDistributedMessagingCenter *messagingCenter;
@property (nonatomic, assign, readonly) TFContainerManagerRole role;

+ (instancetype)sharedManager;
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

- (nullable NSArray <TFAppItem *> *)appItemsWithError:(NSError *__autoreleasing  _Nullable *)error;
- (nullable NSArray <TFAppItem *> *)userAppItemsWithError:(NSError *__autoreleasing  _Nullable *)error;
- (nullable NSArray <TFAppItem *> *)runningAppItemsWithError:(NSError *__autoreleasing  _Nullable *)error;

- (nullable TFAppItem             *)appItemForIdentifier:(NSString *)identifier error:(NSError *__autoreleasing  _Nullable *)error;
- (nullable TFAppItem             *)userAppItemForIdentifier:(NSString *)identifier error:(NSError *__autoreleasing  _Nullable *)error;

- (nullable NSArray <TFAppItem *> *)appItemsWithOptions:(TFContainerManagerFetchOptions)options error:(NSError *__autoreleasing  _Nullable *)error;
- (nullable NSArray <TFAppItem *> *)runningAppItemsWithOptions:(TFContainerManagerFetchOptions)options error:(NSError *__autoreleasing  _Nullable *)error;

- (nullable TFAppItem             *)appItemForIdentifier:(NSString *)identifier options:(TFContainerManagerFetchOptions)options error:(NSError *__autoreleasing  _Nullable *)error;
- (nullable NSArray <TFAppItem *> *)searchAppItemsWithDisplayName:(NSString *)displayName options:(TFContainerManagerFetchOptions)options error:(NSError *__autoreleasing  _Nullable *)error;

- (BOOL                            )launchAppWithIdentifier:(NSString *)identifier error:(NSError *__autoreleasing  _Nullable *)error;
- (BOOL                            )launchAppWithIdentifier:(NSString *)identifier inBackground:(BOOL)inBackground error:(NSError *__autoreleasing  _Nullable *)error;
- (BOOL                            )terminateAppWithIdentifier:(NSString *)identifier;
- (BOOL                            )terminateAllApp;
- (nullable NSString              *)frontmostAppIdentifierWithError:(NSError *__autoreleasing  _Nullable *)error;
- (pid_t                           )processIdentifierForAppIdentifier:(NSString *)identifier;

- (BOOL                            )installIPAArchiveAtPath:(NSString *)path removeAfterInstallation:(BOOL)remove error:(NSError *__autoreleasing  _Nullable *)error;
- (BOOL                            )uninstallApplicationWithIdentifier:(NSString *)identifier error:(NSError *__autoreleasing  _Nullable *)error;
- (BOOL                            )packAppWithIdentifier:(NSString *)identifier toIPAArchivePath:(NSString *)ipaPath error:(NSError *__autoreleasing  _Nullable * _Nullable)error;
- (BOOL                            )packBundleContainerAtPath:(NSString *)path toIPAArchivePath:(NSString *)ipaPath error:(NSError *__autoreleasing  _Nullable * _Nullable)error;

- (BOOL                            )openSensitiveURL:(NSURL *)url error:(NSError *__autoreleasing  _Nullable * _Nullable)error;
- (BOOL                            )openSensitiveURLWithString:(NSString *)urlString error:(NSError *__autoreleasing  _Nullable * _Nullable)error;

@end


@class LSApplicationProxy;
@class LSPlugInKitProxy;

NS_ASSUME_NONNULL_END
#endif

NS_ASSUME_NONNULL_BEGIN
#ifdef __cplusplus
extern "C" {
#endif

LSApplicationProxy    *_Nullable TFUserAppProxyForIdentifier(NSString *identifier);
LSApplicationProxy    *_Nullable TFAppProxyForIdentifier(NSString *identifier);
LSPlugInKitProxy      *_Nullable TFPlugInKitProxyForIdentifier(NSString *identifier);

NSArray <TFAppItem *> *TFCopyAppItems(BOOL userOnly, TFContainerManagerFetchOptions options, NSError *__autoreleasing  _Nullable * _Nullable error);

TFAppItem   *_Nullable TFCopyUserAppItemForIdentifier(NSString *identifier, TFContainerManagerFetchOptions options, NSError *__autoreleasing  _Nullable * _Nullable error);
TFAppItem   *_Nullable TFCopyAppItemForIdentifier(NSString *identifier, TFContainerManagerFetchOptions options, NSError *__autoreleasing  _Nullable * _Nullable error);
TFAppItem   *_Nullable TFAppItemForProxy(LSApplicationProxy *application, TFContainerManagerFetchOptions options, NSError *__autoreleasing  _Nullable * _Nullable error);

BOOL                   TFLaunchAppWithIdentifier(NSString *identifier, BOOL inBackground, NSError *__autoreleasing  _Nullable * _Nullable error);
NSString    *_Nullable TFFrontmostAppIdentifier(NSError *__autoreleasing  _Nullable * _Nullable error);

BOOL                   TFInstallIPAArchiveAtPath(NSString *path, BOOL removeAfterInstallation, NSError *__autoreleasing  _Nullable * _Nullable error);
BOOL                   TFUninstallAppWithIdentifier(NSString *identifier, NSError *__autoreleasing  _Nullable * _Nullable error);
BOOL                   TFPackBundleContainerAtPath(NSString *path, NSString *toIPAPath, NSError *__autoreleasing  _Nullable * _Nullable error);
BOOL                   TFOpenSensitiveURL(NSURL *url, NSError *__autoreleasing  _Nullable * _Nullable error);

#ifdef __cplusplus
}
#endif
NS_ASSUME_NONNULL_END

#endif  /* TFContainerManager_h */
