#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import "lua.hpp"

#import <Foundation/Foundation.h>
#import "KxSMBProvider.h"
#import "luae.h"


#pragma mark -

XXTouchF_CAPI int luaopen_samba(lua_State *);
static dispatch_queue_t _eventQueue = NULL;

#define SMBERR_EXPECT_SAMBA_CONFIG \
    "samba_config expected"


#pragma mark -

#define L_TYPE_SAMBA_CONFIG "samba_config"

typedef struct SambaConfig {
    NSUInteger timeout;
    NSUInteger debugLevel;
    BOOL debugToStderr;
    BOOL fullTimeNames;
    KxSMBConfigShareMode shareMode;
    KxSMBConfigEncryptLevel encryptionLevel;
    BOOL caseSensitive;
    NSUInteger browseMaxLmbCount;
    BOOL urlEncodeReaddirEntries;
    BOOL oneSharePerServer;
    BOOL useKerberos;
    BOOL fallbackAfterKerberos;
    BOOL noAutoAnonymousLogin;
    BOOL useCCache;
    BOOL useNTHash;
    
    char netbiosName[16];
    char workgroup[16];
    char username[256];
    char password[128];
} SambaConfig;

NS_INLINE SambaConfig *toSambaConfig(lua_State *L, int index)
{
    SambaConfig *bar = (SambaConfig *)lua_touserdata(L, index);
    if (bar == NULL)
        luaL_argerror(L, index, SMBERR_EXPECT_SAMBA_CONFIG);
    return bar;
}

NS_INLINE BOOL isSambaConfig(lua_State *L, int index)
{
    if (lua_type(L, index) != LUA_TUSERDATA)
        return NO;
    return NULL != luaL_testudata(L, index, L_TYPE_SAMBA_CONFIG);
}

NS_INLINE SambaConfig *checkSambaConfig(lua_State *L, int index)
{
    SambaConfig *bar;
    luaL_checktype(L, index, LUA_TUSERDATA);
    bar = (SambaConfig *)luaL_checkudata(L, index, L_TYPE_SAMBA_CONFIG);
    if (bar == NULL)
        luaL_argerror(L, index, SMBERR_EXPECT_SAMBA_CONFIG);
    return bar;
}

NS_INLINE SambaConfig *pushSambaConfig(lua_State *L)
{
    SambaConfig *bar = (SambaConfig *)lua_newuserdata(L, sizeof(SambaConfig));
    luaL_getmetatable(L, L_TYPE_SAMBA_CONFIG);
    lua_setmetatable(L, -2);
    return bar;
}

NS_INLINE KxSMBAuth *copyAuthFromSambaConfig(SambaConfig *smbConfig)
{
    return [KxSMBAuth smbAuthWorkgroup:[NSString stringWithUTF8String:smbConfig->workgroup]
                              username:[NSString stringWithUTF8String:smbConfig->username]
                              password:[NSString stringWithUTF8String:smbConfig->password]];
}

NS_INLINE KxSMBConfig *copyConfigFromSambaConfig(SambaConfig *smbConfig)
{
    KxSMBConfig *config = [KxSMBConfig new];
    config.timeout = smbConfig->timeout;
    config.debugLevel = smbConfig->debugLevel;
    config.debugToStderr = smbConfig->debugToStderr;
    config.fullTimeNames = smbConfig->fullTimeNames;
    config.shareMode = smbConfig->shareMode;
    config.encryptionLevel = smbConfig->encryptionLevel;
    config.caseSensitive = smbConfig->caseSensitive;
    config.browseMaxLmbCount = smbConfig->browseMaxLmbCount;
    config.urlEncodeReaddirEntries = smbConfig->urlEncodeReaddirEntries;
    config.oneSharePerServer = smbConfig->oneSharePerServer;
    config.useKerberos = smbConfig->useKerberos;
    config.fallbackAfterKerberos = smbConfig->fallbackAfterKerberos;
    config.noAutoAnonymousLogin = smbConfig->noAutoAnonymousLogin;
    config.useCCache = smbConfig->useCCache;
    config.useNTHash = smbConfig->useNTHash;
    config.netbiosName = [NSString stringWithUTF8String:smbConfig->netbiosName];
    config.workgroup = [NSString stringWithUTF8String:smbConfig->workgroup];
    config.username = [NSString stringWithUTF8String:smbConfig->username];
    return config;
}

