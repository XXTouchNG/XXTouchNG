//////////////////////////////////////////////////////////////////////
// Implement the archive{registry} weak table
//////////////////////////////////////////////////////////////////////

#include <archive.h>
#include <ctype.h>
#include <lauxlib.h>
#include <lua.h>
#include <stdlib.h>
#include <string.h>

#include "ar_registry.h"

//////////////////////////////////////////////////////////////////////
// Precondition: User-data is at the top of the stack.
// 
// Postcondition: ptr is the light user data key into the registry
// that points to the full user data.
//////////////////////////////////////////////////////////////////////
void ar_registry_set(lua_State *L, void *ptr) {
    luaL_checktype(L, -1, LUA_TUSERDATA); // {ud}
    luaL_getmetatable(L, AR_REGISTRY); // {ud}, {registry}
    lua_pushlightuserdata(L, ptr); // {ud}, {registry}, <ptr>
    lua_pushvalue(L, -3); // {ud}, {registry}, <ptr>, {ud}
    lua_rawset(L, -3); // {ud}, {registry}
    lua_pop(L, 1); // {ud}
}

// Returns true if value was pushed on the stack.
int ar_registry_get(lua_State *L, void *ptr) {
    luaL_getmetatable(L, AR_REGISTRY); // {registry}
    lua_pushlightuserdata(L, ptr); // {registry}, <ptr>
    lua_rawget(L, -2); // {registry}, {ud}
    if ( lua_isnil(L, -1) ) {
        lua_pop(L, 2);
        return 0;
    }
    lua_insert(L, -2); // {ud}, {registry}
    lua_pop(L, 1); // {ud}
    return 1;
}

void ar_registry_init(lua_State *L) {
    luaL_newmetatable(L, AR_REGISTRY); // {class}, {meta}
    
    lua_pushvalue(L, -1); // {class}, {meta}, {meta}
    lua_setmetatable(L, -2); // {class}, {meta}

    lua_pushstring(L, "v"); // {class}, {meta}, "v"
    lua_setfield(L, -2, "__mode"); // {class}, {meta}

    lua_pop(L, 1); // {class}
}
