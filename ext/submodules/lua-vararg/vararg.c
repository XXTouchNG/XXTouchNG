/*
'vararg' is a Lua library for manipulation of variable arguements (vararg) of
functions. These functions basically allow you to do things with vararg that
cannot be efficiently done in pure Lua but can be easily done through the C API.

Actually, the main motivation for this library was the 'pack' function, which
is an elegant alternative for the possible new standard function 'table.pack'
and the praised 'apairs'. Also 'pack' allows an interesting implementaiton of
tuples in pure Lua.

p = pack(...)
  p()              --> ...
  p("#")           --> select("#", ...)
  p(i)             --> (select(i, ...))
  p(i, j)          --> unpack({...}, i, j)
  for i,v in p do  --> for i,v in apairs(...) do
range(i, j, ...)   --> unpack({...}, i, j)
remove(i, ...)     --> t={...} table.remove(t,i) return unpack(t,1,select("#",...)-1)
insert(v, i, ...)  --> t={...} table.insert(t,i,v) return unpack(t,1,select("#",...)+1)
replace(v, i, ...) --> t={...} t[i]=v return unpack(t,1,select("#",...))
append(v, ...)     --> c=select("#",...)+1 return unpack({[c]=val,...},1,c)
map(f, ...)        --> t={} n=select("#",...) for i=1,n do t[i]=f((select(i,...))) end return unpack(t,1,n)
concat(f1,f2,...)  --> return all the values returned by functions 'f1,f2,...'
count(...)         --> select("#", ...)
at(i, ...)         --> if select("#", ...) >= i then rutrn (select(i, ...)) end
*/

#define LUA_VALIBNAME	"vararg"

#include "lua.h"
#include "lauxlib.h"

#if LUA_VERSION_NUM >= 503 /* Lua 5.3 */

#ifndef luaL_checkint
#define luaL_checkint luaL_checkinteger
#endif

#ifndef luaL_optint
#define luaL_optint luaL_optinteger
#endif

#endif

#if LUA_VERSION_NUM >= 502

#ifndef luaL_register

static void luaL_register (lua_State *L, const char *libname, const luaL_Reg *l){
  if(libname) lua_newtable(L);
  luaL_setfuncs(L, l, 0);
}

#endif

#endif

static int _optindex(lua_State *L, int arg, int top, int def) {
	int idx = (def ? luaL_optint(L, arg, def) : luaL_checkint(L, arg));
	idx = (idx>=0 ? idx : top+idx+1);  /* convert a stack index to positive */
	if (idx<=0) luaL_argerror(L, arg, "index out of bounds");
	return idx;
}

static int luaVA_tuple(lua_State *L) {
	int n = lua_tointeger(L, lua_upvalueindex(1));  /* number of packed values */
	int type = lua_type(L, 1);
	if (type == LUA_TNIL) {
		int i = lua_tointeger(L, 2);
		if(++i > 0 && i <= n) {
			lua_pushinteger(L, i);
			lua_pushvalue(L, lua_upvalueindex(i+1));
			return 2;
		}
	} else if (type == LUA_TSTRING && *lua_tostring(L, 1) == '#') {
		lua_pushinteger(L, n);
		return 1;
	} else {
		int i = 1, e = n;
		if (lua_gettop(L)) {
			i = _optindex(L, 1, n, 0);
			e = _optindex(L, 2, n, i);
			n = e-i+1;  /* number of results */
			luaL_checkstack(L, n, "too many results to unpack");
		}
		for(; i<=e; ++i) lua_pushvalue(L, lua_upvalueindex(i+1));
		return n;
	}
	return 0;
}

static int luaVA_pack(lua_State *L) {
	int top = lua_gettop(L);
	if (top >= 255) luaL_error(L, "too many values to pack");
	lua_pushinteger(L, top);
	lua_insert(L, 1);
	lua_pushcclosure(L, luaVA_tuple, top+1);
	return 1;
}