NS_INLINE NSString *stringFromItemType(KxSMBItemType type)
{
    switch (type) {
        case KxSMBItemTypeUnknown:
            return @"unknown";
        case KxSMBItemTypeWorkgroup:
            return @"workgroup";
        case KxSMBItemTypeServer:
            return @"server";
        case KxSMBItemTypeFileShare:
            return @"share";
        case KxSMBItemTypePrinter:
            return @"printer";
        case KxSMBItemTypeComms:
            return @"comms";
        case KxSMBItemTypeIPC:
            return @"ipc";
        case KxSMBItemTypeDir:
            return @"dir";
        case KxSMBItemTypeFile:
            return @"file";
        case KxSMBItemTypeLink:
            return @"link";
    }
}

NS_INLINE NSDictionary *dictionaryFromItem(KxSMBItem *item, BOOL withStat)
{
    if (!withStat) {
        return @{
            @"path": item.path,
            @"name": item.path.lastPathComponent ?: @"",
            @"type": stringFromItemType(item.type),
        };
    }
    return @{
        @"path": item.path,
        @"name": item.path.lastPathComponent ?: @"",
        @"type": stringFromItemType(item.type),
        @"creation": @([item.stat.creationTime timeIntervalSince1970]),
        @"modification": @([item.stat.lastModified timeIntervalSince1970]),
        @"access": @([item.stat.lastAccess timeIntervalSince1970]),
        @"size": @(item.stat.size),
        @"mode": @(item.stat.mode),
    };
}


#pragma mark -

static int SambaConfig_GC(lua_State *L)
{
    fprintf(stderr, "gc, " L_TYPE_SAMBA_CONFIG " = %p\n", toSambaConfig(L, 1));
    return 0;
}

static int SambaConfig_ToString(lua_State *L)
{
    char buff[BUFSIZ];
    SambaConfig *bar = toSambaConfig(L, 1);
    snprintf(buff, BUFSIZ, "%p <WORKGROUP = %s, USER = %s>", bar, bar->workgroup, bar->username);
    lua_pushfstring(L, L_TYPE_SAMBA_CONFIG ": %s", buff);
    return 1;
}

static int Samba_IsClient(lua_State *L)
{
    lua_pushboolean(L, isSambaConfig(L, 1));
    return 1;
}

