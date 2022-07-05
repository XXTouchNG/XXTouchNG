/**
 * Create a table for ev.Idle that gives access to the constructor for
 * idle objects.
 *
 * [-0, +1, ?]
 */
static int luaopen_ev_idle(lua_State *L) {
    lua_pop(L, create_idle_mt(L));

    lua_createtable(L, 0, 1);

    lua_pushcfunction(L, idle_new);
    lua_setfield(L, -2, "new");

    return 1;
}

/**
 * Create the idle metatable in the registry.
 *
 * [-0, +1, ?]
 */
static int create_idle_mt(lua_State *L) {

    static luaL_Reg fns[] = {
        { "stop",          idle_stop },
        { "start",         idle_start },
        { NULL, NULL }
    };
    luaL_newmetatable(L, IDLE_MT);
    add_watcher_mt(L);
    luaL_setfuncs(L, fns, 0);

    return 1;
}

/**
 * Create a new idle object.  Arguments:
 *   1 - callback function.
 *
 * @see watcher_new()
 *
 * [+1, -0, ?]
 */
static int idle_new(lua_State* L) {
    ev_idle*  idle;

    idle = watcher_new(L, sizeof(ev_idle), IDLE_MT);
    ev_idle_init(idle, &idle_cb);
    return 1;
}

/**
 * @see watcher_cb()
 *
 * [+0, -0, m]
 */
static void idle_cb(struct ev_loop* loop, ev_idle* idle, int revents) {
    watcher_cb(loop, idle, revents);
}

/**
 * Stops the idle so it won't be called by the specified event loop.
 *
 * Usage:
 *     idle:stop(loop)
 *
 * [+0, -0, e]
 */
static int idle_stop(lua_State *L) {
    ev_idle*        idle   = check_idle(L, 1);
    struct ev_loop* loop   = *check_loop_and_init(L, 2);

    loop_stop_watcher(L, 2, 1);
    ev_idle_stop(loop, idle);

    return 0;
}

/**
 * Starts the idle so it won't be called by the specified event loop.
 *
 * Usage:
 *     idle:start(loop [, is_daemon])
 *
 * [+0, -0, e]
 */
static int idle_start(lua_State *L) {
    ev_idle*        idle   = check_idle(L, 1);
    struct ev_loop* loop   = *check_loop_and_init(L, 2);
    int is_daemon          = lua_toboolean(L, 3);

    ev_idle_start(loop, idle);
    loop_start_watcher(L, 2, 1, is_daemon);

    return 0;
}
