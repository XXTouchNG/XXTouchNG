/*
  Author: Alexey Melnichuk <mimir@newmail.ru>

  Copyright (C) 2013-2017 Alexey Melnichuk <mimir@newmail.ru>

  Licensed according to the included 'LICENCE' document

  This file is part of lua-lzqm library.
 */

#include "zcontext.h"
#include "lzutils.h"
#include "lzmq.h"
#include <assert.h>
#include "zsupport.h"

#if ZMQ_VERSION < ZMQ_MAKE_VERSION(4,0,0)
#  define LUAZMQ_CTX_DESTROY zmq_ctx_destroy
#else
#  define LUAZMQ_CTX_DESTROY zmq_ctx_term
#endif

// apply options for object on top of stack
// if set option fail call destroy method for object and return error
// unknown options are ignoring
static int apply_options(lua_State *L, int opt, const char *close_meth){
  if(lua_type(L, opt) == LUA_TTABLE){
    int o = lua_gettop(L);

    lua_pushnil(L);
    while (lua_next(L, opt) != 0){
      assert(lua_gettop(L) == (o+2));
      if(lua_type(L, -2) != LUA_TSTRING){
        lua_pop(L, 1);
        continue;
      }

      lua_pushliteral(L, "set_"); lua_pushvalue(L, -3); lua_concat(L, 2);
      lua_gettable(L, o);
      if(lua_isnil(L, -1)){
        lua_pop(L, 2);
        assert(lua_gettop(L) == (o+1));
        continue;
      }
      lua_insert(L, -2);
      lua_pushvalue(L, o); lua_insert(L, -2);
      lua_call(L, 2, 2);

      if(lua_isnil(L, -2)){
        lua_pushvalue(L, o);
        luazmq_pcall_method(L, close_meth, 0, 0, 0);
        return 2;
      }

      lua_pop(L, 2);
      assert(lua_gettop(L) == (o+1));
    }
    assert(lua_gettop(L) == o);
  }

  return 0;
}

static int apply_bind_connect(lua_State *L, int opt, const char *meth){
  if(lua_type(L, opt) == LUA_TTABLE){
    int o = lua_gettop(L);         // socket
    lua_getfield(L, opt, meth);
    if(!lua_isnil(L, -1)){         // socket, address
      lua_pushvalue(L, o);         // socket, address, socket
      lua_getfield(L, -1, meth);   // socket, address, socket, bind
      lua_insert(L, -3);           // socket, bind, address, socket
      lua_insert(L, -2);           // socket, bind, socket, address
      lua_call(L, 2, 3);
      if(lua_isnil(L, -3)){
        int n = lua_gettop(L);
        lua_pushvalue(L, o);
        luazmq_pcall_method(L, "close", 0, 0, 0);
        lua_settop(L, n);
        return 3;
      }
    }
    lua_settop(L, o);
  }
  return 0;
}

int luazmq_context_create (lua_State *L) {
  zcontext *zctx = luazmq_newudata(L, zcontext, LUAZMQ_CONTEXT);
  zctx->ctx = zmq_ctx_new();
  zctx->autoclose_ref = LUA_NOREF;

#if LZMQ_SOCKET_COUNT
  zctx->socket_count = 0;
#endif

  {int n = apply_options(L, 1, "destroy"); if(n != 0) return n;}

  return 1;
}

int luazmq_context_init (lua_State *L) {
  zcontext *zctx = luazmq_newudata(L, zcontext, LUAZMQ_CONTEXT);
  int n = luaL_optint(L, 1, 1);
  zctx->ctx = zmq_init(n);
  zctx->autoclose_ref = LUA_NOREF;

#if LZMQ_SOCKET_COUNT
  zctx->socket_count = 0;
#endif

  return 1;
}

int luazmq_init_ctx (lua_State *L) {
  void *src_ctx = lua_touserdata(L,1);
  luaL_argcheck(L, lua_islightuserdata(L,1), 1, "You must provide zmq context as lightuserdata");
  if(src_ctx){
    zcontext *zctx = luazmq_newudata(L, zcontext, LUAZMQ_CONTEXT);
    zctx->ctx = src_ctx;
    zctx->flags = LUAZMQ_FLAG_DONT_DESTROY;
    zctx->autoclose_ref = LUA_NOREF;

#if LZMQ_SOCKET_COUNT
    zctx->socket_count = 0;
#endif

    return 1;
  }
  luaL_argcheck(L, 0, 1, "lightuserdata expected");
  return 0;
}

static int luazmq_ctx_lightuserdata(lua_State *L) {
  zcontext *zctx = luazmq_getcontext(L);
  lua_pushlightuserdata(L, zctx->ctx);
  return 1;
}

