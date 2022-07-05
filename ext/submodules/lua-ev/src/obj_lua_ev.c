#include <stdarg.h>

static char* obj_registry = "ev{obj}";

/**
 * Create a "registry" of light userdata pointers into the
 * fulluserdata so that we can get handles into the lua objects.
 */
static void create_obj_registry(lua_State *L) {
    lua_pushlightuserdata(L, &obj_registry);
    lua_newtable(L);

    lua_createtable(L,  0, 1);
    lua_pushliteral(L,   "v");
    lua_setfield(L,     -2, "__mode");
    lua_setmetatable(L, -2);

    lua_rawset(L, LUA_REGISTRYINDEX);
}

/**
 * Count the number of registered objects.  This exists only so we can
 * validate that objects are properly GC'ed.
 *
 * [-0, +1, e]
 */
static int obj_count(lua_State *L) {
    int count = 0;

    lua_pushlightuserdata(L, &obj_registry);
    lua_rawget(L,            LUA_REGISTRYINDEX);
    assert(lua_istable(L, -1) /* create_obj_registry() should have ran */);

    lua_pushnil(L);
    while ( lua_next(L, -2) != 0 ) {
        count++;
        lua_pop(L, 1);
    }
    lua_pushinteger(L, count);
    return 1;
}

/**
 * Create a new "object" with a metatable of tname and allocate size
 * bytes for the object.  Also create an fenv associated with the
 * object.  This fenv is used to keep track of lua objects so that the
 * garbage collector doesn't prematurely collect lua objects that are
 * referenced by the C data structure.
 *
 * [-0, +1, ?]
 */
static void* obj_new(lua_State* L, size_t size, const char* tname) {
    void* obj;

    obj = lua_newuserdata(L, size);
    luaL_getmetatable(L,     tname);
    lua_setmetatable(L,      -2);

    /* Optimized for "watcher" creation that does not use a shadow
     * table:
     */
    lua_createtable(L, 1, 0);
    lua_setuservalue(L, -2);

    return obj;
}

/**
 * Lazily create the shadow table, and provide write access to this
 * shadow table.
 *
 * [-0, +0, ?]
 */
static int obj_newindex(lua_State *L) {
    lua_getuservalue(L, 1);
    lua_rawgeti(L, -1, WATCHER_SHADOW);

    /* fenv, shadow */
    if ( lua_isnil(L, -1) ) {
        /* Lazily create the shadow table: */
        lua_pop(L, 1);
        lua_newtable(L);
        lua_pushvalue(L, -1);
        lua_rawseti(L, -3, WATCHER_SHADOW);
    }

    /* h(table, key,value) */
    lua_replace(L, 1);
    lua_settop(L, 3);
    lua_settable(L, 1);
    return 0;
}

/**
 * Provide read access to the shadow table.
 *
 * [-0, +1, ?]
 */
static int obj_index(lua_State *L) {
    if ( lua_getmetatable(L, 1) ) {
        lua_pushvalue(L, 2);
        lua_gettable(L, -2);
        if ( ! lua_isnil(L, -1) ) return 1;
        lua_pop(L, 1);
    }
    lua_getuservalue(L, 1);
    lua_rawgeti(L, -1, WATCHER_SHADOW);

    if ( lua_isnil(L, -1) ) return 1;

    lua_pushvalue(L, 2);
    lua_gettable(L, -2);
    return 1;
}

/**
 * Register the lua object at index obj_i so it is keyed off of the
 * obj pointer.
 *
 * [-0, +0, ?]
 */
static void register_obj(lua_State*L, int obj_i, void* obj) {
    obj_i = lua_absindex(L, obj_i);

    lua_pushlightuserdata(L, &obj_registry);
    lua_rawget(L,            LUA_REGISTRYINDEX);
    assert(lua_istable(L, -1) /* create_obj_registry() should have ran */);

    lua_pushlightuserdata(L, obj);
    lua_pushvalue(L,         obj_i);
    lua_rawset(L,            -3);
    lua_pop(L,               1);
}

/**
 * Pushes the lua representation of n objects onto the stack.  The
 * objs array must be NULL terminated.  Returns the number of objects
 * pushed onto the stack.
 *
 * [-0, +objs_len, m]
 */
static int push_objs(lua_State* L, void** objs) {
    int obj_count = 0;
    int registry_i;
    void** cur;

    for ( cur=objs; *cur; ++cur ) obj_count++;

    if ( 0 == obj_count ) return obj_count;

    lua_checkstack(L, obj_count + 1);

    lua_pushlightuserdata(L, &obj_registry);
    lua_rawget(L,            LUA_REGISTRYINDEX);
    assert(lua_istable(L, -1) /* create_obj_registry() should have ran */);

    registry_i = lua_gettop(L);
    for ( cur=objs; *cur; ++cur ) {
        lua_pushlightuserdata(L, *cur);
        lua_rawget(L, registry_i);
    }

    lua_remove(L, registry_i);

    return obj_count;
}
