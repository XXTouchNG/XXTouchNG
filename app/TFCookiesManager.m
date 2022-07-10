#import "TFCookiesManager.h"
#import "TFContainerManager.h"
#import "libtfcontainermanager-Swift.h"


@implementation TFCookiesManager {
    NSURL *_binaryCookiesURL;
}

+ (instancetype)sharedSafariManager {
    static TFCookiesManager *_sharedSafariManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedSafariManager = [TFCookiesManager managerWithBundleIdentifier:@"com.apple.mobilesafari"];
    });
    return _sharedSafariManager;
}

+ (nullable instancetype)managerWithBundleIdentifier:(NSString *)bundleIdentifier
{
    NSError *err = nil;
    TFAppItem *appItem = [[TFContainerManager sharedManager] appItemForIdentifier:bundleIdentifier
                                                                          options:TFContainerManagerFetchWithSystemApplications
                                                                            error:&err];
    if (!appItem)
    {
        return nil;
    }
    
    NSString *appItemPath = [appItem.dataContainer stringByAppendingPathComponent:@"Library/Cookies/Cookies.binarycookies"];
    if (!appItemPath)
    {
        return nil;
    }
    
    return [[self alloc] initWithBinaryCookiesPath:appItemPath];
}

+ (nullable instancetype)managerWithBundleIdentifier:(NSString *)bundleIdentifier groupIdentifier:(NSString *)groupIdentifier
{
    NSError *err = nil;
    TFAppItem *appItem = [[TFContainerManager sharedManager] appItemForIdentifier:bundleIdentifier
                                                                          options:TFContainerManagerFetchWithSystemApplications
                                                                            error:&err];
    if (!appItem)
    {
        return nil;
    }
    
    NSString *appItemPath = [appItem.groupContainers[groupIdentifier] stringByAppendingPathComponent:@"Library/Cookies/Cookies.binarycookies"];
    if (!appItemPath)
    {
        return nil;
    }
    
    return [[self alloc] initWithBinaryCookiesPath:appItemPath];
}

+ (nullable instancetype)managerWithBundleIdentifier:(NSString *)bundleIdentifier pluginIdentifier:(NSString *)pluginIdentifier
{
    NSError *err = nil;
    TFAppItem *appItem = [[TFContainerManager sharedManager] appItemForIdentifier:bundleIdentifier
                                                                          options:TFContainerManagerFetchWithSystemApplications
                                                                            error:&err];
    if (!appItem)
    {
        return nil;
    }
    
    NSString *appItemPath = [appItem.pluginDataContainers[pluginIdentifier] stringByAppendingPathComponent:@"Library/Cookies/Cookies.binarycookies"];
    if (!appItemPath)
    {
        return nil;
    }
    
    return [[self alloc] initWithBinaryCookiesPath:appItemPath];
}

- (nonnull instancetype)initWithBinaryCookiesPath:(NSString *)binaryCookiesPath
{
    self = [super init];
    if (self)
    {
        _binaryCookiesPath = binaryCookiesPath;
        _binaryCookiesURL = [NSURL fileURLWithPath:binaryCookiesPath];
    }
    return self;
}

+ (NSDateFormatter *)sharedCookiesDateFormatter {
    static NSDateFormatter *_sharedCookiesDateFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedCookiesDateFormatter = [[NSDateFormatter alloc] init];
        _sharedCookiesDateFormatter.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
        _sharedCookiesDateFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        _sharedCookiesDateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss'Z'";
    });
    return _sharedCookiesDateFormatter;
}

- (nullable NSArray <NSDictionary <NSHTTPCookiePropertyKey, id> *> *)readCookiesWithError:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    NSArray <NSDictionary <NSHTTPCookiePropertyKey, id> *> *allCookies = [CookiesToolObjectiveCBridge readBinaryCookiesAtURL:_binaryCookiesURL error:error];
    if (!allCookies)
    {
        return nil;
    }
    
    NSMutableArray <NSDictionary <NSHTTPCookiePropertyKey, id> *> *cookies = [NSMutableArray arrayWithCapacity:allCookies.count];
    for (NSDictionary <NSHTTPCookiePropertyKey, id> *cookie in allCookies)
    {
        NSMutableDictionary <NSHTTPCookiePropertyKey, id> *mCookie = [cookie mutableCopy];
        if ([cookie[NSHTTPCookieExpires] isKindOfClass:[NSDate class]])
        {
            mCookie[NSHTTPCookieExpires] = [[TFCookiesManager sharedCookiesDateFormatter] stringFromDate:cookie[NSHTTPCookieExpires]];
        }
        
        [cookies addObject:mCookie];
    }
    
    return cookies;
}