static int luazmq_ctx_tostring (lua_State *L) {
  zcontext *ctx = (zcontext *)luazmq_checkudatap (L, 1, LUAZMQ_CONTEXT);
  luaL_argcheck (L, ctx != NULL, 1, LUAZMQ_PREFIX"context expected");
  if(ctx->flags & LUAZMQ_FLAG_CLOSED){
    lua_pushfstring(L, LUAZMQ_PREFIX"Context (%p) - closed", ctx);
  }
  else{
    lua_pushfstring(L, LUAZMQ_PREFIX"Context (%p)", ctx);
  }
  return 1;
}

static int luazmq_ctx_set (lua_State *L) {
  zcontext *ctx = luazmq_getcontext(L);
  int option_name  = luaL_checkint(L, 2);
  int option_value = luaL_checkint(L, 3);
  int ret = zmq_ctx_set(ctx->ctx,option_name,option_value);
  if (ret == -1) return luazmq_fail(L,NULL);
  return luazmq_pass(L);
}

static int luazmq_ctx_get (lua_State *L) {
  zcontext *ctx = luazmq_getcontext(L);
  int option_name  = luaL_checkint(L, 2);
  int ret = zmq_ctx_get(ctx->ctx,option_name);
  if (ret == -1) return luazmq_fail(L,NULL);
  lua_pushinteger(L, ret);
  return 1;
}

static int create_autoclose_list(lua_State *L){
  luazmq_new_weak_table(L, "k");
  return luaL_ref(L, LUAZMQ_LUA_REGISTRY);
}

static void call_socket_destroy(lua_State *L, int linger){
  int top = lua_gettop(L);
  assert(luazmq_checkudatap (L, -1, LUAZMQ_SOCKET));
  lua_pushvalue(L, -1);
  if(linger < -1){
    luazmq_pcall_method(L, "close", 0, 0, 0);
  }
  else{
    lua_pushnumber(L, linger);
    luazmq_pcall_method(L, "close", 1, 0, 0);
  }
  lua_settop(L, top);
}

static int luazmq_ctx_autoclose (lua_State *L) {
  zcontext *ctx = luazmq_getcontext(L);
  /*zsocket  *skt = */luazmq_getsocket_at(L,2);

  lua_settop(L, 2);

  if(LUA_NOREF == ctx->autoclose_ref){
    ctx->autoclose_ref = create_autoclose_list(L);
  }

  lua_rawgeti(L, LUAZMQ_LUA_REGISTRY, ctx->autoclose_ref);
  lua_pushvalue(L, -2);
  lua_pushboolean(L, 1);
  lua_rawset(L, -3);
  lua_pop(L,1);

  return 0;
}

static int luazmq_ctx_close_sockets (lua_State *L, zcontext *ctx, int linger){
  if(LUA_NOREF == ctx->autoclose_ref) return 0;

  lua_rawgeti(L, LUAZMQ_LUA_REGISTRY, ctx->autoclose_ref);
  assert(lua_istable(L, -1));
  lua_pushnil(L);
  while(lua_next(L, -2)){
    lua_pop(L, 1); // we do not need value
    call_socket_destroy(L, linger);
  }

  luaL_unref(L, LUAZMQ_LUA_REGISTRY, ctx->autoclose_ref);
  ctx->autoclose_ref = LUA_NOREF;

  return 0;
}

#if LZMQ_SOCKET_COUNT

static int luazmq_ctx_skt_count (lua_State *L) {
  zcontext *ctx = luazmq_getcontext(L);
  lua_pushinteger(L, ctx->socket_count);
  return 1;
}

#endif

#ifdef LUAZMQ_SUPPORT_CTX_SHUTDOWN

static int luazmq_ctx_shutdown (lua_State *L) {
  zcontext *ctx = luazmq_getcontext(L);
  luazmq_ctx_close_sockets(L, ctx, luaL_optint(L, 2, -2));
  if(!(ctx->flags & LUAZMQ_FLAG_DONT_DESTROY)){
    int ret = zmq_ctx_shutdown(ctx->ctx);
    if(ret == -1)return luazmq_fail(L,NULL);
  }
  ctx->flags |= LUAZMQ_FLAG_CTX_SHUTDOWN;
  return luazmq_pass(L);
}

static int luazmq_ctx_shutdowned (lua_State *L) {
  zcontext *ctx = (zcontext *)luazmq_checkudatap (L, 1, LUAZMQ_CONTEXT);
  luaL_argcheck (L, ctx != NULL, 1, LUAZMQ_PREFIX"context expected");
  lua_pushboolean(L, ctx->flags & LUAZMQ_FLAG_CTX_SHUTDOWN);
  return 1;
}

