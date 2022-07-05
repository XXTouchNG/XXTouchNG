/*
  Author: Alexey Melnichuk <mimir@newmail.ru>

  Copyright (C) 2013-2014 Alexey Melnichuk <mimir@newmail.ru>

  Licensed according to the included 'LICENCE' document

  This file is part of lua-lzqm library.
 */

#include "lzutils.h"
#include <memory.h>
#include <assert.h>

#if LUA_VERSION_NUM >= 502 

int luazmq_typerror (lua_State *L, int narg, const char *tname) {
  const char *msg = lua_pushfstring(L, "%s expected, got %s", tname,
      luaL_typename(L, narg));
  return luaL_argerror(L, narg, msg);
}

#else 

void luazmq_setfuncs (lua_State *L, const luaL_Reg *l, int nup){
  luaL_checkstack(L, nup, "too many upvalues");
  for (; l->name != NULL; l++) {  /* fill the table with given functions */
    int i;
    for (i = 0; i < nup; i++)  /* copy upvalues to the top */
      lua_pushvalue(L, -nup);
    lua_pushcclosure(L, l->func, nup);  /* closure with those upvalues */
    lua_setfield(L, -(nup + 2), l->name);
  }
  lua_pop(L, nup);  /* remove upvalues */
}

void luazmq_rawgetp(lua_State *L, int index, const void *p){
  index = luazmq_absindex(L, index);
  lua_pushlightuserdata(L, (void *)p);
  lua_rawget(L, index);
}

void luazmq_rawsetp (lua_State *L, int index, const void *p){
  index = luazmq_absindex(L, index);
  lua_pushlightuserdata(L, (void *)p);
  lua_insert(L, -2);
  lua_rawset(L, index);
}

#endif

int luazmq_newmetatablep (lua_State *L, const void *p) {
  luazmq_rawgetp(L, LUA_REGISTRYINDEX, p);
  if (!lua_isnil(L, -1))  /* name already in use? */
    return 0;  /* leave previous value on top, but return 0 */
  lua_pop(L, 1);

  lua_newtable(L);  /* create metatable */
  lua_pushvalue(L, -1); /* duplicate metatable to set*/
  luazmq_rawsetp(L, LUA_REGISTRYINDEX, p);

  return 1;
}

void luazmq_getmetatablep (lua_State *L, const void *p) {
  lua_pushlightuserdata(L, (void *)p);
  lua_rawget(L, LUA_REGISTRYINDEX);
}

int luazmq_isudatap (lua_State *L, int ud, const void *p) {
  if (lua_isuserdata(L, ud)){
    if (lua_getmetatable(L, ud)) {           /* does it have a metatable? */
      int res;
      luazmq_rawgetp(L,LUA_REGISTRYINDEX,p); /* get correct metatable */
      res = lua_rawequal(L, -1, -2);         /* does it have the correct mt? */
      lua_pop(L, 2);                         /* remove both metatables */
      return res;
    }
  }
  return 0;
}

void *luazmq_toudatap (lua_State *L, int ud, const void *p) {
  void *up = lua_touserdata(L, ud);
  if (up != NULL) {  /* value is a userdata? */
    if (lua_getmetatable(L, ud)) {  /* does it have a metatable? */
      luazmq_rawgetp(L,LUA_REGISTRYINDEX,p); /* get correct metatable */
      if (lua_rawequal(L, -1, -2)) {  /* does it have the correct mt? */
        lua_pop(L, 2);  /* remove both metatables */
        return up;
      }
    }
  }
  return NULL;  /* to avoid warnings */
}

void *luazmq_checkudatap (lua_State *L, int ud, const void *p) {
  void *up = luazmq_toudatap(L, ud, p);
  if (up != NULL) {
    return up;
  }
  luazmq_typerror(L, ud, p);  /* else error */
  return NULL;  /* to avoid warnings */
}


int luazmq_createmeta (lua_State *L, const char *name, const luaL_Reg *methods, int nup) {
  if (!luazmq_newmetatablep(L, name))
    return 0;

  lua_insert(L, -1 - nup);           /* move mt prior upvalues */
  luazmq_setfuncs (L, methods, nup); /* define methods */
  lua_pushliteral (L, "__index");    /* define metamethods */
  lua_pushvalue (L, -2);
  lua_settable (L, -3);

  lua_pushliteral (L, "__metatable");
  lua_pushliteral (L, "you're not allowed to get this metatable");
  lua_settable (L, -3);

  return 1;
}

void luazmq_setmeta (lua_State *L, const char *name) {
  luazmq_getmetatablep(L, name);
  assert(lua_istable(L,-1));
  lua_setmetatable (L, -2);
}

void *luazmq_newudata_(lua_State *L, size_t size, const char *name){
  void *obj = lua_newuserdata (L, size);
  memset(obj, 0, size);
  luazmq_setmeta(L, name);
  return obj;
}

void luazmq_register_consts(lua_State *L, const luazmq_int_const *c){
  const luazmq_int_const *v;
  for(v = c; v->name; ++v){
    lua_pushinteger(L, v->value);
    lua_setfield(L, -2, v->name);
  }
}