- (nullable NSArray <NSDictionary <NSHTTPCookiePropertyKey, id> *> *)filterCookiesWithDomainSuffix:(nonnull NSString *)domainSuffix pathPrefix:(nullable NSString *)pathPrefix error:(NSError *__autoreleasing _Nullable *)error
{
    NSArray <NSDictionary <NSHTTPCookiePropertyKey, id> *> *allCookies = [self readCookiesWithError:error];
    if (!allCookies)
    {
        return nil;
    }
    
    NSMutableArray <NSDictionary <NSHTTPCookiePropertyKey, id> *> *cookies = [NSMutableArray arrayWithCapacity:allCookies.count];
    for (NSDictionary <NSHTTPCookiePropertyKey, id> *cookie in allCookies)
    {
        if (![cookie[NSHTTPCookieDomain] hasSuffix:domainSuffix])
        {
            continue;
        }
        
        if (pathPrefix)
        {
            if (![cookie[NSHTTPCookiePath] hasPrefix:pathPrefix])
            {
                continue;
            }
        }
        
        [cookies addObject:cookie];
    }
    
    return cookies;
}

- (nullable NSDictionary <NSHTTPCookiePropertyKey, id> *)getCookiesWithDomainSuffix:(nonnull NSString *)domainSuffix pathPrefix:(nullable NSString *)pathPrefix name:(nonnull NSString *)name error:(NSError *__autoreleasing _Nullable *)error
{
    NSArray <NSDictionary <NSHTTPCookiePropertyKey, id> *> *allCookies = [self filterCookiesWithDomainSuffix:domainSuffix pathPrefix:pathPrefix error:error];
    if (!allCookies)
    {
        return nil;
    }
    
    NSDictionary <NSHTTPCookiePropertyKey, id> *targetCookie = nil;
    for (NSDictionary <NSHTTPCookiePropertyKey, id> *cookie in allCookies)
    {
        if ([cookie[NSHTTPCookieName] isEqualToString:name])
        {
            targetCookie = cookie;
            break;
        }
    }
    
    return targetCookie;
}

- (BOOL)setCookies:(NSArray <NSDictionary <NSHTTPCookiePropertyKey, id> *> *)cookies error:(NSError *__autoreleasing  _Nullable *)error
{
    NSMutableArray <NSDictionary <NSHTTPCookiePropertyKey, id> *> *mCookies = [[self readCookiesWithError:error] mutableCopy];
    if (!mCookies)
    {
        mCookies = [NSMutableArray array];
    }
    
    NSMutableArray <NSDictionary <NSHTTPCookiePropertyKey, id> *> *mCookiesToDelete = [NSMutableArray arrayWithCapacity:mCookies.count];
    for (NSDictionary <NSHTTPCookiePropertyKey, id> *mCookie in mCookies)
    {
        for (NSDictionary <NSHTTPCookiePropertyKey, id> *cookie in cookies)
        {
            if (
                cookie[NSHTTPCookieDomain] &&
                mCookie[NSHTTPCookieDomain] &&
                [cookie[NSHTTPCookieDomain] isEqualToString:mCookie[NSHTTPCookieDomain]] &&
                cookie[NSHTTPCookieName] &&
                mCookie[NSHTTPCookieName] &&
                [cookie[NSHTTPCookieName] isEqualToString:mCookie[NSHTTPCookieName]] &&
                cookie[NSHTTPCookiePath] &&
                mCookie[NSHTTPCookiePath] &&
                [cookie[NSHTTPCookiePath] isEqualToString:mCookie[NSHTTPCookiePath]]
                )
            {
                [mCookiesToDelete addObject:mCookie];
                break;
            }
        }
    }
    
    [mCookies removeObjectsInArray:mCookiesToDelete];
    [mCookies addObjectsFromArray:cookies];
    
    return [self writeCookies:mCookies error:error];
}

