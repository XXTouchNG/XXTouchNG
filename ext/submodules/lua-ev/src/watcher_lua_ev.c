#include <stdint.h>

static const char* watcher_magic = "a string that is used"
    " to mark a watcher";

/**
 * Add watcher specific methods to the table on the top of the lua
 * stack.
 *
 * [-0, +0, ?]
 */
static int add_watcher_mt(lua_State *L) {

    static luaL_Reg fns[] = {
        { "is_active",     watcher_is_active },
        { "is_pending",    watcher_is_pending },
        { "clear_pending", watcher_clear_pending },
        { "callback",      watcher_callback },
        { "priority",      watcher_priority },
        { "__index",       obj_index },
        { "__newindex",    obj_newindex },
        { NULL, NULL }
    };
    luaL_setfuncs(L, fns, 0);

    /* Mark this as being a watcher: */
    lua_pushliteral(L, "is_watcher__");
    lua_pushlightuserdata(L, (void*)watcher_magic);
    lua_rawset(L, -3);

    return 0;
}

/**
 * Checks that we have a watcher at watcher_i index by validating the
 * metatable has the is_watcher__ field set to the watcher magic light
 * userdata that is simply used to mark a metatable as being a
 * "watcher".
 *
 * [-0, +0, ?]
 */
static struct ev_watcher* check_watcher(lua_State *L, int watcher_i) {
    void *watcher = lua_touserdata(L, watcher_i);
    if ( watcher != NULL ) { /* Got a userdata? */
        if ( lua_getmetatable(L, watcher_i) ) { /* got a metatable? */
            lua_getfield(L, -1, "is_watcher__");
            lua_pushlightuserdata(L, (void*)watcher_magic);

            if ( lua_rawequal(L, -1, -2) ) {
                lua_pop(L, 3);
                return (struct ev_watcher*)watcher;
            }
        }
    }
    luaL_error(L, "ev{io,timer,signal,idle} expected, got %s", luaL_typename(L, watcher_i));
    return NULL;
}

/**
 * Test if the watcher is active.
 *
 * Usage:
 *   bool = watcher:is_active()
 *
 * [+1, -0, e]
 */
static int watcher_is_active(lua_State *L) {
    lua_pushboolean(L, ev_is_active(check_watcher(L, 1)));
    return 1;
}

/**
 * Test if the watcher is pending.
 *
 * Usage:
 *   bool = watcher:is_pending()
 *
 * [+1, -0, e]
 */
static int watcher_is_pending(lua_State *L) {
    lua_pushboolean(L, ev_is_pending(check_watcher(L, 1)));
    return 1;
}

/**
 * If the watcher is pending, return the revents and clear the pending
 * status (so the watcher callback won't be called).
 *
 * Usage:
 *   revents = watcher:clear_pending(loop)
 *
 * [+1, -0, e]
 */
static int watcher_clear_pending(lua_State *L) {
    lua_pushnumber(L, ev_clear_pending(*check_loop_and_init(L, 2), check_watcher(L, 1)));
    return 1;
}

/**
 * Implement the new function on all the watcher objects.  The first
 * element on the stack must be the callback function.  The new
 * "watcher" is now at the top of the stack.
 *
 * [+1, -0, ?]
 */
static void* watcher_new(lua_State* L, size_t size, const char* lua_type) {
    void*  obj;

    luaL_checktype(L, 1, LUA_TFUNCTION);

    obj = obj_new(L, size, lua_type);
    register_obj(L, -1, obj);

    lua_getuservalue(L, -1);
    lua_pushvalue(L, 1);
    lua_rawseti(L, -2, WATCHER_FN);

    lua_pop(L, 1);

    return obj;
}

/**
 * Implements the callback function on all the watcher objects.  This
 * will be indirectly called by the libev event loop implementation.
 *
 * TODO: Custom error handlers?  Currently, any error in a callback
 * will print the error to stderr and things will "go on".
 *
 * [+0, -0, m]
 */
static void watcher_cb(struct ev_loop *loop, void *watcher, int revents) {
    lua_State* L       = ev_userdata(loop);
    void*      objs[3] = { loop, watcher, NULL };
    int        result;

    lua_pushcfunction(L, traceback);

    result = lua_checkstack(L, 5);
    assert(result != 0 /* able to allocate enough space on lua stack */);
    result = push_objs(L, objs);
    assert(result == 2 /* pushed two objects on the lua stack */);
    assert(!lua_isnil(L, -2) /* the loop obj was resolved */);
    assert(!lua_isnil(L, -1) /* the watcher obj was resolved */);

    /* STACK: <traceback>, <loop>, <watcher> */

    if ( !ev_is_active(watcher) ) {
        /* Must remove "stop"ed watcher from loop: */
        loop_stop_watcher(L, -2, -1);
    }

    lua_getuservalue(L, -1);
    assert(lua_istable(L, -1) /* The watcher fenv was found */);
    lua_rawgeti(L, -1, WATCHER_FN);
    if ( lua_isnil(L, -1) ) {
        /* The watcher function was set to nil, so do nothing */
        lua_pop(L, 5);
        return;
    }
    assert(lua_isfunction(L, -1) /* watcher function is a function */);

    /* STACK: <traceback>, <loop>, <watcher>, <watcher fenv>, <watcher fn> */

    lua_insert(L, -4);
    lua_pop(L, 1);
    lua_pushinteger(L, revents);

    /* STACK: <traceback>, <watcher fn>, <loop>, <watcher>, <revents> */
    if ( lua_pcall(L, 3, 0, -5) ) {
        /* TODO: Enable user-specified error handler! */
        fprintf(stderr, "CALLBACK FAILED: %s\n",
                lua_tostring(L, -1));
        lua_pop(L, 2);
    } else {
        lua_pop(L, 1);
    }
}

/**
 * Get/set the watcher callback.  If passed a new_callback, then the
 * old_callback will be returned.  Otherwise, just returns the current
 * callback function.
 *
 * Usage:
 *   old_callback = watcher:callback([new_callback])
 *
 * [+1, -0, e]
 */
static int watcher_callback(lua_State *L) {
    int has_fn = lua_gettop(L) > 1;

    check_watcher(L, 1);
    if ( has_fn ) luaL_checktype(L, 2, LUA_TFUNCTION);

    lua_getuservalue(L, 1);
    assert(lua_istable(L, -1) /* getfenv of watcher worked */);
    lua_rawgeti(L, -1, WATCHER_FN);
    if ( has_fn ) {
        lua_pushvalue(L, 2);
        lua_rawseti(L, -3, WATCHER_FN);
    }
    lua_remove(L, -2);
    return 1;
}

/**
 * Get/set the watcher priority.  If passed a new_priority, then the
 * old_priority will be returned.  Otherwise, just returns the current
 * priority.
 *
 * Usage:
 *   old_priority = watcher:priority([new_priority])
 *
 * [+1, -0, e]
 */
static int watcher_priority(lua_State *L) {
    int has_pri = lua_gettop(L) > 1;
    ev_watcher *w = check_watcher(L, 1);
    int old_pri = ev_priority(w);

#if LUA_VERSION_NUM > 502
    if ( has_pri ) ev_set_priority(w, (int)luaL_checkinteger(L, 2));
#else
    if ( has_pri ) ev_set_priority(w, luaL_checkint(L, 2));
#endif
    lua_pushinteger(L, old_pri);
    return 1;
}
