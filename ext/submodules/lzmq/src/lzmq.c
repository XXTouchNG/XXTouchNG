/*
  Author: Alexey Melnichuk <mimir@newmail.ru>

  Copyright (C) 2013-2017 Alexey Melnichuk <mimir@newmail.ru>

  Licensed according to the included 'LICENCE' document

  This file is part of lua-lzqm library.
 */

#include "zmq.h"
#if ZMQ_VERSION < ZMQ_MAKE_VERSION(4,2,0)
#include "zmq_utils.h"
#endif
#include "lzutils.h"
#include "lzmq.h"
#include "zerror.h"
#include "zmsg.h"
#include "zcontext.h"
#include "zsocket.h"
#include "poller.h"
#include "zpoller.h"
#include <assert.h>
#include "zsupport.h"
#include <memory.h>

#define LUAZMQ_MODULE_NAME      "lzmq"
#define LUAZMQ_MODULE_LICENSE   "MIT"
#define LUAZMQ_MODULE_COPYRIGHT "Copyright (c) 2013-2017 Alexey Melnichuk"
#define LUAZMQ_VERSION_MAJOR 0
#define LUAZMQ_VERSION_MINOR 4
#define LUAZMQ_VERSION_PATCH 5
#define LUAZMQ_VERSION_COMMENT "dev"

const char *LUAZMQ_CONTEXT = LUAZMQ_PREFIX "Context";
const char *LUAZMQ_SOCKET  = LUAZMQ_PREFIX "Socket";
const char *LUAZMQ_ERROR   = LUAZMQ_PREFIX "Error";
const char *LUAZMQ_POLLER  = LUAZMQ_PREFIX "Poller";
const char *LUAZMQ_MESSAGE = LUAZMQ_PREFIX "Message";

static const char *LUAZMQ_STOPWATCH = LUAZMQ_PREFIX "stopwatch";

LUAZMQ_EXPORT int luazmq_context (lua_State *L, void *ctx, unsigned char own) {
  zcontext *zctx;
  assert(ctx);
  zctx = luazmq_newudata(L, zcontext, LUAZMQ_CONTEXT);
  zctx->ctx = ctx;
  zctx->autoclose_ref = LUA_NOREF;

#if LZMQ_SOCKET_COUNT
  zctx->socket_count = 0;
#endif

  if(!own){
    zctx->flags = LUAZMQ_FLAG_DONT_DESTROY;
  }

  return 1;
}

LUAZMQ_EXPORT int luazmq_socket (lua_State *L, void *skt, unsigned char own) {
  zsocket *zskt;
  assert(skt);

  zskt = luazmq_newudata(L, zsocket, LUAZMQ_SOCKET);
  zskt->skt = skt;
  zskt->onclose_ref = LUA_NOREF;
  zskt->ctx_ref = LUA_NOREF;
  if(!own){
    zskt->flags = LUAZMQ_FLAG_DONT_DESTROY;
  }

  return 1;
}

//-----------------------------------------------------------
// common
//{----------------------------------------------------------

int luazmq_pass(lua_State *L){
  lua_pushboolean(L, 1);
  return 1;
}

static int luazmq_geterrno(lua_State *L, zsocket *skt){
  int err = zmq_errno();
  /* After we get ETERM error we can still use this socket
   * to syncronize between threads. So this make sense to not close it.
   */
  if(skt && (err == ETERM)){
    if(!(skt->flags & LUAZMQ_FLAG_CLOSED)){
      if(skt->flags & LUAZMQ_FLAG_CLOSE_ON_ETERM){
        /*int ret = */zmq_close(skt->skt);
        skt->flags |= LUAZMQ_FLAG_CLOSED;
        luazmq_skt_before_close(L, skt);
#if LZMQ_SOCKET_COUNT
        skt->ctx->socket_count--;
        assert(skt->ctx->socket_count >= 0);
#endif
      }
    }
  }
  return err;
}

int luazmq_fail_str(lua_State *L, zsocket *skt){
  int err = luazmq_geterrno(L, skt);
  lua_pushnil(L);
  luazmq_error_pushstring(L, err);
  return 2;
}

int luazmq_fail_no(lua_State *L, zsocket *skt){
  int err = luazmq_geterrno(L, skt);
  lua_pushnil(L);
  lua_pushinteger(L, err);
  return 2;
}

int luazmq_fail_obj(lua_State *L, zsocket *skt){
  int err = luazmq_geterrno(L, skt);
  lua_pushnil(L);
  luazmq_error_create(L, err);
  return 2;
}

