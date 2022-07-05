#include <fcntl.h> /* O_* */
#include <signal.h> /* sigset_t */
#include <spawn.h>
#include <string.h> /* strerror */
#include <sys/types.h> /* pid_t */
#include <unistd.h> /* _POSIX_PRIORITY_SCHEDULING */

#include <lua.h>
#include <lauxlib.h>
#include "compat-5.3.h"

#ifdef __APPLE__
#include <crt_externs.h>
#define environ (*_NSGetEnviron())
#else
extern char** environ;
#endif

static const char** l_posix_checkarraystrings(lua_State *L, int arg) {
	const char **ret;
	lua_Integer n, i;
	int t;
	int abs_arg = lua_absindex(L, arg);
	luaL_checktype(L, abs_arg, LUA_TTABLE);
	n = lua_rawlen(L, abs_arg);
	ret = lua_newuserdata(L, (n+1)*sizeof(char*));
	for (i=0; i<n; i++) {
		t = lua_rawgeti(L, abs_arg, i+1);
		if (t == LUA_TNIL)
			break;
		luaL_argcheck(L, t == LUA_TSTRING, arg, "expected array of strings");
		ret[i] = lua_tostring(L, -1);
		lua_pop(L, 1);
	}
	ret[i] = NULL;
	return ret;
}

static const char** l_posix_optarraystrings(lua_State *L, int n, const char** def) {
	return lua_isnoneornil(L, n) ? def : l_posix_checkarraystrings(L, n);
}

static int l_posix_spawn(lua_State *L) {
	int r;
	pid_t pid;
	const char *path = luaL_checkstring(L, 1);
	posix_spawn_file_actions_t *file_actions = luaL_testudata(L, 2, "posix_spawn_file_actions_t");
	posix_spawnattr_t *attr = luaL_testudata(L, 3, "posix_spawnattr_t");
	const char **argv, **envp;
	lua_settop(L, 5);
	argv = l_posix_checkarraystrings(L, 4);
	envp = l_posix_optarraystrings(L, 5, (const char**)environ);
	if (0 != (r = posix_spawn(&pid, path, file_actions, attr, (char*const*)argv, (char*const*)envp))) {
		lua_pushnil(L);
		lua_pushstring(L, strerror(r));
		lua_pushinteger(L, r);
		return 3;
	}
	lua_pushinteger(L, pid);
	return 1;
}

/* Almost same API as posix_spawn */
static int l_posix_spawnp(lua_State *L) {
	int r;
	pid_t pid;
	const char *file = luaL_checkstring(L, 1);
	posix_spawn_file_actions_t *file_actions = luaL_testudata(L, 2, "posix_spawn_file_actions_t");
	posix_spawnattr_t *attr = luaL_testudata(L, 3, "posix_spawnattr_t");
	const char **argv, **envp;
	lua_settop(L, 5);
	argv = l_posix_checkarraystrings(L, 4);
	envp = l_posix_optarraystrings(L, 5, (const char**)environ);
	if (0 != (r = posix_spawnp(&pid, file, file_actions, attr, (char*const*)argv, (char*const*)envp))) {
		lua_pushnil(L);
		lua_pushstring(L, strerror(r));
		lua_pushinteger(L, r);
		return 3;
	}
	lua_pushinteger(L, pid);
	return 1;
}

static int l_posix_spawnattr_init(lua_State *L) {
	int r;
	posix_spawnattr_t *attr = lua_newuserdata(L, sizeof(posix_spawnattr_t));
	luaL_setmetatable(L, "posix_spawnattr_t");
	if (0 != (r = posix_spawnattr_init(attr))) {
		lua_pushnil(L);
		lua_pushstring(L, strerror(r));
		lua_pushinteger(L, r);
		return 3;
	}
	return 1;
}

static int l_posix_spawnattr_destroy(lua_State *L) {
	int r;
	posix_spawnattr_t *attr = luaL_checkudata(L, 1, "posix_spawnattr_t");
	if (0 != (r = posix_spawnattr_destroy(attr))) {
		lua_pushnil(L);
		lua_pushstring(L, strerror(r));
		lua_pushinteger(L, r);
		return 3;
	}
	lua_pushboolean(L, 1);
	return 1;
}