void luazmq_register_consts_invers(lua_State *L, const luazmq_int_const *c){
  const luazmq_int_const *v;
  for(v = c; v->name; ++v){
    lua_pushstring(L, v->name);
    lua_rawseti(L, -2, v->value);
  }
}

int luazmq_pcall_method(lua_State *L, const char *name, int nargs, int nresults, int errfunc){
  int obj_index = -nargs - 1;
  lua_getfield(L, obj_index, name);
  lua_insert(L, obj_index - 1);
  return lua_pcall(L, nargs + 1, nresults, errfunc);
}

int luazmq_call_method(lua_State *L, const char *name, int nargs, int nresults){
  int top = lua_gettop(L) - nargs;
  int obj_index = -nargs - 1;
  assert(top >= 0);

  lua_getfield(L, obj_index, name);
  lua_insert(L, obj_index - 1);
  lua_call(L, nargs + 1, nresults);
  top = lua_gettop(L) - top;
  assert(top >= 0);
  return top;
}


int luazmq_new_weak_table(lua_State*L, const char *mode){
  int top = lua_gettop(L);
  lua_newtable(L);
  lua_newtable(L);
  lua_pushstring(L, mode);
  lua_setfield(L, -2, "__mode");
  lua_setmetatable(L,-2);
  assert((top+1) == lua_gettop(L));
  return 1;
}

void luazmq_stack_dump (lua_State *L){
  int i = 1, top = lua_gettop(L);

  fprintf(stderr, " ----------------  Stack Dump ----------------\n" );
  while( i <= top ) {
    int t = lua_type(L, i);
    switch (t) {
      case LUA_TSTRING:
        fprintf(stderr, "%d(%d):`%s'\n", i, i - top - 1, lua_tostring(L, i));
        break;
      case LUA_TBOOLEAN:
        fprintf(stderr, "%d(%d): %s\n",  i, i - top - 1,lua_toboolean(L, i) ? "true" : "false");
        break;
      case LUA_TNUMBER:
        fprintf(stderr, "%d(%d): %g\n",  i, i - top - 1, lua_tonumber(L, i));
        break;
      default:
        lua_getglobal(L, "tostring");
        lua_pushvalue(L, i);
        lua_call(L, 1, 1);
        fprintf(stderr, "%d(%d): %s(%s)\n", i, i - top - 1, lua_typename(L, t), lua_tostring(L, -1));
        lua_pop(L, 1);
        break;
    }
    i++;
  }
  fprintf(stderr, " ------------ Stack Dump Finished ------------\n" );
}

lzmq_os_sock_t luazmq_check_os_socket(lua_State *L, int idx, const char *msg) {
  if (lua_islightuserdata(L, idx))
    return (lzmq_os_sock_t)lua_touserdata(L, idx);

  if (!lua_isnumber(L, idx)) {
    luazmq_typerror(L, idx, msg);
    return 0;
  }

  if (sizeof(lua_Integer) >= sizeof(lzmq_os_sock_t))
    return (lzmq_os_sock_t)lua_tointeger(L, idx);
  return (lzmq_os_sock_t)lua_tonumber(L, idx);
}

void luazmq_push_os_socket(lua_State *L, lzmq_os_sock_t fd) {
#if !defined(_WIN32)
  lua_pushinteger(L, (lua_Integer)fd);
#else /*_WIN32*/
  /* Assumes that compiler can optimize constant conditions. MSVC do this. */

  /*On Lua 5.3 lua_Integer type can be represented exactly*/
#if LUA_VERSION_NUM >= 503
  if (sizeof(lzmq_os_sock_t) <= sizeof(lua_Integer)) {
    lua_pushinteger(L, (lua_Integer)fd);
    return;
  }
#endif

#if defined(LUA_NUMBER_DOUBLE) || defined(LUA_NUMBER_FLOAT)
  /*! @todo test DBL_MANT_DIG, FLT_MANT_DIG */

  if (sizeof(lua_Number) == 8) { /*we have 53 bits for integer*/
    if ((sizeof(lzmq_os_sock_t) <= 6)) {
      lua_pushnumber(L, (lua_Number)fd);
      return;
    }

    if(((UINT_PTR)fd & 0x1FFFFFFFFFFFFF) == (UINT_PTR)fd)
      lua_pushnumber(L, (lua_Number)fd);
    else
      lua_pushlightuserdata(L, (void*)fd);

    return;
  }

  if (sizeof(lua_Number) == 4) { /*we have 24 bits for integer*/
    if (((UINT_PTR)fd & 0xFFFFFF) == (UINT_PTR)fd)
      lua_pushnumber(L, (lua_Number)fd);
    else
      lua_pushlightuserdata(L, (void*)fd);
    return;
  }
#endif

  lua_pushnumber(L, (lua_Number)fd);
  if (luazmq_check_os_socket(L, -1, NULL) != fd)
    lua_pushlightuserdata(L, (void*)fd);

#endif /*_WIN32*/
}