int luazmq_allocfail(lua_State *L){
  lua_pushliteral(L, "can not allocate enouth memory");
  return lua_error(L);
}

zcontext *luazmq_getcontext_at (lua_State *L, int i) {
 zcontext *ctx = (zcontext *)luazmq_checkudatap (L, i, LUAZMQ_CONTEXT);
 luaL_argcheck (L, ctx != NULL, 1, LUAZMQ_PREFIX"context expected");
 luaL_argcheck (L, !(ctx->flags & LUAZMQ_FLAG_CLOSED), 1, LUAZMQ_PREFIX"context is closed");
 luaL_argcheck (L, !(ctx->flags & LUAZMQ_FLAG_CTX_SHUTDOWN), 1, LUAZMQ_PREFIX"context is  shutdowned");
 return ctx;
}

zsocket *luazmq_getsocket_at (lua_State *L, int i) {
 zsocket *skt = (zsocket *)luazmq_checkudatap (L, i, LUAZMQ_SOCKET);
 luaL_argcheck (L, skt != NULL, 1, LUAZMQ_PREFIX"socket expected");
 luaL_argcheck (L, !(skt->flags & LUAZMQ_FLAG_CLOSED), 1, LUAZMQ_PREFIX"socket is closed");
 return skt;
}

zerror *luazmq_geterror_at (lua_State *L, int i) {
  zerror *err = (zerror *)luazmq_checkudatap (L, i, LUAZMQ_ERROR);
  luaL_argcheck (L, err != NULL, 1, LUAZMQ_PREFIX"error object expected");
  return err;
}

zpoller *luazmq_getpoller_at (lua_State *L, int i) {
  zpoller *poller = (zpoller *)luazmq_checkudatap (L, i, LUAZMQ_POLLER);
  luaL_argcheck (L, poller != NULL, 1, LUAZMQ_PREFIX"poller expected");
  luaL_argcheck (L, poller->items != NULL, 1, LUAZMQ_PREFIX"poller is closed");
  return poller;
}

zmessage *luazmq_getmessage_at (lua_State *L, int i) {
  zmessage *zmsg = (zmessage *)luazmq_checkudatap (L, i, LUAZMQ_MESSAGE);
  luaL_argcheck (L, zmsg != NULL, 1, LUAZMQ_PREFIX"message expected");
  luaL_argcheck (L, !(zmsg->flags & LUAZMQ_FLAG_CLOSED), 1, LUAZMQ_PREFIX"message is closed");
  return zmsg;
}

//}----------------------------------------------------------

//-----------------------------------------------------------
// zmq.utils
//{----------------------------------------------------------

typedef void* zstopwatch;

static int luazmq_stopwatch_create(lua_State *L){
  zstopwatch *timer = luazmq_newudata(L, zstopwatch, LUAZMQ_STOPWATCH);
  *timer = NULL;
  return 1;
}

static int luazmq_stopwatch_start(lua_State *L){
  zstopwatch *timer = luazmq_checkudatap(L, 1, LUAZMQ_STOPWATCH);
  luaL_argcheck (L, *timer == NULL, 1, LUAZMQ_PREFIX"timer alrady started");
  *timer = zmq_stopwatch_start();
  return 1;
}

static int luazmq_stopwatch_stop(lua_State *L){
  zstopwatch *timer = luazmq_checkudatap(L, 1, LUAZMQ_STOPWATCH);
  luaL_argcheck (L, *timer != NULL, 1, LUAZMQ_PREFIX"timer not started");
  lua_pushnumber(L, zmq_stopwatch_stop(*timer));
  *timer = NULL;
  return 1;
}

static int luazmq_stopwatch_close(lua_State *L){
  zstopwatch *timer = luazmq_checkudatap(L, 1, LUAZMQ_STOPWATCH);
  if(*timer){
    zmq_stopwatch_stop(*timer);
    *timer = NULL;
  }
  return luazmq_pass(L);
}

static int luazmq_utils_sleep(lua_State *L){
  int sec = luaL_checkint(L, 1);
  zmq_sleep(sec);
  return luazmq_pass(L);
}

static const struct luaL_Reg luazmq_utilslib[]   = {
  { "stopwatch",     luazmq_stopwatch_create },
  { "sleep",         luazmq_utils_sleep      },

  {NULL, NULL}
};

