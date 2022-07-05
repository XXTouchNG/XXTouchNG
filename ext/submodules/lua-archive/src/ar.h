#if !defined LUA_VERSION_NUM
/* Lua 5.0 */
#define luaL_Reg luaL_reg
#endif

#if LUA_VERSION_NUM <= 501
/* Lua 5.1 or older */
#define lua_setuservalue lua_setfenv
#define lua_getuservalue lua_getfenv
#endif