#endif

static int luazmq_ctx_destroy (lua_State *L) {
  zcontext *ctx = (zcontext *)luazmq_checkudatap (L, 1, LUAZMQ_CONTEXT);
  luaL_argcheck (L, ctx != NULL, 1, LUAZMQ_PREFIX"context expected");
  if(!(ctx->flags & LUAZMQ_FLAG_CLOSED)){
    luazmq_ctx_close_sockets(L, ctx, luaL_optint(L, 2, -2));
    if(!(ctx->flags & LUAZMQ_FLAG_DONT_DESTROY)){
      int ret = LUAZMQ_CTX_DESTROY(ctx->ctx);
      if(ret == -1)return luazmq_fail(L,NULL);
    }
    ctx->flags |= LUAZMQ_FLAG_CLOSED;
  }
  return luazmq_pass(L);
}

static int luazmq_ctx_closed (lua_State *L) {
  zcontext *ctx = (zcontext *)luazmq_checkudatap (L, 1, LUAZMQ_CONTEXT);
  luaL_argcheck (L, ctx != NULL, 1, LUAZMQ_PREFIX"context expected");
  lua_pushboolean(L, ctx->flags & LUAZMQ_FLAG_CLOSED);
  return 1;
}

static int socket_type(lua_State *L, int pos){
  static const char* NAMES[] = {
    "PAIR", "PUB", "SUB", "REQ", "REP",
    "DEALER", "ROUTER", "PULL", "PUSH", 
    "XPUB", "XSUB",
#ifdef ZMQ_STREAM
    "STREAM",
#endif

    NULL
  };

  static int TYPES[] = {
   ZMQ_PAIR, ZMQ_PUB, ZMQ_SUB, ZMQ_REQ,
   ZMQ_REP, ZMQ_DEALER, ZMQ_ROUTER, ZMQ_PULL,
   ZMQ_PUSH, ZMQ_XPUB, ZMQ_XSUB,
#ifdef ZMQ_STREAM
    ZMQ_STREAM,
#endif
  };

  if(lua_isnumber(L, pos))
    return lua_tonumber(L, pos);

  if(lua_isstring(L, pos))
    return TYPES[luaL_checkoption(L, pos, NULL, NAMES)];

  if(lua_istable(L, pos)){
    lua_rawgeti(L, pos, 1);
    if(lua_isnumber(L, -1)){
      int n = lua_tonumber(L, -1);
      lua_pop(L, 1);
      return n;
    }
    if(lua_isstring(L, -1)){
      int n = TYPES[luaL_checkoption(L, -1, NULL, NAMES)];
      lua_pop(L, 1);
      return n;
    }
    lua_pop(L, 1);
  }
  return luaL_argerror(L, pos, "Socket type expected");
}

static int luazmq_ctx_socket (lua_State *L) {
  zsocket *zskt;
  zcontext *ctx = luazmq_getcontext(L);
  int stype = socket_type(L,2);
  void *skt = zmq_socket(ctx->ctx, stype);
  if(!skt)return luazmq_fail(L,NULL);

  zskt = luazmq_newudata(L, zsocket, LUAZMQ_SOCKET);
  zskt->skt = skt;
  zskt->onclose_ref = LUA_NOREF;
  zskt->ctx_ref = LUA_NOREF;

#if LZMQ_SOCKET_COUNT
  ctx->socket_count++;
  zskt->ctx = ctx;
  assert(ctx->socket_count > 0);
#endif

  {
#ifdef LUAZMQ_DEBUG
    int top = lua_gettop(L);
#endif
    int opt_pos = lua_istable(L, 2)?2:3;
    int n = apply_options(L, opt_pos, "close");
    if(n != 0) return n;
    n = apply_bind_connect(L, opt_pos, "bind");
    if(n != 0) return n;
    n = apply_bind_connect(L, opt_pos, "connect");
    if(n != 0) return n;
#ifdef LUAZMQ_DEBUG
    assert(top == lua_gettop(L));
#endif
  }

#if LZMQ_AUTOCLOSE_SOCKET
  {
    int n, o = lua_gettop(L);
    lua_pushvalue(L, 1);
    lua_pushvalue(L, o);
    n = luazmq_pcall_method(L, "autoclose", 1, 0, 0);
    if(n != 0){
      int top = lua_gettop(L);
      lua_pushvalue(L, o);
      luazmq_pcall_method(L, "close", 0, 0, 0);
      lua_settop(L, top);
      return lua_error(L);
    }
    assert(o == lua_gettop(L));
  }
#endif

  lua_pushvalue(L, 1);
  zskt->ctx_ref = luaL_ref(L, LUAZMQ_LUA_REGISTRY);

  return 1;
}