static const struct luaL_Reg luazmq_stopwatch_methods[] = {
  {"start",    luazmq_stopwatch_start },
  {"stop",     luazmq_stopwatch_stop  },
  {"__gc",     luazmq_stopwatch_close },

  {NULL,NULL}
};

static void luazmq_zutils_initlib(lua_State *L, int nup){
#ifdef LUAZMQ_DEBUG
  int top = lua_gettop(L);
#endif

  int i = 0;
  for (i = 0; i < nup; i++)
    lua_pushvalue(L, -nup);

#ifdef LUAZMQ_DEBUG
  {int top = lua_gettop(L);
#endif

  luazmq_createmeta(L, LUAZMQ_STOPWATCH, luazmq_stopwatch_methods, nup);
  lua_pop(L, 1);

#ifdef LUAZMQ_DEBUG
  assert(top == (lua_gettop(L) + nup));}
#endif

  lua_newtable(L);
  luazmq_setfuncs(L, luazmq_utilslib, nup);
  lua_setfield(L, -2, "utils");

#ifdef LUAZMQ_DEBUG
  assert(top == (lua_gettop(L) + nup));
#endif
}

//}

//-----------------------------------------------------------
// zmq
//{----------------------------------------------------------

static int luazmq_push_version(lua_State *L){
  lua_pushinteger(L, LUAZMQ_VERSION_MAJOR);
  lua_pushliteral(L, ".");
  lua_pushinteger(L, LUAZMQ_VERSION_MINOR);
  lua_pushliteral(L, ".");
  lua_pushinteger(L, LUAZMQ_VERSION_PATCH);
#ifdef LUAZMQ_VERSION_COMMENT
  if(LUAZMQ_VERSION_COMMENT[0]){
    lua_pushliteral(L, "-"LUAZMQ_VERSION_COMMENT);
    lua_concat(L, 6);
  }
  else
#endif
  lua_concat(L, 5);
  return 1;
}

static int luazmq_version(lua_State *L){
  int major, minor, patch;
  zmq_version (&major, &minor, &patch);
  if(!lua_toboolean(L, 1)){
    lua_newtable(L);
    lua_pushinteger(L, major); lua_rawseti(L, -2, 1);
    lua_pushinteger(L, minor); lua_rawseti(L, -2, 2);
    lua_pushinteger(L, patch); lua_rawseti(L, -2, 3);
    return 1;
  }
  lua_pushinteger(L, major);
  lua_pushinteger(L, minor);
  lua_pushinteger(L, patch);
  return 3;
}

static int luazmq_device(lua_State *L){
  int device_type = luaL_checkint(L,1);
  zsocket *fe = luazmq_getsocket_at(L,2);
  zsocket *be = luazmq_getsocket_at(L,3);
  int ret = zmq_device(device_type, fe->skt, be->skt);
  if (ret == -1) return luazmq_fail(L,NULL);

  assert(0 && "The zmq_device() function always returns -1 and errno set to ETERM");
  return luazmq_pass(L);
}

#ifdef LUAZMQ_SUPPORT_PROXY

static int luazmq_proxy(lua_State *L){
  zsocket *fe = luazmq_getsocket_at(L,1);
  zsocket *be = luazmq_getsocket_at(L,2);
  zsocket *cp = lua_isnoneornil(L,3)?NULL:luazmq_getsocket_at(L,3);
  int ret = zmq_proxy(fe->skt, be->skt, cp ? (cp->skt) : NULL);
  if (ret == -1) return luazmq_fail(L,NULL);

  assert(0 && "The zmq_proxy() function always returns -1 and errno set to ETERM");
  return luazmq_pass(L);
}

#endif

#ifdef LUAZMQ_SUPPORT_PROXY_STEERABLE

static int luazmq_proxy_steerable(lua_State *L){
  zsocket *fe = luazmq_getsocket_at(L,1);
  zsocket *be = luazmq_getsocket_at(L,2);
  zsocket *cp = lua_isnoneornil(L,3)?NULL:luazmq_getsocket_at(L,3);
  zsocket *cn = lua_isnoneornil(L,4)?NULL:luazmq_getsocket_at(L,4);
  int ret = zmq_proxy_steerable(fe->skt, be->skt, cp ? (cp->skt) : NULL, cn ? (cn->skt) : NULL);
  if (ret == -1) return luazmq_fail(L,NULL);
  return luazmq_pass(L);
}

#endif

#ifdef ZMQ_HAS_CAPABILITIES

static int luazmq_has(lua_State *L){
  const char *capability = luaL_checkstring(L,1);
  lua_pushboolean(L, zmq_has(capability));
  return 1;
}

