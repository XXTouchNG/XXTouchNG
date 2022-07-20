#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import <dlfcn.h>
#import <notify.h>
#import <pthread.h>
#import <sys/sysctl.h>
#import <objc/runtime.h>
#import <Foundation/Foundation.h>

#import "TFContainerManager.h"
#import "TFLuaBridge.h"
#import "TFShell.h"
#import <AppList/AppList.h>


#pragma mark - Private APIs

typedef CFArrayRef        (*SBSCopyApplicationDisplayIdentifiers)(bool, bool);
typedef CFStringRef       (*SBSCopyLocalizedApplicationNameForDisplayIdentifier)(CFStringRef);
typedef CFDataRef         (*SBSCopyIconImagePNGDataForDisplayIdentifier)(CFStringRef);
typedef CFStringRef       (*SBFrontmostApplicationDisplayIdentifier)(mach_port_t *, char *);
typedef mach_port_t      *(*SBSSpringBoardServerPort)(void);
typedef int               (*SBSLaunchApplicationWithIdentifier)(CFStringRef, bool);
typedef CFStringRef       (*SBSApplicationLaunchingErrorString)(int);

OBJC_EXTERN SBSCopyIconImagePNGDataForDisplayIdentifier TFCopyIconImagePNGDataForDisplayIdentifier;
OBJC_EXTERN SBFrontmostApplicationDisplayIdentifier     TFFrontmostApplicationDisplayIdentifier;
OBJC_EXTERN SBSSpringBoardServerPort                    TFSpringBoardServerPort;

OBJC_EXTERN NSString *     kLSApplicationTypeSystem;
OBJC_EXTERN NSString *     kLSApplicationTypeUser;
OBJC_EXTERN NSString *     MCMContainerTypeBundle NS_AVAILABLE_IOS(12.0);
OBJC_EXTERN NSString *     MCMContainerTypeData   NS_AVAILABLE_IOS(12.0);
OBJC_EXTERN NSString *     MCMContainerTypeGroup  NS_AVAILABLE_IOS(12.0);
OBJC_EXTERN NSString *     MCMContainerTypePlugin NS_AVAILABLE_IOS(12.0);

SBSCopyIconImagePNGDataForDisplayIdentifier TFCopyIconImagePNGDataForDisplayIdentifier = NULL;
SBFrontmostApplicationDisplayIdentifier     TFFrontmostApplicationDisplayIdentifier    = NULL;
SBSSpringBoardServerPort                    TFSpringBoardServerPort                    = NULL;
SBSLaunchApplicationWithIdentifier          TFLaunchApplicationWithIdentifier          = NULL;
SBSApplicationLaunchingErrorString          TFApplicationLaunchingErrorString          = NULL;

#import "MCMContainer.h"
#import "MCMContainerManager.h"
NSString *MCMContainerTypeBundle  = @"MCMAppContainer";
NSString *MCMContainerTypeData    = @"MCMAppDataContainer";
NSString *MCMContainerTypeGroup   = @"MCMSharedDataContainer";
NSString *MCMContainerTypePlugin  = @"MCMPluginKitPluginDataContainer";
static void *TFGetMobileContainerManager() {
    static dispatch_once_t onceToken;
    static void *MobileContainerManager = NULL;
    dispatch_once(&onceToken, ^{
        MobileContainerManager = dlopen("/System/Library/PrivateFrameworks/MobileContainerManager.framework/MobileContainerManager", RTLD_LAZY);
    });
    assert(MobileContainerManager);
    return MobileContainerManager;
}

#import "LSApplicationProxy.h"
#import "LSApplicationWorkspace.h"
#import "LSPlugInKitProxy.h"
NSString *kLSApplicationTypeSystem = @"System";
NSString *kLSApplicationTypeUser = @"User";
static void *TFGetSpringBoardServices() {
    static dispatch_once_t onceToken;
    static void *SpringBoardServices = NULL;
    dispatch_once(&onceToken, ^{
        SpringBoardServices = dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_LAZY);
        if (SpringBoardServices) {
            TFCopyIconImagePNGDataForDisplayIdentifier = (SBSCopyIconImagePNGDataForDisplayIdentifier)dlsym(SpringBoardServices, "SBSCopyIconImagePNGDataForDisplayIdentifier");
            NSCAssert(TFCopyIconImagePNGDataForDisplayIdentifier, @"SBSCopyIconImagePNGDataForDisplayIdentifier");
            TFLaunchApplicationWithIdentifier = (SBSLaunchApplicationWithIdentifier)dlsym(SpringBoardServices, "SBSLaunchApplicationWithIdentifier");
            NSCAssert(TFLaunchApplicationWithIdentifier, @"SBSLaunchApplicationWithIdentifier");
            TFApplicationLaunchingErrorString = (SBSApplicationLaunchingErrorString)dlsym(SpringBoardServices, "SBSApplicationLaunchingErrorString");
            NSCAssert(TFApplicationLaunchingErrorString, @"SBSApplicationLaunchingErrorString");
            TFFrontmostApplicationDisplayIdentifier = (SBFrontmostApplicationDisplayIdentifier)dlsym(SpringBoardServices, "SBFrontmostApplicationDisplayIdentifier");
            NSCAssert(TFFrontmostApplicationDisplayIdentifier, @"SBFrontmostApplicationDisplayIdentifier");
            TFSpringBoardServerPort = (SBSSpringBoardServerPort)dlsym(SpringBoardServices, "SBSSpringBoardServerPort");
            NSCAssert(TFSpringBoardServerPort, @"TFSpringBoardServerPort");
        }
    });
    assert(SpringBoardServices);
    return SpringBoardServices;
}