- (BOOL)writeCookies:(NSArray <NSDictionary <NSHTTPCookiePropertyKey, id> *> *)cookies error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    NSMutableArray <NSDictionary <NSHTTPCookiePropertyKey, id> *> *mCookies = [NSMutableArray arrayWithCapacity:cookies.count];
    for (NSDictionary <NSHTTPCookiePropertyKey, id> *cookie in cookies) {
        NSMutableDictionary <NSHTTPCookiePropertyKey, id> *mCookie = [cookie mutableCopy];
        if (![mCookie[NSHTTPCookieExpires] isKindOfClass:[NSDate class]])
        {
            if ([mCookie[NSHTTPCookieExpires] isKindOfClass:[NSString class]])
            {
                NSDate *parsedDate = [[TFCookiesManager sharedCookiesDateFormatter] dateFromString:mCookie[NSHTTPCookieExpires]];
                if (!parsedDate)
                {
                    NSTimeInterval expireStamp = [mCookie[NSHTTPCookieExpires] doubleValue];
                    if (expireStamp > 0)
                    {
                        parsedDate = [NSDate dateWithTimeIntervalSince1970:expireStamp];
                    }
                    else
                    {
                        parsedDate = [NSDate distantFuture];
                    }
                }
                mCookie[NSHTTPCookieExpires] = parsedDate;
            }
            else if ([mCookie[NSHTTPCookieExpires] isKindOfClass:[NSNumber class]])
            {
                mCookie[NSHTTPCookieExpires] = [NSDate dateWithTimeIntervalSince1970:[mCookie[NSHTTPCookieExpires] doubleValue]];
            }
            else
            {
                mCookie[NSHTTPCookieExpires] = [NSDate distantFuture];
            }
        }
        [mCookies addObject:mCookie];
    }
    
    BOOL created = [[NSFileManager defaultManager] createDirectoryAtPath:[_binaryCookiesPath stringByDeletingLastPathComponent]
                                             withIntermediateDirectories:YES
                                                              attributes:@{ NSFileOwnerAccountID: @(501), NSFileGroupOwnerAccountID: @(501) }
                                                                   error:error];
    if (!created)
    {
        return created;
    }
    
    BOOL wrote = [CookiesToolObjectiveCBridge writeBinaryCookies:mCookies toURL:_binaryCookiesURL error:error];
    if (!wrote)
    {
        return wrote;
    }
    
    BOOL succeed = [[NSFileManager defaultManager] setAttributes:@{ NSFileOwnerAccountID: @(501), NSFileGroupOwnerAccountID: @(501) }
                                                    ofItemAtPath:_binaryCookiesPath
                                                           error:error];
    return succeed;
}

- (BOOL)removeCookiesExpiredBeforeDate:(NSDate *)date error:(NSError *__autoreleasing  _Nullable *)error
{
    NSMutableArray <NSDictionary <NSHTTPCookiePropertyKey, id> *> *mCookies = [[self readCookiesWithError:error] mutableCopy];
    if (!mCookies)
    {
        mCookies = [NSMutableArray array];
    }
    
    NSMutableArray <NSDictionary <NSHTTPCookiePropertyKey, id> *> *mCookiesToDelete = [NSMutableArray arrayWithCapacity:mCookies.count];
    for (NSDictionary <NSHTTPCookiePropertyKey, id> *mCookie in mCookies)
    {
        NSDate *mCookieExpires = nil;
        if ([mCookie[NSHTTPCookieExpires] isKindOfClass:[NSDate class]])
        {
            mCookieExpires = mCookie[NSHTTPCookieExpires];
        }
        else if ([mCookie[NSHTTPCookieExpires] isKindOfClass:[NSString class]])
        {
            mCookieExpires = [[TFCookiesManager sharedCookiesDateFormatter] dateFromString:mCookie[NSHTTPCookieExpires]];
        }
        else
        {
            mCookieExpires = [NSDate distantFuture];
        }
        
        if ([date compare:mCookieExpires] == NSOrderedDescending)
        {
            [mCookiesToDelete addObject:mCookie];
        }
    }
    
    [mCookies removeObjectsInArray:mCookiesToDelete];
    
    return [self writeCookies:mCookies error:error];
}

- (BOOL)clearCookiesWithError:(NSError * _Nullable __autoreleasing * _Nullable)error
{
    return [self writeCookies:@[] error:error];
}

@end
