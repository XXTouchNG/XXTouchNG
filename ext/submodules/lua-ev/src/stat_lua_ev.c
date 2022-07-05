/**
 * Create a table for ev.STAT that gives access to the constructor for
 * stat objects.
 *
 * [-0, +1, ?]
 */
static int luaopen_ev_stat(lua_State *L) {
    lua_pop(L, create_stat_mt(L));

    lua_createtable(L, 0, 1);

    lua_pushcfunction(L, stat_new);
    lua_setfield(L, -2, "new");

    return 1;
}

/**
 * Create the stat metatable in the registry.
 *
 * [-0, +1, ?]
 */
static int create_stat_mt(lua_State *L) {

    static luaL_Reg fns[] = {
        { "stop",          stat_stop },
        { "start",         stat_start },
        { "getdata",       stat_getdata },
        { NULL, NULL }
    };
    luaL_newmetatable(L, STAT_MT);
    add_watcher_mt(L);
    luaL_setfuncs(L, fns, 0);

    return 1;
}

/**
 * Create a new stat object. Arguments:
 *   1 - callback function.
 *   2 - path
 *   3 - interval
 *
 * @see watcher_new()
 *
 * [+1, -0, ?]
 */
static int stat_new(lua_State* L) {
    const char* path = luaL_checkstring(L, 2);
#if LUA_VERSION_NUM > 502
    ev_tstamp   interval = (int)luaL_optinteger(L, 3, 0);
#else
    ev_tstamp   interval = luaL_optint(L, 3, 0);
#endif
    ev_stat*    stat;

    stat = watcher_new(L, sizeof(ev_stat), STAT_MT);
    ev_stat_init(stat, &stat_cb, path, interval);
    return 1;
}

/**
 * @see watcher_cb()
 *
 * [+0, -0, m]
 */
static void stat_cb(struct ev_loop* loop, ev_stat* stat, int revents) {
    watcher_cb(loop, stat, revents);
}

/**
 * Stops the stat so it won't be called by the specified event loop.
 *
 * Usage:
 *     stat:stop(loop)
 *
 * [+0, -0, e]
 */
static int stat_stop(lua_State *L) {
    ev_stat*        stat  = check_stat(L, 1);
    struct ev_loop* loop = *check_loop_and_init(L, 2);

    loop_stop_watcher(L, 2, 1);
    ev_stat_stop(loop, stat);

    return 0;
}

/**
 * Starts the stat so it will be called by the specified event loop.
 *
 * Usage:
 *     stat:start(loop [, is_daemon])
 *
 * [+0, -0, e]
 */
static int stat_start(lua_State *L) {
    ev_stat*       stat = check_stat(L, 1);
    struct ev_loop* loop = *check_loop_and_init(L, 2);
    int is_daemon        = lua_toboolean(L, 3);

    ev_stat_start(loop, stat);
    loop_start_watcher(L, 2, 1, is_daemon);

    return 0;
}

#define set_attr(value)                         \
    lua_pushliteral(L, #value);                 \
    lua_pushinteger(L, stat->attr.st_##value);  \
    lua_settable(L, -3)

#define set_prev(value)                         \
    lua_pushliteral(L, #value);                 \
    lua_pushinteger(L, stat->prev.st_##value);  \
    lua_settable(L, -3)

/**
 * Returns a table with the following fields:
 * - path: the file system path that is being watched;
 * - interval: the specified interval;
 * - attr: the most-recently detected attributes of the file in a form
 *   of table with the following fields: dev, ino, mode, nlink, uid, gid,
 *   rdev, size, atime, mtime, ctime corresponding to struct stat members
 *   (st_dev, st_ino, etc.);
 * - prev: the previous attributes of the file with the same fields as
 *   attr fields.
 *
 * Usage:
 *     stat:getdata()
 *
 * [+1, -0, e]
 */
static int stat_getdata(lua_State *L) {
    ev_stat* stat = check_stat(L, 1);

    lua_newtable(L);

    lua_pushliteral(L, "path");
    lua_pushstring(L, stat->path);
    lua_settable(L, -3);

    lua_pushliteral(L, "interval");
    lua_pushinteger(L, stat->interval);
    lua_settable(L, -3);

    /* attr table */
    lua_pushliteral(L, "attr");
    lua_newtable(L);

    set_attr(dev);
    set_attr(ino);
    set_attr(mode);
    set_attr(nlink);
    set_attr(uid);
    set_attr(gid);
    set_attr(rdev);
    set_attr(size);
    set_attr(atime);
    set_attr(mtime);
    set_attr(ctime);

    lua_settable(L, -3);

    /* prev table */
    lua_pushliteral(L, "prev");
    lua_newtable(L);

    set_prev(dev);
    set_prev(ino);
    set_prev(mode);
    set_prev(nlink);
    set_prev(uid);
    set_prev(gid);
    set_prev(rdev);
    set_prev(size);
    set_prev(atime);
    set_prev(mtime);
    set_prev(ctime);

    lua_settable(L, -3);

    return 1;
}