#pragma mark - Instances

@implementation TFAppItem

@synthesize bundlePath = _bundlePath;
@synthesize bundleURL = _bundleURL;
@synthesize bundleContainer = _bundleContainer;
@synthesize bundleContainerURL = _bundleContainerURL;
@synthesize dataContainer = _dataContainer;
@synthesize dataContainerURL = _dataContainerURL;
@synthesize groupContainers = _groupContainers;
@synthesize groupContainerURLs = _groupContainerURLs;
@synthesize pluginDataContainers = _pluginDataContainers;
@synthesize pluginDataContainerURLs = _pluginDataContainerURLs;
@synthesize entitlements = _entitlements;
@synthesize processIdentifier = _processIdentifier;

- (NSDictionary *)toDictionaryWithIconData:(BOOL)needsIcon {
    return [self toDictionaryWithIconData:needsIcon entitlements:NO legacy:NO];
}

- (NSDictionary *)toDictionaryWithIconData:(BOOL)needsIcon entitlements:(BOOL)needsEntitlements {
    return [self toDictionaryWithIconData:needsIcon entitlements:needsEntitlements legacy:NO];
}

- (NSDictionary *)toDictionaryWithIconData:(BOOL)needsIcon
                              entitlements:(BOOL)needsEntitlements
                                    legacy:(BOOL)needsLegacyFields
{
    
    NSMutableDictionary <NSString *, id> *mDict = [NSMutableDictionary dictionaryWithDictionary:@{
        @"bid": self.identifier,
        @"identifier": self.identifier,
    }];
    
    if (self.name) {
        mDict[@"name"] = self.name;
    }
    
    if (self.version) {
        mDict[@"version"] = self.version;
    }
    
    if (self.type) {
        mDict[@"type"] = self.type;
    }
    
    if (self.bundleContainer) {
        mDict[@"bundle_path"] = self.bundlePath;
        mDict[@"bundle_container"] = self.bundleContainer;
    }
    
    if (self.dataContainer) {
        if (needsLegacyFields) {
            mDict[@"data_path"] = self.dataContainer;
        } else {
            mDict[@"data_container"] = self.dataContainer;
        }
    }
    
    if (self.groupContainers) {
        if (needsLegacyFields) {
            mDict[@"group_paths"] = self.groupContainers;
        } else {
            mDict[@"group_containers"] = self.groupContainers;
        }
    }
    
    if (self.pluginDataContainers) {
        if (needsLegacyFields) {
            mDict[@"plugin_paths"] = self.pluginDataContainers;
        } else {
            mDict[@"plugin_containers"] = self.pluginDataContainers;
        }
    }
    
    if (self.appleId) {
        mDict[@"apple_id"] = self.appleId;
    }
    
    if (needsIcon && self.iconData) {
        mDict[@"icon"] = [self.iconData base64EncodedStringWithOptions:kNilOptions];
    }
    
    if (needsEntitlements && self.entitlements) {
        mDict[@"entitlements"] = [[NSPropertyListSerialization dataWithPropertyList:self.entitlements format:NSPropertyListBinaryFormat_v1_0 options:kNilOptions error:nil] base64EncodedStringWithOptions:kNilOptions];
    }
    
    mDict[@"processIdentifier"] = @(self.processIdentifier);
    
    return mDict;
}

