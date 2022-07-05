/*
  Author: Alexey Melnichuk <mimir@newmail.ru>

  Copyright (C) 2013-2014 Alexey Melnichuk <mimir@newmail.ru>

  Licensed according to the included 'LICENCE' document

  This file is part of lua-lzqm library.
 */

#ifndef _LZMQ_H_
#define _LZMQ_H_
#include "lua.h"

#include "zmq.h"

#if defined (_WIN32) || defined (_WINDOWS)
#  define __WINDOWS__
#endif

#ifdef _MSC_VER
#  define LUAZMQ_EXPORT __declspec(dllexport)
#else
#  define LUAZMQ_EXPORT
#endif

#ifndef LZMQ_SOCKET_COUNT
#  define LZMQ_SOCKET_COUNT 1
#endif

#ifndef LZMQ_AUTOCLOSE_SOCKET
#  define LZMQ_AUTOCLOSE_SOCKET 1
#endif

#define LUAZMQ_PREFIX  "LuaZMQ: "

typedef unsigned char uchar;
#define LUAZMQ_FLAG_CLOSED         (uchar)(0x01 << 0)
/*context only*/
#define LUAZMQ_FLAG_CTX_SHUTDOWN   (uchar)(0x01 << 1)
#define LUAZMQ_FLAG_DONT_DESTROY   (uchar)(0x01 << 2)
#define LUAZMQ_FLAG_MORE           (uchar)(0x01 << 3)
#define LUAZMQ_FLAG_CLOSE_ON_ETERM (uchar)(0x01 << 4)

typedef struct{
  void  *ctx;
  uchar flags;
#if LZMQ_SOCKET_COUNT
  int socket_count;
#endif
  int autoclose_ref;
} zcontext;

typedef struct{
  void  *skt;
  uchar flags;
#if LZMQ_SOCKET_COUNT
  zcontext *ctx;
#endif
  int ctx_ref;
  int onclose_ref;
} zsocket;

typedef struct{
  int no;
} zerror;

struct ZMQ_Poller;
typedef struct ZMQ_Poller zpoller;

typedef struct{
  zmq_msg_t msg;
  uchar flags;
} zmessage;

extern const char *LUAZMQ_CONTEXT;
extern const char *LUAZMQ_SOCKET;
extern const char *LUAZMQ_ERROR;
extern const char *LUAZMQ_POLLER;
extern const char *LUAZMQ_MESSAGE;

zcontext *luazmq_getcontext_at (lua_State *L, int i);
#define luazmq_getcontext(L) luazmq_getcontext_at((L),1)

zsocket *luazmq_getsocket_at (lua_State *L, int i);
#define luazmq_getsocket(L) luazmq_getsocket_at((L),1)

zerror *luazmq_geterror_at (lua_State *L, int i);
#define luazmq_geterror(L) luazmq_geterror_at((L),1) 

zpoller *luazmq_getpoller_at (lua_State *L, int i);
#define luazmq_getpoller(L) luazmq_getpoller_at((L),1)

zmessage *luazmq_getmessage_at (lua_State *L, int i);
#define luazmq_getmessage(L) luazmq_getmessage_at((L),1)


int luazmq_pass(lua_State *L);
int luazmq_fail_str(lua_State *L, zsocket *skt);
int luazmq_fail_obj(lua_State *L, zsocket *skt);
int luazmq_fail_no(lua_State *L, zsocket *skt);

#if   defined LUAZMQ_USE_ERR_TYPE_OBJECT
#  define luazmq_fail luazmq_fail_obj
#elif defined LUAZMQ_USE_ERR_TYPE_NUMBER 
#  define luazmq_fail luazmq_fail_no
#elif defined LUAZMQ_USE_ERR_TYPE_STRING
#  define luazmq_fail luazmq_fail_str
#else /* default */
#  define luazmq_fail luazmq_fail_no
#endif

#ifdef LUAZMQ_USE_LUA_REGISTRY
#  define LUAZMQ_LUA_REGISTRY LUA_REGISTRYINDEX
#else
#  define LUAZMQ_LUA_REGISTRY lua_upvalueindex(1)
#endif

int luazmq_allocfail(lua_State *L);

#endif