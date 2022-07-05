/*
  Author: Alexey Melnichuk <mimir@newmail.ru>

  Copyright (C) 2013-2014 Alexey Melnichuk <mimir@newmail.ru>

  Licensed according to the included 'LICENCE' document

  This file is part of lua-lzqm library.
 */

#ifndef _LZUTILS_H_
#define _LZUTILS_H_

#if defined(_WIN32)
#include <winsock2.h>
#endif

#include "lua.h"
#include "lauxlib.h"

#if defined(_WIN32)
typedef SOCKET lzmq_os_sock_t;
#else
typedef int    lzmq_os_sock_t;
#endif

#if LUA_VERSION_NUM >= 503 /* Lua 5.3 */

#ifndef luaL_optint
# define luaL_optint luaL_optinteger
#endif

#ifndef luaL_checkint
# define luaL_checkint luaL_checkinteger
#endif

#endif

#if LUA_VERSION_NUM >= 502 

# define luazmq_rawgetp  lua_rawgetp
# define luazmq_rawsetp  lua_rawsetp
# define luazmq_setfuncs luaL_setfuncs
# define luazmq_absindex lua_absindex
#ifndef lua_objlen
# define lua_objlen      lua_rawlen
#endif

int   luazmq_typerror (lua_State *L, int narg, const char *tname);

#else 

# define luazmq_absindex(L, i) (((i)>0)?(i):((i)<=LUA_REGISTRYINDEX?(i):(lua_gettop(L)+(i)+1)))
# define lua_rawlen      lua_objlen
# define luazmq_typerror luaL_typerror

void  luazmq_rawgetp   (lua_State *L, int index, const void *p);
void  luazmq_rawsetp   (lua_State *L, int index, const void *p);
void  luazmq_setfuncs  (lua_State *L, const luaL_Reg *l, int nup);

#endif

int   luazmq_newmetatablep (lua_State *L, const void *p);
void  luazmq_getmetatablep (lua_State *L, const void *p);
int   luazmq_isudatap      (lua_State *L, int ud, const void *p);
void *luazmq_toudatap      (lua_State *L, int ud, const void *p);
void *luazmq_checkudatap   (lua_State *L, int ud, const void *p);

int   luazmq_createmeta    (lua_State *L, const char *name, const luaL_Reg *methods, int nup);
void  luazmq_setmeta       (lua_State *L, const char *name);

void *luazmq_newudata_     (lua_State *L, size_t size, const char *name);

#define luazmq_newudata(L, TTYPE, TNAME) (TTYPE *)luazmq_newudata_(L, sizeof(TTYPE), TNAME)

#define LUAZMQ_STATIC_ASSERT(A) {(int(*)[(A)?1:0])0;}

typedef struct {
  const char *name;
  int value;
}luazmq_int_const;

#define DEFINE_ZMQ_CONST(NAME) {#NAME, ZMQ_##NAME}
#define DEFINE_INT_CONST(NAME) {#NAME, NAME}

#ifdef LUAZMQ_USE_TEMP_BUFFERS
# ifndef LUAZMQ_TEMP_BUFFER_SIZE
#  define LUAZMQ_TEMP_BUFFER_SIZE 128
# endif
# define LUAZMQ_ALLOC_TEMP(BUF, SIZE) (sizeof(BUF) >= SIZE)?(BUF):malloc(SIZE)
# define LUAZMQ_FREE_TEMP(BUF, PTR) do{if((PTR) != (BUF))free((void*)PTR);}while(0)
# define LUAZMQ_DEFINE_TEMP_BUFFER(NAME) char NAME[LUAZMQ_TEMP_BUFFER_SIZE]
#else
# define LUAZMQ_ALLOC_TEMP(BUF, SIZE) malloc(SIZE)
# define LUAZMQ_FREE_TEMP(BUF, PTR) free((void*)PTR)
// MSVC need this to compile easy
# define LUAZMQ_DEFINE_TEMP_BUFFER(NAME) static const void *const NAME = NULL
#endif

void luazmq_register_consts(lua_State *L, const luazmq_int_const *c);

void luazmq_register_consts_invers(lua_State *L, const luazmq_int_const *c);

int luazmq_pcall_method(lua_State *L, const char *name, int nargs, int nresults, int errfunc);

int luazmq_call_method(lua_State *L, const char *name, int nargs, int nresults);

int luazmq_new_weak_table(lua_State*L, const char *mode);

void luazmq_stack_dump(lua_State *L);

lzmq_os_sock_t luazmq_check_os_socket(lua_State *L, int idx, const char *msg);

void luazmq_push_os_socket(lua_State *L, lzmq_os_sock_t fd);

#endif