- (instancetype)initWithDictionary:(NSDictionary *)otherDictionary {
    self = [super init];
    if (self) {
        
        NSString *identifier = otherDictionary[@"identifier"];
        NSAssert1([identifier isKindOfClass:[NSString class]], @"invalid identifier %@", identifier);
        self.identifier = identifier;
        
        self.version = otherDictionary[@"version"];
        self.type = otherDictionary[@"type"];
        self.name = otherDictionary[@"name"];
        
        if ([otherDictionary[@"icon"] isKindOfClass:[NSString class]]) {
            self.iconData = [[NSData alloc] initWithBase64EncodedString:otherDictionary[@"icon"] options:kNilOptions];
        }
        
        self.appleId = otherDictionary[@"apple_id"];
        self.bundlePath = otherDictionary[@"bundle_path"];
        self.bundleContainer = otherDictionary[@"bundle_container"];
        self.dataContainer = otherDictionary[@"data_container"];
        self.groupContainers = otherDictionary[@"group_containers"];
        self.pluginDataContainers = otherDictionary[@"plugin_containers"];
        
        if ([otherDictionary[@"bundle_path"] isKindOfClass:[NSString class]]) {
            self.bundleURL = [NSURL fileURLWithPath:otherDictionary[@"bundle_path"]];
        }
        
        if ([otherDictionary[@"bundle_container"] isKindOfClass:[NSString class]]) {
            self.bundleContainerURL = [NSURL fileURLWithPath:otherDictionary[@"bundle_container"]];
        }
        
        if ([otherDictionary[@"data_container"] isKindOfClass:[NSString class]]) {
            self.dataContainerURL = [NSURL fileURLWithPath:otherDictionary[@"data_container"]];
        }
        
        if ([otherDictionary[@"group_containers"] isKindOfClass:[NSDictionary class]]) {
            NSMutableDictionary <NSString *, NSURL *> *groupContainerURLs = [NSMutableDictionary dictionary];
            NSDictionary <NSString *, NSString *> *groupContainers = otherDictionary[@"group_containers"];
            for (NSString *groupId in groupContainers) {
                if ([groupContainers[groupId] isKindOfClass:[NSString class]]) {
                    groupContainerURLs[groupId] = [NSURL fileURLWithPath:groupContainers[groupId]];
                }
            }
            self.groupContainerURLs = groupContainerURLs;
        }
        
        if ([otherDictionary[@"entitlements"] isKindOfClass:[NSString class]]) {
            NSData *entitlementsData = [[NSData alloc] initWithBase64EncodedString:otherDictionary[@"entitlements"] options:kNilOptions];
            if (entitlementsData) {
                id entitlements = [NSPropertyListSerialization propertyListWithData:entitlementsData options:kNilOptions format:NULL error:nil];
                if ([entitlements isKindOfClass:[NSDictionary class]]) {
                    self.entitlements = (NSDictionary <NSString *, id>           *)entitlements;
                }
            }
        }
        
        if ([otherDictionary[@"processIdentifier"] isKindOfClass:[NSNumber class]]) {
            self.processIdentifier = [otherDictionary[@"processIdentifier"] intValue];
        }
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@", [self toDictionaryWithIconData:NO]];
}

- (NSString *)debugDescription {
    return [NSString stringWithFormat:@"%@", [self toDictionaryWithIconData:YES entitlements:YES]];
}

- (BOOL)launch {
    return [[TFContainerManager sharedManager] launchAppWithIdentifier:self.identifier error:nil];
}

- (BOOL)launchWithError:(NSError *__autoreleasing*)error {
    return [[TFContainerManager sharedManager] launchAppWithIdentifier:self.identifier error:error];
}

- (BOOL)launchInBackground:(BOOL)inBackground {
    return [[TFContainerManager sharedManager] launchAppWithIdentifier:self.identifier inBackground:inBackground error:nil];
}

- (BOOL)launchInBackground:(BOOL)inBackground error:(NSError *__autoreleasing*)error {
    return [[TFContainerManager sharedManager] launchAppWithIdentifier:self.identifier inBackground:inBackground error:error];
}

- (BOOL)isFrontmostApp {
    return [[[TFContainerManager sharedManager] frontmostAppIdentifierWithError:nil] isEqualToString:self.identifier];
}

- (BOOL)isFrontmostAppWithError:(NSError *__autoreleasing*)error {
    return [[[TFContainerManager sharedManager] frontmostAppIdentifierWithError:error] isEqualToString:self.identifier];
}

- (BOOL)terminate {
    return [[TFContainerManager sharedManager] terminateAppWithIdentifier:self.identifier];
}

- (BOOL)isRunning {
    return [[TFContainerManager sharedManager] processIdentifierForAppIdentifier:self.identifier] > 0;
}

- (pid_t)getProcessIdentifier {
    return [[TFContainerManager sharedManager] processIdentifierForAppIdentifier:self.identifier];
}

@end


#pragma mark - Utils

static NSArray <NSString *> *TFGetAppleAppIdentifierWhitelist()
{
    return [TFLuaBridge allowedAppleProductBundleIDs];
}

static NSURL *MCMGetContainerURL(NSString *containerType, NSString *identifier, NSError *__autoreleasing  _Nullable * _Nullable error) {
    if (!TFGetMobileContainerManager()) {
        if (error) {
            *error = [NSError errorWithDomain:@TFContainerErrorDomain code:500 userInfo:@{ NSLocalizedDescriptionKey: @"fail to load MobileContainerManager" }];
        }
        return nil;
    }
    MCMContainer *container = [objc_getClass(containerType.UTF8String) containerWithIdentifier:identifier error:error];
    return container.url;
}

static NSURL *MCMRecreateDefaultContainerStructure(NSString *containerType, NSString *identifier, NSError *__autoreleasing  _Nullable * _Nullable error) {
    if (!TFGetMobileContainerManager()) {
        if (error) {
            *error = [NSError errorWithDomain:@TFContainerErrorDomain code:500 userInfo:@{ NSLocalizedDescriptionKey: @"fail to load MobileContainerManager" }];
        }
        return nil;
    }
    MCMContainer *container = nil;
    Class containerClass = objc_getClass(containerType.UTF8String);
    if (!container) {
        container = [containerClass containerWithIdentifier:identifier error:error];
    }
    if (!container) {
        BOOL existed = NO;
        MCMContainerManager *containerManager = (MCMContainerManager *)[MCMContainerManager defaultManager];
        container = [containerManager containerWithContentClass:[containerClass typeContainerClass] identifier:identifier createIfNecessary:YES existed:&existed error:error];
    }
    BOOL succeed = [container recreateDefaultStructureWithError:error];
    if (!succeed) { return nil; }
    return container.url;
}

static NSMutableDictionary *_kSharedTFAppItemCaches = nil;
static pthread_mutex_t _kSharedTFAppItemCachesLock;

static void TFClearAppItemCaches(void)
{
    pthread_mutex_lock(&_kSharedTFAppItemCachesLock);
    [_kSharedTFAppItemCaches removeAllObjects];
    pthread_mutex_unlock(&_kSharedTFAppItemCachesLock);
}

TFAppItem *TFAppItemForProxy(LSApplicationProxy *application, TFContainerManagerFetchOptions options, NSError *__autoreleasing  _Nullable * _Nullable error)
{
    if (!application.applicationIdentifier) {
        return nil;
    }
    
    pthread_mutex_lock(&_kSharedTFAppItemCachesLock);
    if (_kSharedTFAppItemCaches[application.applicationIdentifier] != nil) {
        TFAppItem *appItem = _kSharedTFAppItemCaches[application.applicationIdentifier];
        if (!(options & TFContainerManagerFetchWithIconData) || appItem.iconData != nil) {
            pthread_mutex_unlock(&_kSharedTFAppItemCachesLock);
            return appItem;
        }
    }
    pthread_mutex_unlock(&_kSharedTFAppItemCachesLock);
    
    NSArray <NSString *> *whitelist = TFGetAppleAppIdentifierWhitelist();
    BOOL useMCM = NO;
    if (@available(iOS 12.0, *)) {
        if (![application.applicationIdentifier hasPrefix:@"com.apple."] ||
            [whitelist containsObject:application.applicationIdentifier])
        {
            useMCM = YES;
        }
    }
    
    NSMutableDictionary <NSString *, NSURL *>    *groupContainerURLs  = [NSMutableDictionary dictionary];
    NSMutableDictionary <NSString *, NSString *> *groupContainerPaths = [NSMutableDictionary dictionary];
    for (NSString *groupContaierIdentifier in application.groupContainerURLs) {
        
        NSURL *groupContainerURL     = nil;
        NSString *groupContainerPath = nil;
        
        if (useMCM) {
            groupContainerURL  = MCMGetContainerURL(MCMContainerTypeGroup, groupContaierIdentifier, error);
            if (!groupContainerURL) {
                groupContainerURL = MCMRecreateDefaultContainerStructure(MCMContainerTypeGroup, groupContaierIdentifier, error);
            }
            groupContainerPath = [groupContainerURL path];
        } else {
            groupContainerURL  = application.groupContainerURLs[groupContaierIdentifier];
            groupContainerPath = [groupContainerURL path];
        }
        
        if (!groupContainerURL || !groupContainerPath) {
            continue;
        }
        
        [groupContainerURLs setObject:groupContainerURL forKey:groupContaierIdentifier];
        [groupContainerPaths setObject:groupContainerPath forKey:groupContaierIdentifier];
        
    }
    
    NSMutableDictionary <NSString *, NSURL *>    *pluginDataContainerURLs  = [NSMutableDictionary dictionary];
    NSMutableDictionary <NSString *, NSString *> *pluginDataContainerPaths = [NSMutableDictionary dictionary];
    for (LSPlugInKitProxy *pluginProxy in application.plugInKitPlugins) {
        
        NSString *pluginIdentifier = pluginProxy.pluginIdentifier;
        
        NSURL *pluginDataContainerURL     = nil;
        NSString *pluginDataContainerPath = nil;
        
        if (useMCM) {
            pluginDataContainerURL  = MCMGetContainerURL(MCMContainerTypePlugin, pluginIdentifier, error);
            if (!pluginDataContainerURL) {
                pluginDataContainerURL = MCMRecreateDefaultContainerStructure(MCMContainerTypePlugin, pluginIdentifier, error);
            }
            pluginDataContainerPath = [pluginDataContainerURL path];
        } else {
            pluginDataContainerURL  = pluginProxy.dataContainerURL;
            pluginDataContainerPath = [pluginDataContainerURL path];
        }
        
        if (!pluginDataContainerURL || !pluginDataContainerPath) {
            continue;
        }
        
        [pluginDataContainerURLs setObject:pluginDataContainerURL forKey:pluginIdentifier];
        [pluginDataContainerPaths setObject:pluginDataContainerPath forKey:pluginIdentifier];
        
        // we do not care other properties of a plugin
    }
    
    NSURL *bundleContainerURL = nil;
    NSString *bundleContainerPath = nil;
    if (useMCM) {
        bundleContainerURL  = MCMGetContainerURL(MCMContainerTypeBundle, application.applicationIdentifier, error);
        bundleContainerPath = [bundleContainerURL path];
    } else {
        bundleContainerURL  = application.bundleContainerURL;
        bundleContainerPath = [application.bundleContainerURL path];
    }
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray <NSString *> *bundleItems = [fileManager contentsOfDirectoryAtPath:bundleContainerPath error:error];
    NSString *bundleAppItem = nil;
    for (NSString *bundleItem in bundleItems) {
        if ([[bundleItem pathExtension] isEqualToString:@"app"]) {
            bundleAppItem = bundleItem;
            break;
        }
    }
    
    NSString *bundlePath = [bundleContainerPath stringByAppendingPathComponent:bundleAppItem];
    NSURL *bundleURL = [NSURL fileURLWithPath:bundlePath];
    
    NSURL *dataContainerURL     = nil;
    NSString *dataContainerPath = nil;
    if (useMCM) {
        dataContainerURL  = MCMGetContainerURL(MCMContainerTypeData, application.applicationIdentifier, error);
        if (!dataContainerURL) {
            dataContainerURL = MCMRecreateDefaultContainerStructure(MCMContainerTypeData, application.applicationIdentifier, error);
        }
        dataContainerPath = [dataContainerURL path];
    } else {
        dataContainerURL  = application.dataContainerURL;
        dataContainerPath = [application.dataContainerURL path];
    }
    
    TFAppItem *appItem                = [[TFAppItem alloc] init];
    appItem.identifier                = application.applicationIdentifier;
    appItem.name                      = application.localizedName;
    appItem.version                   = application.shortVersionString;
    appItem.type                      = application.applicationType;
    appItem.bundleContainer           = bundleContainerPath;
    appItem.bundlePath                = bundlePath;
    appItem.dataContainer             = dataContainerPath;
    appItem.groupContainers           = [groupContainerPaths copy];
    appItem.pluginDataContainers      = [pluginDataContainerPaths copy];
    appItem.bundleContainerURL        = bundleContainerURL;
    appItem.bundleURL                 = bundleURL;
    appItem.dataContainerURL          = dataContainerURL;
    appItem.groupContainerURLs        = [groupContainerURLs copy];
    appItem.pluginDataContainerURLs   = [pluginDataContainerURLs copy];
    
    if (options & TFContainerManagerFetchWithEntitlements) {
        appItem.entitlements              = application.entitlements;  // simply ignore entitlements from plugins
    }
    
    NSDictionary *metaDict = [NSDictionary dictionaryWithContentsOfFile:[bundleContainerPath stringByAppendingPathComponent:@"iTunesMetadata.plist"]];
    appItem.appleId = metaDict[@"com.apple.iTunesStore.downloadInfo"][@"accountInfo"][@"AppleID"];
    
    if (options & TFContainerManagerFetchWithIconData) {
        NSData *applicationIconImageData = nil;
        
        /// uses applist
        if (options & TFContainerManagerFetchUsesAppList) {
            if (!applicationIconImageData) {
                do {
                    if (!objc_getClass("ALApplicationList")) {
                        break;
                    }
                    ALApplicationList *applist = [ALApplicationList sharedApplicationList];
                    UIImage *applicationIconImage = [applist iconOfSize:ALApplicationIconSizeLarge forDisplayIdentifier:application.applicationIdentifier];
                    if (applicationIconImage) {
                        applicationIconImageData = UIImagePNGRepresentation(applicationIconImage);
                    }
                } while (0);
            }
        }
        
        /// uses springboard services
        {
            if (!applicationIconImageData) {
                if (TFGetSpringBoardServices()) {
                    if (TFCopyIconImagePNGDataForDisplayIdentifier) {
                        applicationIconImageData = CFBridgingRelease(TFCopyIconImagePNGDataForDisplayIdentifier((__bridge CFStringRef)(application.applicationIdentifier)));
                    }
                }
            }
        }
        
        static NSDictionary <NSString *, NSString *> *systemBundlePathMappings = nil;
        static dispatch_once_t onceToken2;
        dispatch_once(&onceToken2, ^{
            NSMutableDictionary <NSString *, NSString *> *mappings = [NSMutableDictionary dictionary];
            NSString *sysAppDir = @"/Applications";
            NSArray <NSString *> *sysAppBundleNames = [fileManager contentsOfDirectoryAtPath:sysAppDir error:nil];
            for (NSString *sysAppBundleName in sysAppBundleNames) {
                if (![sysAppBundleName hasSuffix:@".app"]) {
                    continue;
                }
                NSString *sysAppBundlePath = [sysAppDir stringByAppendingPathComponent:sysAppBundleName];
                NSString *infoPath         = [sysAppBundlePath stringByAppendingPathComponent:@"Info.plist"];
                NSDictionary *infoDict     = [NSDictionary dictionaryWithContentsOfFile:infoPath];
                NSString *sysAppBundleID   = infoDict[(__bridge NSString *)kCFBundleIdentifierKey];
                if (![sysAppBundleID isKindOfClass:[NSString class]]) {
                    continue;
                }
                mappings[sysAppBundleID] = sysAppBundlePath;
            }
            systemBundlePathMappings = mappings;
        });
        
        do {
            
            if (!applicationIconImageData && bundlePath.length) {
                NSString *infoPlist = [bundlePath stringByAppendingPathComponent:@"Info.plist"];
                NSDictionary *infoDict = [NSDictionary dictionaryWithContentsOfFile:infoPlist];
                NSArray *iconFiles = nil;
                if (infoDict[@"CFBundleIcons"] && infoDict[@"CFBundleIcons"][@"CFBundlePrimaryIcon"] && infoDict[@"CFBundleIcons"][@"CFBundlePrimaryIcon"][@"CFBundleIconFiles"]) {
                    iconFiles = infoDict[@"CFBundleIcons"][@"CFBundlePrimaryIcon"][@"CFBundleIconFiles"];
                } else {
                    iconFiles = infoDict[@"CFBundleIconFiles"];
                }
                if (!iconFiles || iconFiles.count == 0) {
                    break;
                }
                
                NSString *iconPath = nil;
                {
                    NSMutableArray <NSString *> *possibleIconFiles = [iconFiles mutableCopy];
                    while ([possibleIconFiles count] > 0) {
                        NSString *iconFileName = [possibleIconFiles lastObject];
                        iconPath = [NSString stringWithFormat:@"%@/%@@2x.png", bundlePath, iconFileName];
                        if (![fileManager fileExistsAtPath:iconPath]) {
                            iconPath = [NSString stringWithFormat:@"%@/%@@3x.png", bundlePath, iconFileName];
                        }
                        if (![fileManager fileExistsAtPath:iconPath]) {
                            iconPath = [NSString stringWithFormat:@"%@/%@.png", bundlePath, iconFileName];
                        }
                        if (![fileManager fileExistsAtPath:iconPath]) {
                            iconPath = nil;
                        }
                        if (iconPath != nil) {
                            break;
                        }
                        [possibleIconFiles removeLastObject];
                    }
                }
                if (!iconPath) {
                    break;
                }
                
                UIImage *icon = [UIImage imageWithData:[NSData dataWithContentsOfFile:iconPath]];
                if (!icon) {
                    break;
                }
                
                NSData *img = UIImagePNGRepresentation(icon);
                if (!img) {
                    break;
                }
                
                applicationIconImageData = img;
            }
            
        } while (0);
        
        appItem.iconData = applicationIconImageData;
    }
    
    pthread_mutex_lock(&_kSharedTFAppItemCachesLock);
    _kSharedTFAppItemCaches[application.applicationIdentifier] = appItem;
    pthread_mutex_unlock(&_kSharedTFAppItemCachesLock);
    
    return appItem;
}

LSApplicationProxy *TFUserAppProxyForIdentifier(NSString *identifier)
{
    NSArray <NSString *> *whitelist = TFGetAppleAppIdentifierWhitelist();
    
    if ([identifier hasPrefix:@"com.apple."] &&
        ![whitelist containsObject:identifier])
    {
        return nil;
    }
    
    LSApplicationProxy *proxy = [LSApplicationProxy applicationProxyForIdentifier:identifier];
    if (!proxy.applicationIdentifier) {
        return nil;
    }
    
    if (![proxy.applicationType isEqualToString:kLSApplicationTypeUser] &&
        ![whitelist containsObject:identifier])
    {
        return nil;
    }
    
    return proxy;
}

LSApplicationProxy *TFAppProxyForIdentifier(NSString *identifier)
{
    LSApplicationProxy *proxy = [LSApplicationProxy applicationProxyForIdentifier:identifier];
    if (!proxy.applicationIdentifier || !proxy.applicationType) {
        return nil;
    }
    return proxy;
}

LSPlugInKitProxy *TFPlugInKitProxyForIdentifier(NSString *identifier)
{
    LSPlugInKitProxy *proxy = [LSPlugInKitProxy pluginKitProxyForIdentifier:identifier];
    if (!proxy.pluginIdentifier) {
        return nil;
    }
    return proxy;
}


#pragma mark - Public APIs

NSArray <TFAppItem *> *TFCopyAppItems(BOOL userOnly, TFContainerManagerFetchOptions options, NSError *__autoreleasing  _Nullable * _Nullable error) {
    NSArray <NSString *> *whitelist = TFGetAppleAppIdentifierWhitelist();
    LSApplicationWorkspace *workspace = [LSApplicationWorkspace defaultWorkspace];
    NSArray <LSApplicationProxy *> *allApps = workspace.allApplications;
    NSMutableArray <TFAppItem *> *outputs = [NSMutableArray arrayWithCapacity:allApps.count];
    for (LSApplicationProxy *proxy in allApps) {
        
        if (userOnly && ![proxy.applicationType isEqualToString:kLSApplicationTypeUser])
            continue;
        
        if ([proxy.applicationIdentifier hasPrefix:@"com.apple."] &&
            ![whitelist containsObject:proxy.applicationIdentifier])
            continue;
        
        [outputs addObject:TFAppItemForProxy(proxy, options, error)];
    }
    return outputs;
}

TFAppItem *TFCopyUserAppItemForIdentifier(NSString *identifier, TFContainerManagerFetchOptions options, NSError *__autoreleasing  _Nullable * _Nullable error)
{
    return TFAppItemForProxy(TFUserAppProxyForIdentifier(identifier), options, error);
}

TFAppItem *TFCopyAppItemForIdentifier(NSString *identifier, TFContainerManagerFetchOptions options, NSError *__autoreleasing  _Nullable * _Nullable error)
{
    return TFAppItemForProxy(TFAppProxyForIdentifier(identifier), options, error);
}

BOOL TFLaunchAppWithIdentifier(NSString *identifier, BOOL inBackground, NSError *__autoreleasing  _Nullable * _Nullable error)
{
    if (!TFGetSpringBoardServices()) {
        if (error) {
            *error = [NSError errorWithDomain:@TFContainerErrorDomain code:500 userInfo:@{ NSLocalizedDescriptionKey: @"fail to load SpringBoardServices" }];
        }
        return NO;
    }
    CFStringRef cfIdentifier = CFStringCreateWithCString(kCFAllocatorDefault, identifier.UTF8String, kCFStringEncodingUTF8);
    assert(cfIdentifier);
    int result = TFLaunchApplicationWithIdentifier(cfIdentifier, inBackground);
    CFRelease(cfIdentifier);
    if (result != 0) {
        CFStringRef errStr = TFApplicationLaunchingErrorString(result);
        if (error) {
            *error = [NSError errorWithDomain:@TFContainerErrorDomain code:500 userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"%@", (__bridge NSString *)errStr] }];
        }
        // Not copied, do not over-release it.
    }
    return result == 0;
}