static int Samba_NewClient(lua_State *L)
{
    @autoreleasepool {
        NSDictionary <NSString *, id> *args = lua_toNSDictionary(L, 1);
        SambaConfig *bar = pushSambaConfig(L);
        
        do {
            bzero(bar, sizeof(SambaConfig));
            KxSMBConfig *defaultConfig = [KxSMBConfig new];
            
            bar->timeout = defaultConfig.timeout;
            if ([args[@"timeout"] isKindOfClass:[NSNumber class]])
                bar->timeout = [args[@"timeout"] unsignedIntegerValue];
            else if (args[@"timeout"])
            {
                return luaL_argerror(L, 1, "bad parameter: timeout");
            }
            
            bar->debugLevel = defaultConfig.debugLevel;
            if ([args[@"debugLevel"] isKindOfClass:[NSNumber class]])
                bar->debugLevel = [args[@"debugLevel"] unsignedIntegerValue];
            else if (args[@"debugLevel"])
            {
                return luaL_argerror(L, 1, "bad parameter: debugLevel");
            }
            
            bar->debugToStderr = defaultConfig.debugToStderr;
            if ([args[@"debugToStderr"] isKindOfClass:[NSNumber class]])
                bar->debugToStderr = [args[@"debugToStderr"] boolValue];
            else if (args[@"debugToStderr"])
            {
                return luaL_argerror(L, 1, "bad parameter: debugToStderr");
            }
            
            bar->fullTimeNames = defaultConfig.fullTimeNames;
            if ([args[@"fullTimeNames"] isKindOfClass:[NSNumber class]])
                bar->fullTimeNames = [args[@"fullTimeNames"] boolValue];
            else if (args[@"fullTimeNames"])
            {
                return luaL_argerror(L, 1, "bad parameter: fullTimeNames");
            }
            
            bar->shareMode = defaultConfig.shareMode;
            if ([args[@"shareMode"] isKindOfClass:[NSNumber class]])
                bar->shareMode = (KxSMBConfigShareMode)[args[@"shareMode"] unsignedIntegerValue];
            else if (args[@"shareMode"])
            {
                return luaL_argerror(L, 1, "bad parameter: shareMode");
            }
            
            bar->encryptionLevel = defaultConfig.encryptionLevel;
            if ([args[@"encryptionLevel"] isKindOfClass:[NSNumber class]])
                bar->encryptionLevel = (KxSMBConfigEncryptLevel)[args[@"encryptionLevel"] unsignedIntegerValue];
            else if (args[@"encryptionLevel"])
            {
                return luaL_argerror(L, 1, "bad parameter: encryptionLevel");
            }
            
            bar->caseSensitive = defaultConfig.caseSensitive;
            if ([args[@"caseSensitive"] isKindOfClass:[NSNumber class]])
                bar->caseSensitive = [args[@"caseSensitive"] boolValue];
            else if (args[@"caseSensitive"])
            {
                return luaL_argerror(L, 1, "bad parameter: caseSensitive");
            }
            
            bar->browseMaxLmbCount = defaultConfig.browseMaxLmbCount;
            if ([args[@"browseMaxLmbCount"] isKindOfClass:[NSNumber class]])
                bar->browseMaxLmbCount = [args[@"browseMaxLmbCount"] unsignedIntegerValue];
            else if (args[@"browseMaxLmbCount"])
            {
                return luaL_argerror(L, 1, "bad parameter: browseMaxLmbCount");
            }
            
            bar->urlEncodeReaddirEntries = defaultConfig.urlEncodeReaddirEntries;
            if ([args[@"urlEncodeReaddirEntries"] isKindOfClass:[NSNumber class]])
                bar->urlEncodeReaddirEntries = [args[@"urlEncodeReaddirEntries"] boolValue];
            else if (args[@"urlEncodeReaddirEntries"])
            {
                return luaL_argerror(L, 1, "bad parameter: urlEncodeReaddirEntries");
            }
            
            bar->oneSharePerServer = defaultConfig.oneSharePerServer;
            if ([args[@"oneSharePerServer"] isKindOfClass:[NSNumber class]])
                bar->oneSharePerServer = [args[@"oneSharePerServer"] boolValue];
            else if (args[@"oneSharePerServer"])
            {
                return luaL_argerror(L, 1, "bad parameter: oneSharePerServer");
            }
            
            bar->useKerberos = defaultConfig.useKerberos;
            if ([args[@"useKerberos"] isKindOfClass:[NSNumber class]])
                bar->useKerberos = [args[@"useKerberos"] boolValue];
            else if (args[@"useKerberos"])
            {
                return luaL_argerror(L, 1, "bad parameter: useKerberos");
            }
            
            bar->fallbackAfterKerberos = defaultConfig.fallbackAfterKerberos;
            if ([args[@"fallbackAfterKerberos"] isKindOfClass:[NSNumber class]])
                bar->fallbackAfterKerberos = [args[@"fallbackAfterKerberos"] boolValue];
            else if (args[@"fallbackAfterKerberos"])
            {
                return luaL_argerror(L, 1, "bad parameter: fallbackAfterKerberos");
            }
            
            bar->noAutoAnonymousLogin = defaultConfig.noAutoAnonymousLogin;
            if ([args[@"noAutoAnonymousLogin"] isKindOfClass:[NSNumber class]])
                bar->noAutoAnonymousLogin = [args[@"noAutoAnonymousLogin"] boolValue];
            else if (args[@"noAutoAnonymousLogin"])
            {
                return luaL_argerror(L, 1, "bad parameter: noAutoAnonymousLogin");
            }
            
            bar->useCCache = defaultConfig.useCCache;
            if ([args[@"useCCache"] isKindOfClass:[NSNumber class]])
                bar->useCCache = [args[@"useCCache"] boolValue];
            else if (args[@"useCCache"])
            {
                return luaL_argerror(L, 1, "bad parameter: useCCache");
            }
            
            bar->useNTHash = defaultConfig.useNTHash;
            if ([args[@"useNTHash"] isKindOfClass:[NSNumber class]])
                bar->useNTHash = [args[@"useNTHash"] boolValue];
            else if (args[@"useNTHash"])
            {
                return luaL_argerror(L, 1, "bad parameter: useNTHash");
            }
            
            if (defaultConfig.netbiosName)
                strncpy(bar->netbiosName, [defaultConfig.netbiosName UTF8String], 16);
            
            if ([args[@"netbiosName"] isKindOfClass:[NSString class]])
                strncpy(bar->netbiosName, [args[@"netbiosName"] UTF8String], 16);
            else if (args[@"netbiosName"])
            {
                return luaL_argerror(L, 1, "bad parameter: netbiosName");
            }
            
            if (defaultConfig.workgroup)
                strncpy(bar->workgroup, [defaultConfig.workgroup UTF8String], 16);
            
            if ([args[@"workgroup"] isKindOfClass:[NSString class]])
                strncpy(bar->workgroup, [args[@"workgroup"] UTF8String], 16);
            else if (args[@"workgroup"])
            {
                return luaL_argerror(L, 1, "bad parameter: workgroup");
            }
            
            if (defaultConfig.username)
                strncpy(bar->username, [defaultConfig.username UTF8String], 256);
            
            if ([args[@"username"] isKindOfClass:[NSString class]])
                strncpy(bar->username, [args[@"username"] UTF8String], 256);
            else if (args[@"username"])
            {
                return luaL_argerror(L, 1, "bad parameter: username");
            }
            
            if ([args[@"password"] isKindOfClass:[NSString class]])
                strncpy(bar->password, [args[@"password"] UTF8String], 128);
            else if (args[@"password"])
            {
                return luaL_argerror(L, 1, "bad parameter: password");
            }
            else
            {
                return luaL_argerror(L, 1, "missing parameter: password");
            }
        } while (NO);
        
        return 1;
    }
}

