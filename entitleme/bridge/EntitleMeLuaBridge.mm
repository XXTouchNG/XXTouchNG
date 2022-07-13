#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import "lua.hpp"

#import "luae.h"
#import "EntitleMe.h"


#pragma mark -

XXTouchF_CAPI int luaopen_xxtouch_entitleme(lua_State *L);


#pragma mark -

static int EntitleMe_QueryDaemonStatus(lua_State *L)
{
    @autoreleasepool {
        lua_pushNSDictionary(L, [[EntitleMe sharedInstance] queryAuthKitDaemonStatus]);
        return 1;
    }
}

static int EntitleMe_SetupSignInSession(lua_State *L)
{
    @autoreleasepool {
        const char *cUsername = luaL_checkstring(L, 1);
        const char *cPassword = luaL_checkstring(L, 2);
        
        [[EntitleMe sharedInstance] setupSignInSessionWithUsername:[NSString stringWithUTF8String:cUsername]
                                                          Password:[NSString stringWithUTF8String:cPassword]];
        
        return 0;
    }
}

static int EntitleMe_TearDownSignInSession(lua_State *L)
{
    @autoreleasepool {
        [[EntitleMe sharedInstance] tearDownSignInSession];
        return 0;
    }
}

static int EntitleMe_GetCurrentStoreAccount(lua_State *L)
{
    @autoreleasepool {
        lua_pushNSDictionary(L, [[EntitleMe sharedInstance] currentStoreAccount]);
        return 1;
    }
}

static int EntitleMe_LogOutCurrentStoreAccount(lua_State *L)
{
    @autoreleasepool {
        [[EntitleMe sharedInstance] logoutCurrentStoreAccount];
        return 0;
    }
}


#pragma mark -

static const luaL_Reg EntitleMe_AuxLib[] = {
    {"__query", EntitleMe_QueryDaemonStatus},
    {"__setup", EntitleMe_SetupSignInSession},
    {"__teardown", EntitleMe_TearDownSignInSession},
    {"__account", EntitleMe_GetCurrentStoreAccount},
    {"__logout", EntitleMe_LogOutCurrentStoreAccount},
    {NULL, NULL},
};

XXTouchF_CAPI int luaopen_xxtouch_entitleme(lua_State *L)
{
    lua_createtable(L, 0, (sizeof(EntitleMe_AuxLib) / sizeof((EntitleMe_AuxLib)[0]) - 1) + 2);
    lua_pushliteral(L, LUA_MODULE_VERSION);
    lua_setfield(L, -2, "_VERSION");
    luaL_setfuncs(L, EntitleMe_AuxLib, 0);
    
    return 1;
}
