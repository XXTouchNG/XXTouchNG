#ifndef _WIN32
#include <sys/wait.h>
#endif

#if LUA_VERSION_NUM > 502
#define luaL_checkbool(L, i) (lua_isboolean(L, i) ? lua_toboolean(L, i) : (int)luaL_checkinteger(L, i))
#else
#define luaL_checkbool(L, i) (lua_isboolean(L, i) ? lua_toboolean(L, i) : luaL_checkint(L, i))
#endif

/**
 * Create a table for ev.CHILD that gives access to the constructor for
 * child objects.
 *
 * [-0, +1, ?]
 */
static int luaopen_ev_child(lua_State *L) {
    lua_pop(L, create_child_mt(L));

    lua_createtable(L, 0, 1);

    lua_pushcfunction(L, child_new);
    lua_setfield(L, -2, "new");

    return 1;
}

/**
 * Create the child metatable in the registry.
 *
 * [-0, +1, ?]
 */
static int create_child_mt(lua_State *L) {
    static luaL_Reg fns[] = {
        { "stop",          child_stop },
        { "start",         child_start },
        { "getpid" ,       child_getpid },
        { "getrpid" ,      child_getrpid },
        { "getstatus" ,    child_getstatus },
        { NULL, NULL }
    };
    luaL_newmetatable(L, CHILD_MT);
    add_watcher_mt(L);
    luaL_setfuncs(L, fns, 0);

    return 1;
}

/**
 * Create a new child object.  Arguments:
 *   1 - callback function.
 *   2 - pid number (0 for any pid)
 *   3 - trace (either false - only activate the watcher when the process
 *       terminates or true - additionally activate the watcher when the
 *       process is stopped or continued).
 *
 * @see watcher_new()
 *
 * [+1, -0, ?]
 */
static int child_new(lua_State* L) {
#if LUA_VERSION_NUM > 502
    int         pid = (int)luaL_checkinteger(L, 2);
#else
    int         pid = luaL_checkint(L, 2);
#endif
    int         trace = luaL_checkbool(L, 3);
    ev_child*   child;

    child = watcher_new(L, sizeof(ev_child), CHILD_MT);
    ev_child_init(child, &child_cb, pid, trace);
    return 1;
}

/**
 * @see watcher_cb()
 *
 * [+0, -0, m]
 */
static void child_cb(struct ev_loop* loop, ev_child* child, int revents) {
    watcher_cb(loop, child, revents);
}

/**
 * Stops the child so it won't be called by the specified event loop.
 *
 * Usage:
 *     child:stop(loop)
 *
 * [+0, -0, e]
 */
static int child_stop(lua_State *L) {
    ev_child*       child  = check_child(L, 1);
    struct ev_loop* loop = *check_loop_and_init(L, 2);

    loop_stop_watcher(L, 2, 1);
    ev_child_stop(loop, child);

    return 0;
}

/**
 * Starts the child so it will be called by the specified event loop.
 *
 * Usage:
 *     child:start(loop [, is_daemon])
 *
 * [+0, -0, e]
 */
static int child_start(lua_State *L) {
    ev_child*       child = check_child(L, 1);
    struct ev_loop* loop = *check_loop_and_init(L, 2);
    int is_daemon        = lua_toboolean(L, 3);

    ev_child_start(loop, child);
    loop_start_watcher(L, 2, 1, is_daemon);

    return 0;
}

/**
 * Returns the child pid (the process id this watcher watches out for, or 0,
 * meaning any process id).
 * Usage:
 *     child:getpid()
 *
 * [+1, -0, e]
 */
static int child_getpid(lua_State *L) {
    ev_child*       child  = check_child(L, 1);

    lua_pushinteger (L, child->pid);

    return 1;
}

/**
 * Returns the child rpid (the process id that detected a status change).
 * Usage:
 *     child:getrpid()
 *
 * [+1, -0, e]
 */
static int child_getrpid(lua_State *L) {
    ev_child*       child  = check_child(L, 1);

    lua_pushinteger (L, child->rpid);

    return 1;
}

static void populate_child_status_table(ev_child *child, lua_State *L) {
    int             exited, stopped, signaled;

    exited = WIFEXITED(child->rstatus);
    stopped = WIFSTOPPED(child->rstatus);
    signaled = WIFSIGNALED(child->rstatus);

    lua_pushstring(L, "status");
    lua_pushinteger(L, child->rstatus);
    lua_settable(L, -3);

    lua_pushstring(L, "exited");
    lua_pushboolean(L, exited);
    lua_settable(L, -3);

    lua_pushstring(L, "stopped");
    lua_pushboolean(L, stopped);
    lua_settable(L, -3);

    lua_pushstring(L, "signaled");
    lua_pushboolean(L, signaled);
    lua_settable(L, -3);

    if (exited) {
        lua_pushstring(L, "exit_status");
        lua_pushinteger(L, WEXITSTATUS(child->rstatus));
        lua_settable(L, -3);
    }

    if (stopped) {
        lua_pushstring(L, "stop_signal");
        lua_pushinteger(L, WSTOPSIG(child->rstatus));
        lua_settable(L, -3);
    }

    if (signaled) {
        lua_pushstring(L, "term_signal");
        lua_pushinteger(L, WTERMSIG(child->rstatus));
        lua_settable(L, -3);
    }
}

/**
 * Returns the process exit/trace status caused by "rpid" (see your systems
 * "waitpid" and "sys/wait.h" for details).
 * Usage:
 *     child:getstatus()
 *
 * It returns the table with the following fields:
 * - exited: true if status was returned for a child process that terminated
 *   normally;
 * - stopped: true if status was returned for a child process that is currently
 *   stopped;
 * - signaled: true if status was returned for a child process that terminated
 *   due to receipt of a signal that was not caught;
 * - exit_status: (only if exited == true) the low-order 8 bits of the status
 *   argument that the child process passed to _exit() or exit(), or the value
 *   the child process returned from main();
 * - stop_signal: (only if stopped == true) the number of the signal that
 *   caused the child process to stop;
 * - term_signal: (only if signaled == true) the number of the signal that 
 *   caused the termination of the child process.
 *
 * [+1, -0, e]
 */
static int child_getstatus(lua_State *L) {
    ev_child*       child  = check_child(L, 1);

    lua_newtable(L);
#ifndef _WIN32
    populate_child_status_table(child, L);
#endif

    return 1;
}
