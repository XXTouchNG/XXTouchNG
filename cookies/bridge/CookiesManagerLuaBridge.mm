#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import "luae.h"
#import <mach/mach.h>
#import "TFCookiesManager.h"


#pragma mark -

XXTouchF_CAPI int luaopen_cookies(lua_State *L);


#pragma mark -

static int CookiesManager_ValueOfCookies(lua_State *L)
{
    @autoreleasepool
    {
        NSString *name = nil;
        NSString *path = nil;
        NSString *domain = nil;
        NSString *anyID = nil;
        
        if (lua_gettop(L) >= 1 && lua_type(L, 1) == LUA_TTABLE)
        {
            NSDictionary *dict = lua_toNSDictionary(L, 1);
            
            name = dict[@"name"] ?: dict[@"Name"] ?: @"";
            path = dict[@"path"] ?: dict[@"Path"] ?: @"";
            domain = dict[@"domain"] ?: dict[@"Domain"] ?: @"";
            anyID = dict[@"id"] ?: @"";
            
            if (!anyID.length && lua_gettop(L) >= 2)
            {
                const char *cAnyID = luaL_optstring(L, 2, "");
                anyID = [NSString stringWithUTF8String:cAnyID];
            }
        }
        else
        {
            const char *cName = luaL_optstring(L, 1, "");
            const char *cPath = luaL_optstring(L, 2, "");
            const char *cDomain = luaL_optstring(L, 3, "");
            const char *cAnyID = luaL_optstring(L, 4, "");
            
            name = [NSString stringWithUTF8String:cName];
            path = [NSString stringWithUTF8String:cPath];
            domain = [NSString stringWithUTF8String:cDomain];
            anyID = [NSString stringWithUTF8String:cAnyID];
        }
        
        TFCookiesManager *cookiesMgr = nil;
        if (anyID.length)
        {
            cookiesMgr = [TFCookiesManager managerWithAnyIdentifier:anyID];
        }
        else
        {
            cookiesMgr = [TFCookiesManager sharedSafariManager];
        }
        
        NSError *err = nil;
        NSDictionary *cookies = [cookiesMgr getCookiesWithDomain:domain
                                                            path:path
                                                            name:name
                                                           error:&err];
        if (!cookies)
        {
            lua_pushnil(L);
            lua_pushstring(L, [[err localizedDescription] UTF8String]);
            return 2;
        }
        
        if (!cookies[NSHTTPCookieValue])
        {
            lua_pushnil(L);
            lua_pushnil(L);
            return 2;
        }
        
        lua_pushNSValue(L, cookies[NSHTTPCookieValue]);
        lua_pushnil(L);
        return 2;
    }
}

static int CookiesManager_GetCookies(lua_State *L)
{
    @autoreleasepool
    {
        NSString *name = nil;
        NSString *path = nil;
        NSString *domain = nil;
        NSString *anyID = nil;
        
        if (lua_gettop(L) >= 1 && lua_type(L, 1) == LUA_TTABLE)
        {
            NSDictionary *dict = lua_toNSDictionary(L, 1);
            
            name = dict[@"name"] ?: dict[@"Name"] ?: @"";
            path = dict[@"path"] ?: dict[@"Path"] ?: @"";
            domain = dict[@"domain"] ?: dict[@"Domain"] ?: @"";
            anyID = dict[@"id"] ?: @"";
            
            if (!anyID.length && lua_gettop(L) >= 2)
            {
                const char *cAnyID = luaL_optstring(L, 2, "");
                anyID = [NSString stringWithUTF8String:cAnyID];
            }
        }
        else
        {
            const char *cName = luaL_optstring(L, 1, "");
            const char *cPath = luaL_optstring(L, 2, "");
            const char *cDomain = luaL_optstring(L, 3, "");
            const char *cAnyID = luaL_optstring(L, 4, "");
            
            name = [NSString stringWithUTF8String:cName];
            path = [NSString stringWithUTF8String:cPath];
            domain = [NSString stringWithUTF8String:cDomain];
            anyID = [NSString stringWithUTF8String:cAnyID];
        }
        
        TFCookiesManager *cookiesMgr = nil;
        if (anyID.length)
        {
            cookiesMgr = [TFCookiesManager managerWithAnyIdentifier:anyID];
        }
        else
        {
            cookiesMgr = [TFCookiesManager sharedSafariManager];
        }
        
        NSError *err = nil;
        NSDictionary *cookies = [cookiesMgr getCookiesWithDomain:domain
                                                            path:path
                                                            name:name
                                                           error:&err];
        if (!cookies)
        {
            lua_pushnil(L);
            lua_pushstring(L, [[err localizedDescription] UTF8String]);
            return 2;
        }
        
        lua_pushNSDictionary(L, cookies);
        lua_pushnil(L);
        return 2;
    }
}

