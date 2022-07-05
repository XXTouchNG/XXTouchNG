#include <assert.h>
#include <ev.h>
#include <lauxlib.h>
#include <lua.h>
#include <signal.h>

#include "lua_ev.h"

/* We make everything static, so we just include all *.c files in a
 * single compilation unit. */
#include "obj_lua_ev.c"
#include "loop_lua_ev.c"
#include "watcher_lua_ev.c"
#include "io_lua_ev.c"
#include "timer_lua_ev.c"
#include "signal_lua_ev.c"
#include "idle_lua_ev.c"
#include "async_lua_ev.c"
#include "child_lua_ev.c"
#include "stat_lua_ev.c"

static const luaL_Reg R[] = {
    {"version", version},
    {"object_count", obj_count},
    {NULL, NULL},
};


/**
 * Entry point into the 'ev' lua library.  Validates that the
 * dynamically linked libev version matches, creates the object
 * registry, and creates the table returned by require().
 */
LUALIB_API int luaopen_ev(lua_State *L) {

    assert(ev_version_major() == EV_VERSION_MAJOR &&
           ev_version_minor() >= EV_VERSION_MINOR);

    create_obj_registry(L);

#if LUA_VERSION_NUM > 501
    luaL_newlib(L, R);
#else
    luaL_register(L, "ev", R);
#endif

    luaopen_ev_loop(L);
    lua_setfield(L, -2, "Loop");

    luaopen_ev_timer(L);
    lua_setfield(L, -2, "Timer");

    luaopen_ev_io(L);
    lua_setfield(L, -2, "IO");

    luaopen_ev_async(L);
    lua_setfield(L, -2, "Async");

    luaopen_ev_signal(L);
    lua_setfield(L, -2, "Signal");

    luaopen_ev_idle(L);
    lua_setfield(L, -2, "Idle");

    luaopen_ev_child(L);
    lua_setfield(L, -2, "Child");

    luaopen_ev_stat(L);
    lua_setfield(L, -2, "Stat");

#define EV_SETCONST(state, prefix, C) \
    lua_pushnumber(L, prefix ## C); \
    lua_setfield(L, -2, #C)

    EV_SETCONST(L, EV_, CHILD);
    EV_SETCONST(L, EV_, IDLE);
    EV_SETCONST(L, EV_, ASYNC);
    EV_SETCONST(L, EV_, MINPRI);
    EV_SETCONST(L, EV_, MAXPRI);
    EV_SETCONST(L, EV_, READ);
    EV_SETCONST(L, EV_, SIGNAL);
    EV_SETCONST(L, EV_, STAT);
    EV_SETCONST(L, EV_, TIMEOUT);
    EV_SETCONST(L, EV_, WRITE);

    EV_SETCONST(L, , SIGABRT);
    EV_SETCONST(L, , SIGALRM);
    EV_SETCONST(L, , SIGBUS);
    EV_SETCONST(L, , SIGCHLD);
    EV_SETCONST(L, , SIGCONT);
    EV_SETCONST(L, , SIGFPE);
    EV_SETCONST(L, , SIGHUP);
    EV_SETCONST(L, , SIGINT);
    EV_SETCONST(L, , SIGIO);
    EV_SETCONST(L, , SIGIOT);
    EV_SETCONST(L, , SIGKILL);
    EV_SETCONST(L, , SIGPIPE);
#ifdef SIGPOLL
    EV_SETCONST(L, , SIGPOLL);
#endif
    EV_SETCONST(L, , SIGPROF);
#ifdef SIGPWR
    EV_SETCONST(L, , SIGPWR);
#endif
    EV_SETCONST(L, , SIGQUIT);
    EV_SETCONST(L, , SIGSEGV);
#ifdef SIGSTKFLT
    EV_SETCONST(L, , SIGSTKFLT);
#endif
    EV_SETCONST(L, , SIGSYS);
    EV_SETCONST(L, , SIGTERM);
    EV_SETCONST(L, , SIGTRAP);
    EV_SETCONST(L, , SIGTSTP);
    EV_SETCONST(L, , SIGTTIN);
    EV_SETCONST(L, , SIGTTOU);
    EV_SETCONST(L, , SIGURG);
    EV_SETCONST(L, , SIGUSR1);
    EV_SETCONST(L, , SIGUSR2);
    EV_SETCONST(L, , SIGVTALRM);
    EV_SETCONST(L, , SIGWINCH);
    EV_SETCONST(L, , SIGXCPU);
    EV_SETCONST(L, , SIGXFSZ);

#undef EV_SETCONST

    return 1;
}

/**
 * Push the major and minor version of libev onto the stack.
 *
 * [+2, -0, -]
 */
static int version(lua_State *L) {
    lua_pushnumber(L, ev_version_major());
    lua_pushnumber(L, ev_version_minor());
    return 2;
}

/**
 * Taken from lua.c out of the lua source distribution.  Use this
 * function when doing lua_pcall().
 */
static int traceback(lua_State *L) {
    if ( !lua_isstring(L, 1) ) return 1;

    lua_getglobal(L, "debug");
    if ( !lua_istable(L, -1) ) {
        lua_pop(L, 1);
        return 1;
    }

    lua_getfield(L, -1, "traceback");
    if ( !lua_isfunction(L, -1) ) {
        lua_pop(L, 2);
        return 1;
    }

    lua_pushvalue(L, 1);    /* pass error message */
    lua_pushinteger(L, 2);  /* skip this function and traceback */
    lua_call(L, 2, 1);      /* call debug.traceback */
    return 1;
}