static int luaVA_range(lua_State *L) {
	int n, i, e;
	n = lua_gettop(L);
	i = _optindex(L, 1, n-2, 0)+2;
	e = _optindex(L, 2, n-2, 0)+2;
	if (i > e) return 0;  /* empty range */
	if (!lua_checkstack(L, e-n))  /* space for extra nil's */
		luaL_error(L, "range is too big");
	lua_settop(L, e);
	return e-i+1;
}

static int luaVA_at(lua_State *L) {
	int n, i;
	n = lua_gettop(L);
	i = _optindex(L, 1, n-1, 0)+1;
	if (i > n) return 0;  /* no value */
	lua_settop(L, i);
	return 1;
}

static int luaVA_count(lua_State *L) {
	int n = lua_gettop(L);
	lua_settop(L, 0);
	lua_pushinteger(L, n);
	return 1;
}

static int luaVA_insert(lua_State *L) {
	int i, n;
	n = lua_gettop(L);
	i = _optindex(L, 2, n-2, 0)+2;
	if (i > n) {
		if (!lua_checkstack(L, i-n))  /* space for extra nil's */
			luaL_error(L, "index is too big");
		lua_settop(L, i-1);
		lua_pushvalue(L, 1);
		return i-2;
	}
	lua_pushvalue(L, 1);
	lua_insert(L, i);
	return n-1;
}

static int luaVA_remove(lua_State *L) {
	int i, n;
	n = lua_gettop(L);
	i = _optindex(L, 1, n-1, 0)+1;
	if (i <= n) {
		lua_remove(L, i);
		--n;
	}
	return n-1;
}

static int luaVA_replace(lua_State *L) {
	int i, n;
	n = lua_gettop(L);
	i = _optindex(L, 2, n-2, 0)+2;
	if (i > n) {
		if (!lua_checkstack(L, i-n))  /* space for extra nil's */
			luaL_error(L, "index is too big");
		lua_settop(L, i-1);
		lua_pushvalue(L, 1);
		return i-2;
	}
	lua_pushvalue(L, 1);
	lua_replace(L, i);
	return n-2;
}

static int luaVA_append(lua_State *L) {
	lua_pushvalue(L, 1);
	return lua_gettop(L)-1;
}

static int luaVA_map(lua_State *L) {
	int top = lua_gettop(L);
	int i;
	luaL_checkany(L, 1);
	for(i=2; i<=top; ++i) {
		lua_pushvalue(L, 1);
		lua_pushvalue(L, i);
		lua_call(L, 1, 1);
		lua_replace(L, i); /* to avoid the stack to double in size */
	}
	return top-1;
}

static int luaVA_concat(lua_State *L) {
	int top = lua_gettop(L);
	int i;
	for(i=1; i<=top; ++i) {
		lua_pushvalue(L, i);
		lua_call(L, 0, LUA_MULTRET);
	}
	return lua_gettop(L)-top;
}

static int luaVA_call(lua_State *L) {
	lua_remove(L, 1);
	return luaVA_pack(L);
}

static const luaL_Reg va_funcs[] = {
	{ "pack",    luaVA_pack    },
	{ "range",   luaVA_range   },
	{ "insert",  luaVA_insert  },
	{ "remove",  luaVA_remove  },
	{ "replace", luaVA_replace },
	{ "append",  luaVA_append  },
	{ "map",     luaVA_map     },
	{ "concat",  luaVA_concat  },
	{ "count",   luaVA_count   },
	{ "at",      luaVA_at      },

	{NULL, NULL}
};

LUALIB_API int luaopen_vararg(lua_State *L) {
	luaL_register(L, LUA_VALIBNAME, va_funcs);
	lua_newtable(L);
	lua_pushcfunction(L, luaVA_call);
	lua_setfield(L, -2, "__call");
	lua_setmetatable(L, -2);
	return 1;
}