static int CookiesManager_ListCookies(lua_State *L)
{
    @autoreleasepool
    {
        NSString *anyID = nil;
        
        if (lua_gettop(L) >= 1 && lua_type(L, 1) == LUA_TTABLE)
        {
            NSDictionary *dict = lua_toNSDictionary(L, 1);
            
            anyID = dict[@"id"] ?: @"";
        }
        else
        {
            const char *cAnyID = luaL_optstring(L, 1, "");
            
            anyID = [NSString stringWithUTF8String:cAnyID];
        }
        
        TFCookiesManager *cookiesMgr = nil;
        if (anyID.length)
        {
            cookiesMgr = [TFCookiesManager managerWithAnyIdentifier:anyID];
        }
        else
        {
            cookiesMgr = [TFCookiesManager sharedSafariManager];
        }
        
        NSError *err = nil;
        NSArray <NSDictionary *> *allCookies = [cookiesMgr readCookiesWithError:&err];
        if (!allCookies)
        {
            lua_pushnil(L);
            lua_pushstring(L, [[err localizedDescription] UTF8String]);
            return 2;
        }
        
        lua_pushNSArray(L, allCookies);
        lua_pushnil(L);
        return 2;
    }
}

static int CookiesManager_FilterCookies(lua_State *L)
{
    @autoreleasepool
    {
        NSString *path = nil;
        NSString *domain = nil;
        NSString *anyID = nil;
        
        if (lua_gettop(L) >= 1 && lua_type(L, 1) == LUA_TTABLE)
        {
            NSDictionary *dict = lua_toNSDictionary(L, 1);
            
            path = dict[@"path"] ?: dict[@"Path"] ?: @"";
            domain = dict[@"domain"] ?: dict[@"Domain"] ?: @"";
            anyID = dict[@"id"] ?: @"";
            
            if (!anyID.length && lua_gettop(L) >= 2)
            {
                const char *cAnyID = luaL_optstring(L, 2, "");
                anyID = [NSString stringWithUTF8String:cAnyID];
            }
        }
        else
        {
            const char *cPath = luaL_optstring(L, 1, "");
            const char *cDomain = luaL_optstring(L, 2, "");
            const char *cAnyID = luaL_optstring(L, 3, "");
            
            path = [NSString stringWithUTF8String:cPath];
            domain = [NSString stringWithUTF8String:cDomain];
            anyID = [NSString stringWithUTF8String:cAnyID];
        }
        
        TFCookiesManager *cookiesMgr = nil;
        if (anyID.length)
        {
            cookiesMgr = [TFCookiesManager managerWithAnyIdentifier:anyID];
        }
        else
        {
            cookiesMgr = [TFCookiesManager sharedSafariManager];
        }
        
        NSError *err = nil;
        NSArray <NSDictionary *> *allCookies = [cookiesMgr filterCookiesWithDomain:domain
                                                                              path:path
                                                                             error:&err];
        if (!allCookies)
        {
            lua_pushnil(L);
            lua_pushstring(L, [[err localizedDescription] UTF8String]);
            return 2;
        }
        
        lua_pushNSArray(L, allCookies);
        lua_pushnil(L);
        return 2;
    }
}

static int CookiesManager_UpdateCookies(lua_State *L)
{
    @autoreleasepool
    {
        NSArray <NSDictionary *> *allCookies = lua_toNSValue(L, 1);
        if ([allCookies isKindOfClass:[NSDictionary class]])
        {
            allCookies = [NSArray arrayWithObjects:allCookies, nil];
        }
        else if ([allCookies isKindOfClass:[NSArray class]]) {}
        else
        {
            return luaL_argerror(L, 1, "table expected");
        }
        
        const char *cAnyID = luaL_optstring(L, 2, "");
        
        NSString *anyID = [NSString stringWithUTF8String:cAnyID];
        
        TFCookiesManager *cookiesMgr = nil;
        if (anyID.length)
        {
            cookiesMgr = [TFCookiesManager managerWithAnyIdentifier:anyID];
        }
        else
        {
            cookiesMgr = [TFCookiesManager sharedSafariManager];
        }
        
        NSError *err = nil;
        BOOL succeed = [cookiesMgr setCookies:allCookies error:&err];
        if (!succeed)
        {
            lua_pushboolean(L, false);
            lua_pushstring(L, [[err localizedDescription] UTF8String]);
            return 2;
        }
        
        lua_pushboolean(L, true);
        lua_pushnil(L);
        return 2;
    }
}

static int CookiesManager_ReplaceCookies(lua_State *L)
{
    @autoreleasepool
    {
        NSArray <NSDictionary *> *allCookies = lua_toNSValue(L, 1);
        if ([allCookies isKindOfClass:[NSDictionary class]])
        {
            allCookies = [NSArray arrayWithObjects:allCookies, nil];
        }
        else if ([allCookies isKindOfClass:[NSArray class]]) {}
        else
        {
            return luaL_argerror(L, 1, "table expected");
        }
        
        const char *cAnyID = luaL_optstring(L, 2, "");
        
        NSString *anyID = [NSString stringWithUTF8String:cAnyID];
        
        TFCookiesManager *cookiesMgr = nil;
        if (anyID.length)
        {
            cookiesMgr = [TFCookiesManager managerWithAnyIdentifier:anyID];
        }
        else
        {
            cookiesMgr = [TFCookiesManager sharedSafariManager];
        }
        
        NSError *err = nil;
        BOOL succeed = [cookiesMgr writeCookies:allCookies error:&err];
        if (!succeed)
        {
            lua_pushboolean(L, false);
            lua_pushstring(L, [[err localizedDescription] UTF8String]);
            return 2;
        }
        
        lua_pushboolean(L, true);
        lua_pushnil(L);
        return 2;
    }
}