static int l_posix_spawnattr_getsigdefault(lua_State *L) {
	int r;
	posix_spawnattr_t *attr = luaL_checkudata(L, 1, "posix_spawnattr_t");
	sigset_t *set = luaL_testudata(L, 2, "sigset_t");
	if (set) {
		lua_settop(L, 2);
	} else {
		lua_settop(L, 1);
		set = lua_newuserdata(L, sizeof(sigset_t));
		luaL_setmetatable(L, "sigset_t");
	}
	if (0 != (r = posix_spawnattr_getsigdefault(attr, set))) {
		lua_pushnil(L);
		lua_pushstring(L, strerror(r));
		lua_pushinteger(L, r);
		return 3;
	}
	return 1;
}

static int l_posix_spawnattr_setsigdefault(lua_State *L) {
	int r;
	posix_spawnattr_t *attr = luaL_checkudata(L, 1, "posix_spawnattr_t");
	sigset_t *set = luaL_checkudata(L, 2, "sigset_t");
	if (0 != (r = posix_spawnattr_setsigdefault(attr, set))) {
		lua_pushnil(L);
		lua_pushstring(L, strerror(r));
		lua_pushinteger(L, r);
		return 3;
	}
	lua_pushboolean(L, 1);
	return 1;
}

static int l_posix_spawnattr_getsigmask(lua_State *L) {
	int r;
	posix_spawnattr_t *attr = luaL_checkudata(L, 1, "posix_spawnattr_t");
	sigset_t *set = luaL_testudata(L, 2, "sigset_t");
	if (set) {
		lua_settop(L, 2);
	} else {
		lua_settop(L, 1);
		set = lua_newuserdata(L, sizeof(sigset_t));
		luaL_setmetatable(L, "sigset_t");
	}
	if (0 != (r = posix_spawnattr_getsigmask(attr, set))) {
		lua_pushnil(L);
		lua_pushstring(L, strerror(r));
		lua_pushinteger(L, r);
		return 3;
	}
	return 1;
}

static int l_posix_spawnattr_setsigmask(lua_State *L) {
	int r;
	posix_spawnattr_t *attr = luaL_checkudata(L, 1, "posix_spawnattr_t");
	sigset_t *set = luaL_checkudata(L, 2, "sigset_t");
	if (0 != (r = posix_spawnattr_setsigmask(attr, set))) {
		lua_pushnil(L);
		lua_pushstring(L, strerror(r));
		lua_pushinteger(L, r);
		return 3;
	}
	lua_pushboolean(L, 1);
	return 1;
}

static const struct { const char* flagname; int value; } supported_flags[] = {
	{ "resetids", POSIX_SPAWN_RESETIDS },
	{ "setpgroup", POSIX_SPAWN_SETPGROUP },
	{ "setsigdef", POSIX_SPAWN_SETSIGDEF },
	{ "setsigmask", POSIX_SPAWN_SETSIGMASK },
#ifdef POSIX_SPAWN_SETSID
	{ "setsid", POSIX_SPAWN_SETSID },
#endif
#if (defined _POSIX_PRIORITY_SCHEDULING) && _POSIX_PRIORITY_SCHEDULING != -1
	{ "setscheduler", POSIX_SPAWN_SETSCHEDULER },
	{ "setschedparam", POSIX_SPAWN_SETSCHEDPARAM },
#endif
#ifdef POSIX_SPAWN_USEVFORK
	{ "usevfork", POSIX_SPAWN_USEVFORK },
#endif
};
#define N_SUPPORTED_FLAGS (sizeof(supported_flags)/sizeof(supported_flags[0]))

static int l_posix_spawnattr_getflags(lua_State *L) {
	int r;
	size_t i;
	posix_spawnattr_t *attr = luaL_checkudata(L, 1, "posix_spawnattr_t");
	short int flags;
	if (0 != (r = posix_spawnattr_getflags(attr, &flags))) {
		lua_pushnil(L);
		lua_pushstring(L, strerror(r));
		lua_pushinteger(L, r);
		return 3;
	}
	lua_createtable(L, 0, N_SUPPORTED_FLAGS);
	for (i=0; i<N_SUPPORTED_FLAGS; i++) {
		lua_pushboolean(L, flags & supported_flags[i].value);
		lua_setfield(L, -2, supported_flags[i].flagname);
	}
	return 1;
}

static int l_posix_spawnattr_setflags(lua_State *L) {
	int r;
	size_t i;
	posix_spawnattr_t *attr = luaL_checkudata(L, 1, "posix_spawnattr_t");
	short int flags = 0;
	luaL_checktype(L, 2, LUA_TTABLE);
	for (i=0; i<N_SUPPORTED_FLAGS; i++) {
		lua_getfield(L, 2, supported_flags[i].flagname);
		if (lua_toboolean(L, -1)) flags |= supported_flags[i].value;
		lua_pop(L, 1);
	}
	if (0 != (r = posix_spawnattr_setflags(attr, flags))) {
		lua_pushnil(L);
		lua_pushstring(L, strerror(r));
		lua_pushinteger(L, r);
		return 3;
	}
	lua_pushboolean(L, 1);
	return 1;
}

