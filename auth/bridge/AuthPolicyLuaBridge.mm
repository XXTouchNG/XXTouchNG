#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import "lua.hpp"
#import "AuthPolicy.h"


#pragma mark -

XXTouchF_CAPI int luaopen_xxtouch_auth(lua_State *);


#pragma mark -

static int l_auth_status(lua_State *L)
{
    @autoreleasepool {
        return 0;
    }
}


#pragma mark -


static const luaL_Reg AuthPolicy_AuxLib[] = {
    {"status", l_auth_status},
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