static int CookiesManager_RemoveCookies(lua_State *L)
{
    @autoreleasepool
    {
        NSString *name = nil;
        NSString *path = nil;
        NSString *domain = nil;
        NSString *anyID = nil;
        
        if (lua_gettop(L) >= 1 && lua_type(L, 1) == LUA_TTABLE)
        {
            NSDictionary *dict = lua_toNSDictionary(L, 1);
            
            name = dict[@"name"] ?: dict[@"Name"] ?: @"";
            path = dict[@"path"] ?: dict[@"Path"] ?: @"";
            domain = dict[@"domain"] ?: dict[@"Domain"] ?: @"";
            anyID = dict[@"id"] ?: @"";
            
            if (!anyID.length && lua_gettop(L) >= 2)
            {
                const char *cAnyID = luaL_optstring(L, 2, "");
                anyID = [NSString stringWithUTF8String:cAnyID];
            }
        }
        else
        {
            const char *cName = luaL_optstring(L, 1, "");
            const char *cPath = luaL_optstring(L, 2, "");
            const char *cDomain = luaL_optstring(L, 3, "");
            const char *cAnyID = luaL_optstring(L, 4, "");
            
            name = [NSString stringWithUTF8String:cName];
            path = [NSString stringWithUTF8String:cPath];
            domain = [NSString stringWithUTF8String:cDomain];
            anyID = [NSString stringWithUTF8String:cAnyID];
        }
        
        TFCookiesManager *cookiesMgr = nil;
        if (anyID.length)
        {
            cookiesMgr = [TFCookiesManager managerWithAnyIdentifier:anyID];
        }
        else
        {
            cookiesMgr = [TFCookiesManager sharedSafariManager];
        }
        
        NSError *err = nil;
        BOOL succeed = [cookiesMgr removeCookiesWithDomain:domain
                                                      path:path
                                                      name:name
                                                     error:&err];
        if (!succeed)
        {
            lua_pushboolean(L, false);
            lua_pushstring(L, [[err localizedDescription] UTF8String]);
            return 2;
        }
        
        lua_pushboolean(L, true);
        lua_pushnil(L);
        return 2;
    }
}

static int CookiesManager_ClearCookies(lua_State *L)
{
    @autoreleasepool
    {
        NSString *anyID = nil;
        
        if (lua_gettop(L) >= 1 && lua_type(L, 1) == LUA_TTABLE)
        {
            NSDictionary *dict = lua_toNSDictionary(L, 1);
            
            anyID = dict[@"id"] ?: @"";
        }
        else
        {
            const char *cAnyID = luaL_optstring(L, 1, "");
            
            anyID = [NSString stringWithUTF8String:cAnyID];
        }
        
        TFCookiesManager *cookiesMgr = nil;
        if (anyID.length)
        {
            cookiesMgr = [TFCookiesManager managerWithAnyIdentifier:anyID];
        }
        else
        {
            cookiesMgr = [TFCookiesManager sharedSafariManager];
        }
        
        NSError *err = nil;
        BOOL succeed = [cookiesMgr clearCookiesWithError:&err];
        if (!succeed)
        {
            lua_pushboolean(L, false);
            lua_pushstring(L, [[err localizedDescription] UTF8String]);
            return 2;
        }
        
        lua_pushboolean(L, true);
        lua_pushnil(L);
        return 2;
    }
}

#pragma mark -

static const luaL_Reg CookiesManager_AuxLib[] = {
    {"value", CookiesManager_ValueOfCookies},
    {"get", CookiesManager_GetCookies},
    {"list", CookiesManager_ListCookies},
    {"filter", CookiesManager_FilterCookies},
    {"update", CookiesManager_UpdateCookies},
    {"replace", CookiesManager_ReplaceCookies},
    {"remove", CookiesManager_RemoveCookies},
    {"clear", CookiesManager_ClearCookies},
    {NULL, NULL}
};


#pragma mark -

XXTouchF_CAPI int luaopen_cookies(lua_State *L)
{
    lua_createtable(L, 0, (sizeof(CookiesManager_AuxLib) / sizeof((CookiesManager_AuxLib)[0]) - 1) + 2);
    lua_pushliteral(L, LUA_MODULE_VERSION);
    lua_setfield(L, -2, "_VERSION");
    luaL_setfuncs(L, CookiesManager_AuxLib, 0);
    
    return 1;
}