#define DEFINE_CTX_OPT(NAME, OPTNAME) \
  static int luazmq_ctx_set_##NAME(lua_State *L){\
    lua_pushinteger(L, OPTNAME);\
    lua_insert(L, 2);\
    return luazmq_ctx_set(L);\
  }\
  static int luazmq_ctx_get_##NAME(lua_State *L){\
    lua_pushinteger(L, OPTNAME);\
    return luazmq_ctx_get(L);\
  }

#define REGISTER_CTX_OPT(NAME) {"set_"#NAME, luazmq_ctx_set_##NAME}, {"get_"#NAME, luazmq_ctx_get_##NAME}

DEFINE_CTX_OPT(io_threads,  ZMQ_IO_THREADS)
DEFINE_CTX_OPT(max_sockets, ZMQ_MAX_SOCKETS)

#ifdef ZMQ_SOCKET_LIMIT
DEFINE_CTX_OPT(socket_limit, ZMQ_SOCKET_LIMIT)
#endif

#ifdef ZMQ_THREAD_PRIORITY
DEFINE_CTX_OPT(thread_priority, ZMQ_THREAD_PRIORITY)
#endif

#ifdef ZMQ_THREAD_SCHED_POLICY
DEFINE_CTX_OPT(thread_sched_policy, ZMQ_THREAD_SCHED_POLICY)
#endif

#ifdef ZMQ_MAX_MSGSZ
DEFINE_CTX_OPT(max_msgsz, ZMQ_MAX_MSGSZ)
#endif

static const struct luaL_Reg luazmq_ctx_methods[] = {
  {"__tostring",    luazmq_ctx_tostring      },
  {"__gc",          luazmq_ctx_destroy       },
  {"destroy",       luazmq_ctx_destroy       },
  {"closed",        luazmq_ctx_closed        },
  {"socket",        luazmq_ctx_socket        },
  {"autoclose",     luazmq_ctx_autoclose     },
  {"term",          luazmq_ctx_destroy       },
  {"set",           luazmq_ctx_set           },
  {"get",           luazmq_ctx_get           },
  {"lightuserdata", luazmq_ctx_lightuserdata },

#if LZMQ_SOCKET_COUNT
  {"socket_count",  luazmq_ctx_skt_count     },
#endif

#ifdef LUAZMQ_SUPPORT_CTX_SHUTDOWN
  {"shutdown",      luazmq_ctx_shutdown      },
  {"shutdowned",    luazmq_ctx_shutdowned    },
#endif

  REGISTER_CTX_OPT(io_threads),
  REGISTER_CTX_OPT(max_sockets),

#ifdef ZMQ_SOCKET_LIMIT
  REGISTER_CTX_OPT(socket_limit),
#endif

#ifdef ZMQ_THREAD_PRIORITY
  REGISTER_CTX_OPT(thread_priority),
#endif

#ifdef ZMQ_THREAD_SCHED_POLICY
  REGISTER_CTX_OPT(thread_sched_policy),
#endif

#ifdef ZMQ_MAX_MSGSZ
  REGISTER_CTX_OPT(max_msgsz),
#endif

  {NULL,NULL}
};

static const luazmq_int_const ctx_options[] = {
  DEFINE_ZMQ_CONST(IO_THREADS),
  DEFINE_ZMQ_CONST(MAX_SOCKETS),

#ifdef ZMQ_SOCKET_LIMIT
  DEFINE_ZMQ_CONST(SOCKET_LIMIT),
#endif

#ifdef ZMQ_THREAD_PRIORITY
  DEFINE_ZMQ_CONST(THREAD_PRIORITY),
#endif

#ifdef ZMQ_THREAD_SCHED_POLICY
  DEFINE_ZMQ_CONST(THREAD_SCHED_POLICY),
#endif

#ifdef ZMQ_MAX_MSGSZ
  DEFINE_ZMQ_CONST(MAX_MSGSZ),
#endif

  {0,0}
};

void luazmq_context_initlib (lua_State *L, int nup){
#ifdef LUAZMQ_DEBUG
  int top = lua_gettop(L);
#endif

  luazmq_createmeta(L, LUAZMQ_CONTEXT, luazmq_ctx_methods, nup);
  lua_pop(L, 1);

#ifdef LUAZMQ_DEBUG
  assert(top == (lua_gettop(L) + nup));
#endif

  luazmq_register_consts(L, ctx_options);
}