static int SambaConfig_ListDirectory(lua_State *L)
{
    @autoreleasepool {
        SambaConfig *smbConfig = checkSambaConfig(L, 1);
        const char *smbPath = luaL_checkstring(L, 2);
        
        if (strncmp(smbPath, "smb://", sizeof("smb://") - 1) != 0)
        {
            return luaL_argerror(L, 2, "bad parameter: path must have prefix smb://");
        }
        
        [[KxSMBProvider sharedSmbProvider] setConfig:copyConfigFromSambaConfig(smbConfig)];
        [[KxSMBProvider sharedSmbProvider] setCompletionQueue:_eventQueue];
        
        id items = [[KxSMBProvider sharedSmbProvider] fetchAtPath:[NSString stringWithUTF8String:smbPath]
                                                                            expandDir:YES
                                                                                 auth:copyAuthFromSambaConfig(smbConfig)];
        
        if ([items isKindOfClass:[NSError class]])
        {
            lua_pushnil(L);
            lua_pushstring(L, [[(NSError *)items localizedDescription] UTF8String]);
            return 2;
        }
        else if (![items isKindOfClass:[NSArray class]])
        {
            lua_pushnil(L);
            lua_pushfstring(L, "not a directory: %s", smbPath);
            return 2;
        }
        
        NSMutableArray <NSDictionary *> *itemList = [NSMutableArray arrayWithCapacity:((NSArray <KxSMBItem *> *)items).count];
        for (KxSMBItem *item in (NSArray <KxSMBItem *> *)items) {
            [itemList addObject:dictionaryFromItem(item, YES)];
        }
        
        lua_pushNSArray(L, itemList);
        lua_pushnil(L);
        return 2;
    }
}

static int SambaConfig_CreateDirectory(lua_State *L)
{
    @autoreleasepool {
        SambaConfig *smbConfig = checkSambaConfig(L, 1);
        const char *smbPath = luaL_checkstring(L, 2);
        
        if (strncmp(smbPath, "smb://", sizeof("smb://") - 1) != 0)
        {
            return luaL_argerror(L, 2, "bad parameter: path must have prefix smb://");
        }
        
        [[KxSMBProvider sharedSmbProvider] setConfig:copyConfigFromSambaConfig(smbConfig)];
        [[KxSMBProvider sharedSmbProvider] setCompletionQueue:_eventQueue];
        
        id item = [[KxSMBProvider sharedSmbProvider] createFolderAtPath:[NSString stringWithUTF8String:smbPath]
                                                                   auth:copyAuthFromSambaConfig(smbConfig)];
        
        if ([item isKindOfClass:[NSError class]])
        {
            lua_pushnil(L);
            lua_pushstring(L, [[(NSError *)item localizedDescription] UTF8String]);
            return 2;
        }
        
        lua_pushNSDictionary(L, dictionaryFromItem((KxSMBItemTree *)item, YES));
        lua_pushnil(L);
        return 2;
    }
}