#endif

static int luazmq_error_create_(lua_State *L){
  int err = luaL_checkint(L, 1);
  return luazmq_error_create(L, err);
}

static int luazmq_error_tostring(lua_State *L){
  int err = luaL_checkint(L, 1);
  luazmq_error_pushstring(L, err);
  return 1;
}

#ifdef LUAZMQ_SUPPORT_Z85

static int luazmq_z85_encode(lua_State *L){
  size_t len; const char *data = luaL_checklstring(L, 1, &len);
  LUAZMQ_DEFINE_TEMP_BUFFER(buffer_storage);
  size_t dest_len; char *dest;

#ifndef LUAZMQ_DEBUG
  if(len == 32) dest_len = 41; else
#endif
  {
    dest_len = len >> 2;
    luaL_argcheck(L, len == (dest_len << 2), 1, "size of the block must be divisible by 4");
    dest_len += len + 1;
  }

  dest = LUAZMQ_ALLOC_TEMP(buffer_storage, dest_len);
  if(!zmq_z85_encode(dest, (unsigned char*)data, len))lua_pushnil(L);
  else lua_pushlstring(L, dest, dest_len - 1);
  LUAZMQ_FREE_TEMP(buffer_storage, dest);

  return 1;
}

static int luazmq_z85_decode(lua_State *L){
  size_t len; const char *data = luaL_checklstring(L, 1, &len);
  LUAZMQ_DEFINE_TEMP_BUFFER(buffer_storage);
  size_t dest_len; char *dest;
#ifndef LUAZMQ_DEBUG
  if(len == 40) dest_len = 32; else
#endif
  {
    dest_len = 0.8 * len;
    luaL_argcheck(L, len == (dest_len + (dest_len >> 2)), 1, "size of the block must be divisible by 5");
  }

  dest = LUAZMQ_ALLOC_TEMP(buffer_storage, dest_len);
  if(!zmq_z85_decode((unsigned char*)dest, (char*)data)) lua_pushnil(L);
  else lua_pushlstring(L, dest, dest_len);
  LUAZMQ_FREE_TEMP(buffer_storage, dest);

  return 1;
}

#endif

#ifdef LUAZMQ_SUPPORT_CURVE_KEYPAIR

static int luazmq_curve_keypair(lua_State *L){
  int as_bin = lua_toboolean(L, 1);
  char public_key [41];
  char secret_key [41];
  int rc = zmq_curve_keypair(public_key, secret_key);
  if(rc == -1)
    return luazmq_fail(L, 0);

  if(as_bin){
    uint8_t public_key_bin[32];
    uint8_t secret_key_bin[32];
    zmq_z85_decode (public_key_bin, public_key);
    zmq_z85_decode (secret_key_bin, secret_key);
    lua_pushlstring(L, (char*)public_key_bin, 32);
    lua_pushlstring(L, (char*)secret_key_bin, 32);
    return 2;
  }

  lua_pushlstring(L, public_key, 40);
  lua_pushlstring(L, secret_key, 40);
  return 2;
}

#endif

#ifdef LUAZMQ_SUPPORT_CURVE_PUBLIC

static int luazmq_curve_public(lua_State *L){
  const char *secret_key = luaL_checkstring(L, 1);
  int as_bin = lua_toboolean(L, 2);
  char public_key [41];
  int rc = zmq_curve_public(public_key, secret_key);
  if(rc == -1)
    return luazmq_fail(L, 0);

  if(as_bin){
    uint8_t public_key_bin[32];
    zmq_z85_decode (public_key_bin, public_key);
    lua_pushlstring(L, (char*)public_key_bin, 32);
  }
  else{
    lua_pushlstring(L, public_key, 40);
  }

  return 1;
}

#endif

static int luazmq_init_socket(lua_State *L) {
  void *src = lua_touserdata(L, 1);
  luaL_argcheck(L, lua_islightuserdata(L, 1), 1, "lightuserdata expected");

  return luazmq_socket(L, src, 0);
}

//}----------------------------------------------------------

