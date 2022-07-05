/**
 * Create a table for ev.SIGNAL that gives access to the constructor for
 * signal objects.
 *
 * [-0, +1, ?]
 */
static int luaopen_ev_signal(lua_State *L) {
    lua_pop(L, create_signal_mt(L));

    lua_createtable(L, 0, 1);

    lua_pushcfunction(L, signal_new);
    lua_setfield(L, -2, "new");

    return 1;
}

/**
 * Create the signal metatable in the registry.
 *
 * [-0, +1, ?]
 */
static int create_signal_mt(lua_State *L) {

    static luaL_Reg fns[] = {
        { "stop",          signal_stop },
        { "start",         signal_start },
        { NULL, NULL }
    };
    luaL_newmetatable(L, SIGNAL_MT);
    add_watcher_mt(L);
    luaL_setfuncs(L, fns, 0);

    return 1;
}

/**
 * Create a new signal object.  Arguments:
 *   1 - callback function.
 *   2 - signal number
 *
 * @see watcher_new()
 *
 * [+1, -0, ?]
 */
static int signal_new(lua_State* L) {
#if LUA_VERSION_NUM > 502
    int         signum = (int)luaL_checkinteger(L, 2);
#else
    int         signum = luaL_checkint(L, 2);
#endif
    ev_signal*  sig;

    sig = watcher_new(L, sizeof(ev_signal), SIGNAL_MT);
    ev_signal_init(sig, &signal_cb, signum);
    return 1;
}

/**
 * @see watcher_cb()
 *
 * [+0, -0, m]
 */
static void signal_cb(struct ev_loop* loop, ev_signal* sig, int revents) {
    watcher_cb(loop, sig, revents);
}

/**
 * Stops the signal so it won't be called by the specified event loop.
 *
 * Usage:
 *     signal:stop(loop)
 *
 * [+0, -0, e]
 */
static int signal_stop(lua_State *L) {
    ev_signal*      sig  = check_signal(L, 1);
    struct ev_loop* loop = *check_loop_and_init(L, 2);

    loop_stop_watcher(L, 2, 1);
    ev_signal_stop(loop, sig);

    return 0;
}

/**
 * Starts the signal so it will be called by the specified event loop.
 *
 * Usage:
 *     signal:start(loop [, is_daemon])
 *
 * [+0, -0, e]
 */
static int signal_start(lua_State *L) {
    ev_signal*       sig = check_signal(L, 1);
    struct ev_loop* loop = *check_loop_and_init(L, 2);
    int is_daemon        = lua_toboolean(L, 3);

    ev_signal_start(loop, sig);
    loop_start_watcher(L, 2, 1, is_daemon);

    return 0;
}