static int SambaConfig_RemoveItem(lua_State *L)
{
    @autoreleasepool {
        SambaConfig *smbConfig = checkSambaConfig(L, 1);
        const char *smbPath = luaL_checkstring(L, 2);
        
        if (strncmp(smbPath, "smb://", sizeof("smb://") - 1) != 0)
        {
            return luaL_argerror(L, 2, "bad parameter: path must have prefix smb://");
        }
        
        [[KxSMBProvider sharedSmbProvider] setConfig:copyConfigFromSambaConfig(smbConfig)];
        [[KxSMBProvider sharedSmbProvider] setCompletionQueue:_eventQueue];
        
        id item = [[KxSMBProvider sharedSmbProvider] removeAtPath:[NSString stringWithUTF8String:smbPath] auth:copyAuthFromSambaConfig(smbConfig)];
        
        if ([item isKindOfClass:[NSError class]])
        {
            lua_pushboolean(L, false);
            lua_pushstring(L, [[(NSError *)item localizedDescription] UTF8String]);
            return 2;
        }
        
        lua_pushboolean(L, true);
        lua_pushnil(L);
        return 2;
    }
}

static int SambaConfig_RemoveDirectory(lua_State *L)
{
    @autoreleasepool {
        SambaConfig *smbConfig = checkSambaConfig(L, 1);
        const char *smbPath = luaL_checkstring(L, 2);
        
        if (strncmp(smbPath, "smb://", sizeof("smb://") - 1) != 0)
        {
            return luaL_argerror(L, 2, "bad parameter: path must have prefix smb://");
        }
        
        [[KxSMBProvider sharedSmbProvider] setConfig:copyConfigFromSambaConfig(smbConfig)];
        [[KxSMBProvider sharedSmbProvider] setCompletionQueue:_eventQueue];
        
        __block id item = nil;
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        [[KxSMBProvider sharedSmbProvider] removeFolderAtPath:[NSString stringWithUTF8String:smbPath]
                                                         auth:copyAuthFromSambaConfig(smbConfig)
                                                        block:^(id  _Nullable result) {
            item = result;
            dispatch_semaphore_signal(sema);
        }];
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        
        if ([item isKindOfClass:[NSError class]])
        {
            lua_pushboolean(L, false);
            lua_pushstring(L, [[(NSError *)item localizedDescription] UTF8String]);
            return 2;
        }
        
        lua_pushboolean(L, true);
        lua_pushnil(L);
        return 2;
    }
}

static int SambaConfig_RenameItem(lua_State *L)
{
    @autoreleasepool {
        SambaConfig *smbConfig = checkSambaConfig(L, 1);
        const char *smbPathFrom = luaL_checkstring(L, 2);
        const char *smbPathTo = luaL_checkstring(L, 3);
        
        if (strncmp(smbPathFrom, "smb://", sizeof("smb://") - 1) != 0)
        {
            return luaL_argerror(L, 2, "bad parameter: from_path must have prefix smb://");
        }
        
        if (strncmp(smbPathTo, "smb://", sizeof("smb://") - 1) != 0)
        {
            return luaL_argerror(L, 3, "bad parameter: to_path must have prefix smb://");
        }
        
        [[KxSMBProvider sharedSmbProvider] setConfig:copyConfigFromSambaConfig(smbConfig)];
        [[KxSMBProvider sharedSmbProvider] setCompletionQueue:_eventQueue];
        
        __block id item = nil;
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        [[KxSMBProvider sharedSmbProvider] renameAtPath:[NSString stringWithUTF8String:smbPathFrom]
                                                newPath:[NSString stringWithUTF8String:smbPathTo]
                                                   auth:copyAuthFromSambaConfig(smbConfig)
                                                  block:^(id  _Nullable result) {
            item = result;
            dispatch_semaphore_signal(sema);
        }];
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        
        if ([item isKindOfClass:[NSError class]])
        {
            lua_pushboolean(L, false);
            lua_pushstring(L, [[(NSError *)item localizedDescription] UTF8String]);
            return 2;
        }
        
        lua_pushboolean(L, true);
        lua_pushnil(L);
        return 2;
    }
}