NSString *TFFrontmostAppIdentifier(NSError *__autoreleasing  _Nullable * _Nullable error)
{
    if (!TFGetSpringBoardServices()) {
        if (error) {
            *error = [NSError errorWithDomain:@TFContainerErrorDomain code:500 userInfo:@{ NSLocalizedDescriptionKey: @"fail to load SpringBoardServices" }];
        }
        return nil;
    }
    char *buf = (char *)malloc(BUFSIZ);
    memset(buf, 0x1, BUFSIZ);
    TFFrontmostApplicationDisplayIdentifier(TFSpringBoardServerPort(), buf);
    NSString *identifier = [NSString stringWithUTF8String:buf];
    if (identifier.length == 0 || buf[0] == 0x1) {
        free(buf);
        return nil;
    }
    free(buf);
    return identifier;
}

BOOL TFInstallIPAArchiveAtPath(NSString *path, BOOL removeAfterInstallation, NSError *__autoreleasing  _Nullable * _Nullable error)
{
    Class LSApplicationWorkspace_class = objc_getClass("LSApplicationWorkspace");
    LSApplicationWorkspace *workspace = [LSApplicationWorkspace_class performSelector:@selector(defaultWorkspace)];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *lnkPath = [path stringByAppendingPathExtension:@"lnk"];
    BOOL linkSucceed = [fileManager linkItemAtPath:path toPath:lnkPath error:error];
    if (!linkSucceed) {
        return NO;
    }
    
    NSURL *url = [NSURL fileURLWithPath:path isDirectory:NO];
    BOOL succeed = [workspace installApplication:url withOptions:nil error:error];
    
    NSError *moveError = nil;
    BOOL moveSucceed = [fileManager moveItemAtPath:lnkPath toPath:path error:&moveError];
    if (!moveSucceed) {
        // nothing to do
    }
    if (!succeed) {
        return NO;
    }
    
    if (!moveSucceed) {
        NSError *removeError = nil;
        BOOL removeSucceed = [fileManager removeItemAtPath:lnkPath error:&removeError];
        if (!removeSucceed) {
            // nothing to do
        }
    }
    
    [workspace invalidateIconCache:nil];
    notify_post(NP_APP_INSTALLED);
    
    if (removeAfterInstallation) {
        BOOL removeSucceed = [fileManager removeItemAtPath:path error:error];
        if (!removeSucceed) {
            return NO;
        }
    }
    
    return YES;
}