static int l_posix_spawnattr_getpgroup(lua_State *L) {
	int r;
	posix_spawnattr_t *attr = luaL_checkudata(L, 1, "posix_spawnattr_t");
	pid_t pgroup;
	if (0 != (r = posix_spawnattr_getpgroup(attr, &pgroup))) {
		lua_pushnil(L);
		lua_pushstring(L, strerror(r));
		lua_pushinteger(L, r);
		return 3;
	}
	lua_pushinteger(L, pgroup);
	return 1;
}

static int l_posix_spawnattr_setpgroup(lua_State *L) {
	int r;
	posix_spawnattr_t *attr = luaL_checkudata(L, 1, "posix_spawnattr_t");
	pid_t pgroup = luaL_checkinteger(L, 2);
	if (0 != (r = posix_spawnattr_setpgroup(attr, pgroup))) {
		lua_pushnil(L);
		lua_pushstring(L, strerror(r));
		lua_pushinteger(L, r);
		return 3;
	}
	lua_pushboolean(L, 1);
	return 1;
}

#if (defined _POSIX_PRIORITY_SCHEDULING) && _POSIX_PRIORITY_SCHEDULING != -1
static int l_posix_spawnattr_getschedpolicy(lua_State *L) {
	int r;
	posix_spawnattr_t *attr = luaL_checkudata(L, 1, "posix_spawnattr_t");
	int schedpolicy;
	if (0 != (r = posix_spawnattr_getschedpolicy(attr, &schedpolicy))) {
		lua_pushnil(L);
		lua_pushstring(L, strerror(r));
		lua_pushinteger(L, r);
		return 3;
	}
	lua_pushinteger(L, schedpolicy);
	return 1;
}

static int l_posix_spawnattr_setschedpolicy(lua_State *L) {
	int r;
	posix_spawnattr_t *attr = luaL_checkudata(L, 1, "posix_spawnattr_t");
	int schedpolicy = luaL_checkinteger(L, 2);
	if (0 != (r = posix_spawnattr_setschedpolicy(attr, schedpolicy))) {
		lua_pushnil(L);
		lua_pushstring(L, strerror(r));
		lua_pushinteger(L, r);
		return 3;
	}
	lua_pushboolean(L, 1);
	return 1;
}

/*
static int l_posix_spawnattr_getschedparam(lua_State *L) {
	int r;
	posix_spawnattr_t *attr = luaL_checkudata(L, 1, "posix_spawnattr_t");
	struct schedparam;
	if (0 != (r = posix_spawnattr_getschedparam(attr, &schedparam))) {
		lua_pushnil(L);
		lua_pushstring(L, strerror(r));
		lua_pushinteger(L, r);
		return 3;
	}

	return 1;
}

static int l_posix_spawnattr_setschedparam(lua_State *L) {
	int r;
	posix_spawnattr_t *attr = luaL_checkudata(L, 1, "posix_spawnattr_t");
	struct schedparam = (L, 2);
	if (0 != (r = posix_spawnattr_setschedparam(attr, schedparam))) {
		lua_pushnil(L);
		lua_pushstring(L, strerror(r));
		lua_pushinteger(L, r);
		return 3;
	}
	lua_pushboolean(L, 1);
}
*/
#endif

static int l_posix_spawn_file_actions_init(lua_State *L) {
	int r;
	posix_spawn_file_actions_t *file_actions = lua_newuserdata(L, sizeof(posix_spawn_file_actions_t));
	luaL_setmetatable(L, "posix_spawn_file_actions_t");
	if (0 != (r = posix_spawn_file_actions_init(file_actions))) {
		lua_pushnil(L);
		lua_pushstring(L, strerror(r));
		lua_pushinteger(L, r);
		return 3;
	}
	return 1;
}

static int l_posix_spawn_file_actions_destroy(lua_State *L) {
	int r;
	posix_spawn_file_actions_t *file_actions = luaL_checkudata(L, 1, "posix_spawn_file_actions_t");
	if (0 != (r = posix_spawn_file_actions_destroy(file_actions))) {
		lua_pushnil(L);
		lua_pushstring(L, strerror(r));
		lua_pushinteger(L, r);
		return 3;
	}
	lua_pushboolean(L, 1);
	return 1;
}