static int SambaConfig_TouchFile(lua_State *L)
{
    @autoreleasepool {
        SambaConfig *smbConfig = checkSambaConfig(L, 1);
        const char *smbPath = luaL_checkstring(L, 2);
        
        if (strncmp(smbPath, "smb://", sizeof("smb://") - 1) != 0)
        {
            return luaL_argerror(L, 2, "bad parameter: path must have prefix smb://");
        }
        
        [[KxSMBProvider sharedSmbProvider] setConfig:copyConfigFromSambaConfig(smbConfig)];
        [[KxSMBProvider sharedSmbProvider] setCompletionQueue:_eventQueue];
        
        id item = [[KxSMBProvider sharedSmbProvider] createFileAtPath:[NSString stringWithUTF8String:smbPath]
                                                            overwrite:YES
                                                                 auth:copyAuthFromSambaConfig(smbConfig)];
        
        if ([item isKindOfClass:[NSError class]])
        {
            lua_pushboolean(L, false);
            lua_pushstring(L, [[(NSError *)item localizedDescription] UTF8String]);
            return 2;
        }
        
        lua_pushboolean(L, true);
        lua_pushnil(L);
        return 2;
    }
}

static int SambaConfig_DownloadItem(lua_State *L)
{
    @autoreleasepool {
        
        int argc = lua_gettop(L);
        
        SambaConfig *smbConfig = checkSambaConfig(L, 1);
        const char *smbPath = luaL_checkstring(L, 2);
        const char *localPath = luaL_checkstring(L, 3);
        
        if (strncmp(smbPath, "smb://", sizeof("smb://") - 1) != 0)
        {
            return luaL_argerror(L, 2, "bad parameter: path must have prefix smb://");
        }
        
        if (argc > 3)
        {
            if (!lua_isfunction(L, 4))
            {
                return luaL_argerror(L, 4, "callback function expected");
            }
        }
        
        [[KxSMBProvider sharedSmbProvider] setConfig:copyConfigFromSambaConfig(smbConfig)];
        [[KxSMBProvider sharedSmbProvider] setCompletionQueue:_eventQueue];
        
        __block id item = nil;
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        [[KxSMBProvider sharedSmbProvider] copySMBPath:[NSString stringWithUTF8String:smbPath]
                                             localPath:[NSString stringWithUTF8String:localPath]
                                             overwrite:YES
                                                  auth:copyAuthFromSambaConfig(smbConfig) progress:^(KxSMBItem * _Nonnull item, long transferred, BOOL * _Nonnull stop) {
            if (argc > 3)
            {
                lua_pushvalue(L, 4);
                lua_pushNSDictionary(L, dictionaryFromItem(item, NO));
                lua_pushinteger(L, transferred);
                
                int ret = lua_pcall(L, 2, 1, 0);
                if (ret != LUA_OK)
                {
                    CHLog(@"upload session callback error: %s", lua_tostring(L, -1));
                    return;
                }
                
                int shouldStop = lua_isboolean(L, -1) ? lua_toboolean(L, -1) : false;
                lua_pop(L, 1);
                
                if (shouldStop)
                {
                    *stop = YES;
                }
            }
        } block:^(id  _Nullable result) {
            item = result;
            dispatch_semaphore_signal(sema);
        }];
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        
        if ([item isKindOfClass:[NSError class]])
        {
            lua_pushboolean(L, false);
            lua_pushstring(L, [[(NSError *)item localizedDescription] UTF8String]);
            return 2;
        }
        
        lua_pushboolean(L, true);
        lua_pushnil(L);
        return 2;
    }
}