BOOL TFUninstallAppWithIdentifier(NSString *identifier, NSError *__autoreleasing  _Nullable * _Nullable error)
{
    Class LSApplicationWorkspace_class = objc_getClass("LSApplicationWorkspace");
    LSApplicationWorkspace *workspace = [LSApplicationWorkspace_class performSelector:@selector(defaultWorkspace)];
    
    BOOL succeed = [workspace uninstallApplication:identifier withOptions:nil];
    if (!succeed) {
        return NO;
    }
    
    [workspace invalidateIconCache:nil];
    notify_post(NP_APP_UNINSTALLED);
    
    return YES;
}

BOOL TFPackBundleContainerAtPath(NSString *path, NSString *toIPAPath, NSError *__autoreleasing  _Nullable * _Nullable error)
{
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    NSURL *tmpURL = [fileMgr URLForDirectory:NSItemReplacementDirectory inDomain:NSUserDomainMask appropriateForURL:[NSURL fileURLWithPath:path] create:YES error:error];
    if (!tmpURL) {
        return NO;
    }
    
    NSString *tmpPath = [tmpURL path];
    NSString *payloadPath = [tmpPath stringByAppendingPathComponent:@"Payload"];
    BOOL created = [fileMgr createSymbolicLinkAtPath:payloadPath withDestinationPath:path error:error];
    if (!created) {
        return NO;
    }
    
    NSString *extCommand = [NSString stringWithFormat:@"set -e; shopt -s dotglob; cd '%@'; /usr/bin/zip -qr '%@' Payload/; cd '%@'; shopt -u dotglob;", TFEscapeShellArg(tmpPath), TFEscapeShellArg(toIPAPath), TFEscapeShellArg([[NSFileManager defaultManager] currentDirectoryPath])];
    
    int status;
    NSArray <NSString *> *outputs = TFSystemWithOutputs(extCommand.UTF8String, &status);
    
    if (status != 0) {
        if (error) {
            *error = [NSError errorWithDomain:@TFContainerErrorDomain code:500 userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithFormat:@"%@", outputs[1]] }];
        }
    }
    
    return status == 0;
}

BOOL TFOpenSensitiveURL(NSURL *url, NSError *__autoreleasing  _Nullable * _Nullable error)
{
    Class LSApplicationWorkspace_class = objc_getClass("LSApplicationWorkspace");
    LSApplicationWorkspace *workspace = [LSApplicationWorkspace_class performSelector:@selector(defaultWorkspace)];
    return [workspace openSensitiveURL:url withOptions:nil error:error];
}

CHConstructor {
    @autoreleasepool {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            pthread_mutex_init(&_kSharedTFAppItemCachesLock, NULL);
            _kSharedTFAppItemCaches = [[NSMutableDictionary alloc] init];
        });
        
        int installToken;
        notify_register_dispatch(NP_APP_INSTALLED, &installToken, dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^(int token) {
            CHDebugLogSource(@"Notification %@ received, clear app item caches", @NP_APP_INSTALLED);
            TFClearAppItemCaches();
        });
        
        int uninstallToken;
        notify_register_dispatch(NP_APP_UNINSTALLED, &uninstallToken, dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^(int token) {
            CHDebugLogSource(@"Notification %@ received, clear app item caches", @NP_APP_UNINSTALLED);
            TFClearAppItemCaches();
        });
    }
}