static int l_posix_spawn_file_actions_addopen(lua_State *L) {
	int r;
	posix_spawn_file_actions_t *file_actions = luaL_checkudata(L, 1, "posix_spawn_file_actions_t");
	int fd = luaL_checkinteger(L, 2);
	const char *path = luaL_checkstring(L, 3);
	int oflag;
	mode_t mode;
	switch (lua_type(L, 4)) {
	case LUA_TNUMBER:
		oflag = lua_tointeger(L, 4);
		break;
	case LUA_TTABLE:
		oflag = 0;

		lua_getfield(L, 4, "rdwr");
		if (lua_toboolean(L, -1)) oflag |= O_RDWR;
		lua_getfield(L, 4, "wronly");
		if (lua_toboolean(L, -1)) {
			luaL_argcheck(L, !oflag, 4, "must specify one of rdonly, wronly or rdwr");
			oflag |= O_WRONLY;
		}
		lua_getfield(L, 4, "rdonly");
		if (lua_toboolean(L, -1)) {
			luaL_argcheck(L, !oflag, 4, "must specify one of rdonly, wronly or rdwr");
			oflag |= O_RDONLY;
		} else if(!oflag) {
			return luaL_argerror(L, 4, "must specify one of rdonly, wronly or rdwr");
		}
		lua_pop(L, 3);

		/* defined in posix */
		lua_getfield(L, 4, "append");
		if (lua_toboolean(L, -1)) oflag |= O_APPEND;
		lua_getfield(L, 4, "creat");
		if (lua_toboolean(L, -1)) oflag |= O_CREAT;
		lua_getfield(L, 4, "excl");
		if (lua_toboolean(L, -1)) oflag |= O_EXCL;
		lua_getfield(L, 4, "noctty");
		if (lua_toboolean(L, -1)) oflag |= O_NOCTTY;
		lua_getfield(L, 4, "nonblock");
		if (lua_toboolean(L, -1)) oflag |= O_NONBLOCK;
		lua_getfield(L, 4, "trunc");
		if (lua_toboolean(L, -1)) oflag |= O_TRUNC;
		lua_pop(L, 6);

		/* defined in posix, but optional */
#ifdef O_SYNC
		lua_getfield(L, 4, "sync");
		if (lua_toboolean(L, -1)) oflag |= O_SYNC;
		lua_pop(L, 1);
#endif
#ifdef O_DSYNC
		lua_getfield(L, 4, "dsync");
		if (lua_toboolean(L, -1)) oflag |= O_DSYNC;
		lua_pop(L, 1);
#endif
#ifdef O_RSYNC
		lua_getfield(L, 4, "rsync");
		if (lua_toboolean(L, -1)) oflag |= O_RSYNC;
		lua_pop(L, 1);
#endif

#ifdef O_ASYNC
		lua_getfield(L, 4, "async");
		if (lua_toboolean(L, -1)) oflag |= O_ASYNC;
		lua_pop(L, 1);
#endif
#ifdef O_CLOEXEC
		lua_getfield(L, 4, "cloexec");
		if (lua_toboolean(L, -1)) oflag |= O_CLOEXEC;
		lua_pop(L, 1);
#endif
#ifdef O_DIRECT
		lua_getfield(L, 4, "direct");
		if (lua_toboolean(L, -1)) oflag |= O_DIRECT;
		lua_pop(L, 1);
#endif
#ifdef O_DIRECTORY
		lua_getfield(L, 4, "directory");
		if (lua_toboolean(L, -1)) oflag |= O_DIRECTORY;
		lua_pop(L, 1);
#endif
#ifdef O_LARGEFILE
		lua_getfield(L, 4, "largefile");
		if (lua_toboolean(L, -1)) oflag |= O_LARGEFILE;
		lua_pop(L, 1);
#endif
#ifdef O_NDELAY
		lua_getfield(L, 4, "ndelay");
		if (lua_toboolean(L, -1)) oflag |= O_NDELAY;
		lua_pop(L, 1);
#endif
#ifdef O_NOATIME
		lua_getfield(L, 4, "noatime");
		if (lua_toboolean(L, -1)) oflag |= O_NOATIME;
		lua_pop(L, 1);
#endif
#ifdef O_NOFOLLOW
		lua_getfield(L, 4, "nofollow");
		if (lua_toboolean(L, -1)) oflag |= O_NOFOLLOW;
		lua_pop(L, 1);
#endif
#ifdef O_PATH
		lua_getfield(L, 4, "path");
		if (lua_toboolean(L, -1)) oflag |= O_PATH;
		lua_pop(L, 1);
#endif
#ifdef O_TMPFILE
		lua_getfield(L, 4, "tmpfile");
		if (lua_toboolean(L, -1)) oflag |= O_TMPFILE;
		lua_pop(L, 1);
#endif
		break;
	default:
		return luaL_argerror(L, 4, "expected integer or set of options");
	}
	mode = luaL_optinteger(L, 5, 0);
	if (0 != (r = posix_spawn_file_actions_addopen(file_actions, fd, path, oflag, mode))) {
		lua_pushnil(L);
		lua_pushstring(L, strerror(r));
		lua_pushinteger(L, r);
		return 3;
	}
	lua_pushboolean(L, 1);
	return 1;
}