static int SambaConfig_UploadItem(lua_State *L)
{
    @autoreleasepool {
        
        int argc = lua_gettop(L);
        
        SambaConfig *smbConfig = checkSambaConfig(L, 1);
        const char *localPath = luaL_checkstring(L, 2);
        const char *smbPath = luaL_checkstring(L, 3);
        
        if (strncmp(smbPath, "smb://", sizeof("smb://") - 1) != 0)
        {
            return luaL_argerror(L, 3, "bad parameter: path must have prefix smb://");
        }
        
        if (argc > 3)
        {
            if (!lua_isfunction(L, 4))
            {
                return luaL_argerror(L, 4, "callback function expected");
            }
        }
        
        [[KxSMBProvider sharedSmbProvider] setConfig:copyConfigFromSambaConfig(smbConfig)];
        [[KxSMBProvider sharedSmbProvider] setCompletionQueue:_eventQueue];
        
        __block id item = nil;
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        [[KxSMBProvider sharedSmbProvider] copyLocalPath:[NSString stringWithUTF8String:localPath]
                                                 smbPath:[NSString stringWithUTF8String:smbPath]
                                               overwrite:YES
                                                    auth:copyAuthFromSambaConfig(smbConfig)
                                                progress:^(KxSMBItem * _Nonnull item, long transferred, BOOL * _Nonnull stop) {
            if (argc > 3)
            {
                lua_pushvalue(L, 4);
                lua_pushNSDictionary(L, dictionaryFromItem(item, NO));
                lua_pushinteger(L, transferred);
                
                int ret = lua_pcall(L, 2, 1, 0);
                if (ret != LUA_OK)
                {
                    CHLog(@"upload session callback error: %s", lua_tostring(L, -1));
                    return;
                }
                
                int shouldStop = lua_isboolean(L, -1) ? lua_toboolean(L, -1) : false;
                lua_pop(L, 1);
                
                if (shouldStop)
                {
                    *stop = YES;
                }
            }
        } block:^(id  _Nullable result) {
            item = result;
            dispatch_semaphore_signal(sema);
        }];
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        
        if ([item isKindOfClass:[NSError class]])
        {
            lua_pushboolean(L, false);
            lua_pushstring(L, [[(NSError *)item localizedDescription] UTF8String]);
            return 2;
        }
        
        lua_pushboolean(L, true);
        lua_pushnil(L);
        return 2;
    }
}


#pragma mark -

static const luaL_Reg SambaConfig_MetaLib[] = {
    
    /* Internal APIs */
    {"__gc",       SambaConfig_GC},
    {"__tostring", SambaConfig_ToString},
    
    /* Directory Operation */
    {"list", SambaConfig_ListDirectory},
    {"mkdir", SambaConfig_CreateDirectory},
    {"rmdir", SambaConfig_RemoveDirectory},
    
    /* Rename Operation */
    {"move", SambaConfig_RenameItem},
    {"rename", SambaConfig_RenameItem},
    
    /* Unlink Operation */
    {"remove", SambaConfig_RemoveItem},
    {"unlink", SambaConfig_RemoveItem},
    
    /* Upload Operation */
    {"touch", SambaConfig_TouchFile},
    {"upload", SambaConfig_UploadItem},
    
    /* Download Operation */
    {"download", SambaConfig_DownloadItem},
    
    {NULL, NULL},
};

static const luaL_Reg Samba_AuxLib[] = {
    
    /* Low-Level APIs */
    {"is", Samba_IsClient},
    {"client", Samba_NewClient},
    
    {NULL, NULL},
};


#pragma mark -

XXTouchF_CAPI int luaopen_samba(lua_State *L)
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _eventQueue = dispatch_queue_create("ch.xxtou.queue.samba", DISPATCH_QUEUE_SERIAL_WITH_AUTORELEASE_POOL);
        
        luaL_newmetatable(L, L_TYPE_SAMBA_CONFIG);
        lua_pushstring(L, "__index");
        lua_pushvalue(L, -2);
        lua_settable(L, -3);
        luaL_setfuncs(L, SambaConfig_MetaLib, 0);
    });
    
    lua_createtable(L, 0, (sizeof(Samba_AuxLib) / sizeof((Samba_AuxLib)[0]) - 1) + 2);
    lua_pushliteral(L, LUA_MODULE_VERSION);
    lua_setfield(L, -2, "_VERSION");
    luaL_setfuncs(L, Samba_AuxLib, 0);
    
    return 1;
}
