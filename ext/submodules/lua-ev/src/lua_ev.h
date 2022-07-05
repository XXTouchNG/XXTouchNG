/**
 * This is a private header file.  If you use it outside of this
 * package, then you will be surprised by any changes made.
 *
 * Documentation for functions declared here is with the function
 * implementation.
 */

/**
 * Compatibility defines
 */

#if EV_VERSION_MAJOR < 3 || (EV_VERSION_MAJOR == 3 && EV_VERSION_MINOR < 7)
#  warning lua-ev requires version 3.7 or newer of libev
#endif

#if LUA_VERSION_NUM <= 501

/** Backwards compatibility shims: */
#define lua_absindex(L, i)                              \
    ((i) > 0 || (i) <= LUA_REGISTRYINDEX ?              \
     (i) : lua_gettop(L) + (i) + 1)

#define lua_setuservalue(L, i) lua_setfenv((L), (i))

#define lua_getuservalue(L, i) lua_getfenv((L), (i))

/* NOTE: this only works if nups == 0! */
#define luaL_setfuncs(L, fns, nups) luaL_register((L), NULL, (fns))

#endif

/**
 * Define the names used for the metatables.
 */
#define LOOP_MT    "ev{loop}"
#define IO_MT      "ev{io}"
#define ASYNC_MT   "ev{async}"
#define TIMER_MT   "ev{timer}"
#define SIGNAL_MT  "ev{signal}"
#define IDLE_MT    "ev{idle}"
#define CHILD_MT   "ev{child}"
#define STAT_MT    "ev{stat}"

/**
 * Special token to represent the uninitialized default loop.  This is
 * so we can defer initializing the default loop for as long as
 * possible.
 */
#define UNINITIALIZED_DEFAULT_LOOP (struct ev_loop*)1

/**
 * The location in the fenv of the watcher that contains the callback
 * function.
 */
#define WATCHER_FN 1

/**
 * The location in the fenv of the shadow table.
 */
#define WATCHER_SHADOW 2

/**
 * Various "check" functions simply call luaL_checkudata() and do the
 * appropriate casting, with the exception of check_watcher which is
 * implemented as a C function.
 */

/**
 * If there is any chance that the loop is not initialized yet, then
 * please use check_loop_and_init() instead!  Also note that the
 * loop userdata is a pointer, so don't forget to de-reference the
 * result.
 */
#define check_loop(L, narg)                                      \
    ((struct ev_loop**)    luaL_checkudata((L), (narg), LOOP_MT))

#define check_timer(L, narg)                                     \
    ((struct ev_timer*)    luaL_checkudata((L), (narg), TIMER_MT))

#define check_io(L, narg)                                        \
    ((struct ev_io*)       luaL_checkudata((L), (narg), IO_MT))

#define check_async(L, narg)                                        \
    ((struct ev_async*)    luaL_checkudata((L), (narg), ASYNC_MT))

#define check_signal(L, narg)                                   \
    ((struct ev_signal*)   luaL_checkudata((L), (narg), SIGNAL_MT))

#define check_idle(L, narg)                                      \
    ((struct ev_idle*)     luaL_checkudata((L), (narg), IDLE_MT))

#define check_child(L, narg)                                      \
    ((struct ev_child*)     luaL_checkudata((L), (narg), CHILD_MT))

#define check_stat(L, narg)                                      \
    ((struct ev_stat*)     luaL_checkudata((L), (narg), STAT_MT))


/**
 * Generic functions:
 */
static int               version(lua_State *L);
static int               traceback(lua_State *L);

/**
 * Loop functions:
 */
static int               luaopen_ev_loop(lua_State *L);
static int               create_loop_mt(lua_State *L);
static struct ev_loop**  loop_alloc(lua_State *L);
static struct ev_loop**  check_loop_and_init(lua_State *L, int loop_i);
static int               loop_new(lua_State *L);
static int               loop_delete(lua_State *L);
static void              loop_start_watcher(lua_State* L, int loop_i, int watcher_i, int is_daemon);
static void              loop_stop_watcher(lua_State* L, int loop_i, int watcher_i);
static int               loop_is_default(lua_State *L);
static int               loop_iteration(lua_State *L);
static int               loop_depth(lua_State *L);
static int               loop_now(lua_State *L);
static int               loop_update_now(lua_State *L);
static int               loop_loop(lua_State *L);
static int               loop_unloop(lua_State *L);
static int               loop_backend(lua_State *L);
static int               loop_fork(lua_State *L);

