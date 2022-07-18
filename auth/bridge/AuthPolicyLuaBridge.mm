#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import "lua.hpp"
#import "luae.h"
#import "AuthPolicy.h"


#pragma mark -

XXTouchF_CAPI int luaopen_xxtouch_auth(lua_State *);


#pragma mark -

static int l_auth_code_signature(lua_State *L)
{
    @autoreleasepool {
        lua_Integer cPid = luaL_optinteger(L, 1, (lua_Integer)getpid());
        
        NSError *err = nil;
        NSDictionary *codeSignature = [[AuthPolicy sharedInstance] copyCodeSignatureWithProcessIdentifier:(pid_t)cPid error:&err];
        if (!codeSignature)
        {
            lua_pushnil(L);
            lua_pushstring(L, [[err localizedDescription] UTF8String]);
            return 2;
        }
        
        lua_pushNSDictionary(L, codeSignature);
        lua_pushnil(L);
        return 2;
    }
}

static int l_auth_entitlements(lua_State *L)
{
    @autoreleasepool {
        lua_Integer cPid = luaL_optinteger(L, 1, (lua_Integer)getpid());
        
        NSError *err = nil;
        NSDictionary *codeSignature = [[AuthPolicy sharedInstance] copyEntitlementsWithProcessIdentifier:(pid_t)cPid error:&err];
        if (!codeSignature)
        {
            lua_pushnil(L);
            lua_pushstring(L, [[err localizedDescription] UTF8String]);
            return 2;
        }
        
        lua_pushNSDictionary(L, codeSignature);
        lua_pushnil(L);
        return 2;
    }
}


#pragma mark -


static const luaL_Reg AuthPolicy_AuxLib[] = {
    {"code_signature", l_auth_code_signature},
    {"entitlements", l_auth_entitlements},
    {NULL, NULL},
};


#pragma mark -

XXTouchF_CAPI int luaopen_xxtouch_auth(lua_State *L)
{
    lua_createtable(L, 0, (sizeof(AuthPolicy_AuxLib) / sizeof((AuthPolicy_AuxLib)[0]) - 1) + 2);
    lua_pushliteral(L, LUA_MODULE_VERSION);
    lua_setfield(L, -2, "_VERSION");
    luaL_setfuncs(L, AuthPolicy_AuxLib, 0);

    return 1;
}
