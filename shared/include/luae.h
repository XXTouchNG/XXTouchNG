#import <stdio.h>
#import <stdlib.h>
#import <string.h>

#import "lua.hpp"

#import <Foundation/Foundation.h>


typedef struct luaE_Reg {
    const char *name;
    const char *func_name;
    lua_CFunction func;
} luaE_Reg;

#define luaE_arg_error(N, pos, fmt, arg...) \
luaL_error(L, "[%s] Invalid argument #%d: " fmt, luaE_func2name(__func__, LUAE_LIB_FUNCS_## N), pos, ##arg)

#define luaE_nsarg_error(N, pos, msg) \
luaL_error(L, "[%s] Invalid argument #%d: %s", luaE_func2name(__func__, LUAE_LIB_FUNCS_## N), pos, [msg UTF8String])

#ifdef  __cplusplus
#define _ELIB_DECL(N) \
extern "C" const luaE_Reg LUAE_LIB_FUNCS_## N []
#else
#define _ELIB_DECL(N) \
extern const luaE_Reg LUAE_LIB_FUNCS_## N []
#endif

#define _ELIB(N) \
const luaE_Reg LUAE_LIB_FUNCS_## N []

#ifdef  __cplusplus
#define _ELIB_API(N) \
extern "C" int luaopen_## N (lua_State *L)
#else
#define _ELIB_API(N) \
extern int luaopen_## N (lua_State *L)
#endif

#define _EFUNC(N) static int LuaE_## N (lua_State *L)

#define _EBEGIN \
int L_ECODE = -1; NSString *L_EMSG = nil;

#define _ECHK \
if (L_ECODE == -1)

#define _EARG(C, M) \
L_ECODE = C; L_EMSG = (M);

#define _EEND(N) \
if (L_ECODE != -1) { \
    luaE_nsarg_error(N, L_ECODE, L_EMSG); \
} \
return 0;

#define _EPOOL @autoreleasepool

#define _EREG(F, E) \
{E, #F, F}

#ifdef  __cplusplus
extern "C" {
#endif

void luaE_newelib(lua_State *, const struct luaE_Reg *);
void luaE_setelib(lua_State *, const struct luaE_Reg *);
const char *luaE_func2name(const char *, const struct luaE_Reg *);
void lua_setPath(lua_State *, const char *, const char *);

#ifdef  __cplusplus
}
#endif

#pragma mark - NSValue

#ifdef  __cplusplus
extern "C" {
#endif

int lua_table_is_array(lua_State *L, int index);
void lua_pushNSValuex(lua_State *L, id value, int level);
id lua_toNSValuex(lua_State *L, int index, int level);
void luaE_checkarray(lua_State *L, int index);
void luaE_checkdictionary(lua_State *L, int index);

#ifdef  __cplusplus
}
#endif

#define lua_pushNSValue(L,V) lua_pushNSValuex(L,V,0)
#define lua_toNSValue(L,V) lua_toNSValuex(L,V,0)

#define lua_pushNSArray(L,V) \
    assert([(V) isKindOfClass:[NSArray class]]); \
    lua_pushNSValuex(L,V,0)

#define lua_pushNSDictionary(L,V) \
    assert([(V) isKindOfClass:[NSDictionary class]]); \
    lua_pushNSValuex(L,V,0)

#define lua_toNSArray(L,V) ({ \
    luaE_checkarray(L, V); \
    lua_toNSValuex(L,V,0); \
})

#define lua_toNSDictionary(L,V) ({ \
    luaE_checkdictionary(L, V); \
    lua_toNSValuex(L,V,0); \
})