/**
 * Object functions:
 */
static void              create_obj_registry(lua_State *L);
static int               obj_count(lua_State *L);
static void*             obj_new(lua_State* L, size_t size, const char* tname);
static int               obj_newindex(lua_State *L);
static int               obj_index(lua_State *L);

static int               push_objs(lua_State* L, void** objs);

/**
 * Watcher functions:
 */
static int                add_watcher_mt(lua_State *L);
static int                watcher_is_active(lua_State *L);
static int                watcher_is_pending(lua_State *L);
static int                watcher_clear_pending(lua_State *L);
static void*              watcher_new(lua_State* L, size_t size, const char* lua_type);
static int                watcher_callback(lua_State *L);
static int                watcher_priority(lua_State *L);
static void               watcher_cb(struct ev_loop *loop, void *watcher, int revents);
static struct ev_watcher* check_watcher(lua_State *L, int watcher_i);

/**
 * Timer functions:
 */
static int               luaopen_ev_timer(lua_State *L);
static int               create_timer_mt(lua_State *L);
static int               timer_new(lua_State* L);
static void              timer_cb(struct ev_loop* loop, ev_timer* timer, int revents);
static int               timer_again(lua_State *L);
static int               timer_stop(lua_State *L);
static int               timer_start(lua_State *L);
static int               timer_clear_pending(lua_State *L);

/**
 * IO functions:
 */
static int               luaopen_ev_io(lua_State *L);
static int               create_io_mt(lua_State *L);
static int               io_new(lua_State* L);
static void              io_cb(struct ev_loop* loop, ev_io* io, int revents);
static int               io_stop(lua_State *L);
static int               io_start(lua_State *L);
static int               io_getfd(lua_State *L);

/**
 * Async functions:
 */
static int               luaopen_ev_async(lua_State *L);
static int               create_async_mt(lua_State *L);
static int               async_new(lua_State* L);
static void              async_cb(struct ev_loop* loop, ev_async* async, int revents);
static int               async_send(lua_State *L);
static int               async_stop(lua_State *L);
static int               async_start(lua_State *L);

/**
 * Signal functions:
 */
static int               luaopen_ev_signal(lua_State *L);
static int               create_signal_mt(lua_State *L);
static int               signal_new(lua_State* L);
static void              signal_cb(struct ev_loop* loop, ev_signal* sig, int revents);
static int               signal_stop(lua_State *L);
static int               signal_start(lua_State *L);

/**
 * Idle functions:
 */
static int               luaopen_ev_idle(lua_State *L);
static int               create_idle_mt(lua_State *L);
static int               idle_new(lua_State* L);
static void              idle_cb(struct ev_loop* loop, ev_idle* idle, int revents);
static int               idle_stop(lua_State *L);
static int               idle_start(lua_State *L);

/**
 * Child functions:
 */
static int               luaopen_ev_child(lua_State *L);
static int               create_child_mt(lua_State *L);
static int               child_new(lua_State* L);
static void              child_cb(struct ev_loop* loop, ev_child* sig, int revents);
static int               child_stop(lua_State *L);
static int               child_start(lua_State *L);
static int               child_getpid(lua_State *L);
static int               child_getrpid(lua_State *L);
static int               child_getstatus(lua_State *L);

/**
 * Stat functions:
 */
static int               luaopen_ev_stat(lua_State *L);
static int               create_stat_mt(lua_State *L);
static int               stat_new(lua_State* L);
static void              stat_cb(struct ev_loop* loop, ev_stat* sig, int revents);
static int               stat_stop(lua_State *L);
static int               stat_start(lua_State *L);
static int               stat_start(lua_State *L);
static int               stat_getdata(lua_State *L);