static const struct luaL_Reg luazmqlib[]   = {
  { "version",        luazmq_version          },

#ifdef LUAZMQ_SUPPORT_PROXY
  { "proxy",          luazmq_proxy            },
#endif

#ifdef LUAZMQ_SUPPORT_PROXY_STEERABLE
  { "proxy_steerable",luazmq_proxy_steerable  },
#endif

#ifdef LUAZMQ_SUPPORT_Z85
  { "z85_encode",     luazmq_z85_encode       },
  { "z85_decode",     luazmq_z85_decode       },
#endif

#ifdef LUAZMQ_SUPPORT_CURVE_KEYPAIR
  { "curve_keypair",  luazmq_curve_keypair    },
#endif

#ifdef LUAZMQ_SUPPORT_CURVE_PUBLIC
  { "curve_public",  luazmq_curve_public      },
#endif

#ifdef ZMQ_HAS_CAPABILITIES
  { "has",            luazmq_has              },
#endif

  { "device",         luazmq_device           },
  { "assert",         luazmq_assert           },
  { "error",          luazmq_error_create_    },
  { "strerror",       luazmq_error_tostring   },
  { "context",        luazmq_context_create   },
  { "poller",         luazmq_poller_create    },
  { "init",           luazmq_context_init     },
  { "init_ctx",       luazmq_init_ctx         },
  { "init_socket",    luazmq_init_socket      },
  { "msg_init",       luazmq_msg_init         },
  { "msg_init_size",  luazmq_msg_init_size    },
  { "msg_init_data",  luazmq_msg_init_data    },
  { "msg_init_data_multi",  luazmq_msg_init_data_multi    },
  { "msg_init_data_array",  luazmq_msg_init_data_array    },

  {NULL, NULL}
};

const luazmq_int_const device_types[] ={
  DEFINE_ZMQ_CONST(  STREAMER  ),
  DEFINE_ZMQ_CONST(  FORWARDER ),
  DEFINE_ZMQ_CONST(  QUEUE     ),

  {NULL, 0}
};

const luazmq_int_const events_types[] ={
  DEFINE_ZMQ_CONST( EVENT_CONNECTED       ),
  DEFINE_ZMQ_CONST( EVENT_CONNECT_DELAYED ),
  DEFINE_ZMQ_CONST( EVENT_CONNECT_RETRIED ),
 
  DEFINE_ZMQ_CONST( EVENT_LISTENING       ),
  DEFINE_ZMQ_CONST( EVENT_BIND_FAILED     ),

  DEFINE_ZMQ_CONST( EVENT_ACCEPTED        ),
  DEFINE_ZMQ_CONST( EVENT_ACCEPT_FAILED   ),

  DEFINE_ZMQ_CONST( EVENT_CLOSED          ),
  DEFINE_ZMQ_CONST( EVENT_CLOSE_FAILED    ),
  DEFINE_ZMQ_CONST( EVENT_DISCONNECTED    ),
#ifdef ZMQ_EVENT_MONITOR_STOPPED
  DEFINE_ZMQ_CONST( EVENT_MONITOR_STOPPED ),
#endif

  DEFINE_ZMQ_CONST( EVENT_ALL             ),

  {NULL, 0}
};

static void luazmq_init_lib(lua_State *L){
  lua_newtable(L); /* registry */
  lua_newtable(L); /* library  */

  lua_pushvalue(L, -2); luazmq_setfuncs(L, luazmqlib, 1);
  lua_pushvalue(L, -2); luazmq_context_initlib(L, 1);
  lua_pushvalue(L, -2); luazmq_socket_initlib (L, 1);
  lua_pushvalue(L, -2); luazmq_poller_initlib (L, 1);
  lua_pushvalue(L, -2); luazmq_error_initlib  (L, 1);
  lua_pushvalue(L, -2); luazmq_message_initlib(L, 1);
  lua_pushvalue(L, -2); luazmq_zutils_initlib (L, 1);
  lua_remove(L, -2);/* registry */

  luazmq_register_consts(L, device_types);
  luazmq_register_consts(L, events_types);

  lua_pushliteral(L, "_VERSION");
  luazmq_push_version(L);
  lua_rawset(L, -3);

  lua_pushliteral(L, "_NAME");
  lua_pushliteral(L, LUAZMQ_MODULE_NAME);
  lua_rawset(L, -3);

  lua_pushliteral(L, "_LICENSE");
  lua_pushliteral(L, LUAZMQ_MODULE_LICENSE);
  lua_rawset(L, -3);

  lua_pushliteral(L, "_COPYRIGHT");
  lua_pushliteral(L, LUAZMQ_MODULE_COPYRIGHT);
  lua_rawset(L, -3);
}

LUAZMQ_EXPORT int luaopen_lzmq (lua_State *L){
  LUAZMQ_STATIC_ASSERT(offsetof(zsocket, skt) == 0);

  luazmq_init_lib(L);
  return 1;
}