static int l_posix_spawn_file_actions_addclose(lua_State *L) {
	int r;
	posix_spawn_file_actions_t *file_actions = luaL_checkudata(L, 1, "posix_spawn_file_actions_t");
	int fd = luaL_checkinteger(L, 2);
	if (0 != (r = posix_spawn_file_actions_addclose(file_actions, fd))) {
		lua_pushnil(L);
		lua_pushstring(L, strerror(r));
		lua_pushinteger(L, r);
		return 3;
	}
	lua_pushboolean(L, 1);
	return 1;
}

static int l_posix_spawn_file_actions_adddup2(lua_State *L) {
	int r;
	posix_spawn_file_actions_t *file_actions = luaL_checkudata(L, 1, "posix_spawn_file_actions_t");
	int fd = luaL_checkinteger(L, 2);
	int newfd = luaL_checkinteger(L, 3);
	if (0 != (r = posix_spawn_file_actions_adddup2(file_actions, fd, newfd))) {
		lua_pushnil(L);
		lua_pushstring(L, strerror(r));
		lua_pushinteger(L, r);
		return 3;
	}
	lua_pushboolean(L, 1);
	return 1;
}

static const luaL_Reg spawnattr_methods[] = {
	{ "getsigdefault", l_posix_spawnattr_getsigdefault },
	{ "setsigdefault", l_posix_spawnattr_setsigdefault },
	{ "getsigmask", l_posix_spawnattr_getsigmask },
	{ "setsigmask", l_posix_spawnattr_setsigmask },
	{ "getflags", l_posix_spawnattr_getflags },
	{ "setflags", l_posix_spawnattr_setflags },
	{ "getpgroup", l_posix_spawnattr_getpgroup },
	{ "setpgroup", l_posix_spawnattr_setpgroup },
#if (defined _POSIX_PRIORITY_SCHEDULING) && _POSIX_PRIORITY_SCHEDULING != -1
	{ "getschedpolicy", l_posix_spawnattr_getschedpolicy },
	{ "setschedpolicy", l_posix_spawnattr_setschedpolicy },
	/* { "getschedparam", l_posix_spawnattr_getschedparam }, */
	/* { "setschedparam", l_posix_spawnattr_setschedparam }, */
#endif
	{ NULL, NULL }
};

static const luaL_Reg spawn_file_actions_methods[] = {
	{ "addopen", l_posix_spawn_file_actions_addopen },
	{ "addclose", l_posix_spawn_file_actions_addclose },
	{ "adddup2", l_posix_spawn_file_actions_adddup2 },
	{ NULL, NULL }
};

static const luaL_Reg lib[] = {
	{ "spawn", l_posix_spawn },
	{ "spawnp", l_posix_spawnp },
	{ "new_attr", l_posix_spawnattr_init },
	{ "new_file_actions", l_posix_spawn_file_actions_init },
	{ NULL, NULL }
};

int luaopen_spawn_posix(lua_State *L) {
	luaL_newmetatable(L, "posix_spawnattr_t");
	lua_pushcfunction(L, l_posix_spawnattr_destroy);
	lua_setfield(L, -2, "__gc");
	luaL_newlib(L, spawnattr_methods);
	lua_setfield(L, -2, "__index");
	luaL_newmetatable(L, "posix_spawn_file_actions_t");
	lua_pushcfunction(L, l_posix_spawn_file_actions_destroy);
	lua_setfield(L, -2, "__gc");
	luaL_newlib(L, spawn_file_actions_methods);
	lua_setfield(L, -2, "__index");
	lua_pop(L, 2);

	luaL_newlib(L, lib);
	return 1;
}
