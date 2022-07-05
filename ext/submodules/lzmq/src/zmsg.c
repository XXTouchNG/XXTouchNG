/*
  Author: Alexey Melnichuk <mimir@newmail.ru>

  Copyright (C) 2013-2014 Alexey Melnichuk <mimir@newmail.ru>

  Licensed according to the included 'LICENCE' document

  This file is part of lua-lzqm library.
 */

#include "zmsg.h"
#include "lzutils.h"
#include "lzmq.h"
#include <assert.h>
#include <memory.h>
#include <stdlib.h>
#include "zsupport.h"

int luazmq_msg_init(lua_State *L){
  zmessage *zmsg = luazmq_newudata(L, zmessage, LUAZMQ_MESSAGE);
  int err = zmq_msg_init(&zmsg->msg);
  if(-1 == err) return luazmq_fail(L, NULL);
  return 1;
}

int luazmq_msg_init_size(lua_State *L){
  size_t size = luaL_checkinteger(L,1);
  zmessage *zmsg = luazmq_newudata(L, zmessage, LUAZMQ_MESSAGE);
  int err = zmq_msg_init_size(&zmsg->msg, size);
  if(-1 == err) return luazmq_fail(L, NULL);
  return 1;
}

int luazmq_msg_init_data(lua_State *L){
  zmessage *zmsg = luazmq_newudata(L, zmessage, LUAZMQ_MESSAGE);
  size_t size;
  const char *data = luaL_checklstring(L,1,&size);
  int err = zmq_msg_init_size(&zmsg->msg, size);
  if(-1 == err) return luazmq_fail(L, NULL);
  memcpy(zmq_msg_data(&zmsg->msg), data, size);
  return 1;
}

int luazmq_msg_init_data_multi(lua_State *L){
  size_t top = lua_gettop(L);
  size_t i;
  size_t size = 0;
  for(i = 1; i<=top; ++i){
    size_t s;
    luaL_checklstring(L,i,&s);
    size += s;
  }
  if (0 == size) return luazmq_msg_init(L);

  {
    zmessage *zmsg = luazmq_newudata(L, zmessage, LUAZMQ_MESSAGE);
    int err = zmq_msg_init_size(&zmsg->msg, size);
    size_t pos;
    if(-1 == err) return luazmq_fail(L, NULL);
    for(pos = 0, i = 1; i<=top; ++i){
      const char *data = luaL_checklstring(L,i,&size);
      memcpy((char*)zmq_msg_data(&zmsg->msg) + pos, data, size);
      pos += size;
    }
  }

  return 1;
}

int luazmq_msg_init_data_array(lua_State *L){
  size_t top = lua_rawlen(L, 1);
  size_t i;
  size_t size = 0;
  for(i = 1; i<=top; ++i){
    lua_rawgeti(L,1,i);
    size += lua_rawlen(L,-1);
    lua_pop(L, 1);
  }
  if (0 == size) return luazmq_msg_init(L);

  {
    zmessage *zmsg = luazmq_newudata(L, zmessage, LUAZMQ_MESSAGE);
    int err = zmq_msg_init_size(&zmsg->msg, size);
    size_t pos;
    if(-1 == err) return luazmq_fail(L, NULL);
    for(pos = 0, i = 1; i<=top; ++i){
      const char *data;
      lua_rawgeti(L, 1, i);
      data = luaL_checklstring(L,-1,&size);
      memcpy((char*)zmq_msg_data(&zmsg->msg) + pos, data, size);
      pos += size;
      lua_pop(L, 1);
    }
  }

  return 1;
}

int luazmq_msg_close(lua_State *L){
  zmessage *zmsg = (zmessage *)luazmq_checkudatap (L, 1, LUAZMQ_MESSAGE);
  luaL_argcheck (L, zmsg != NULL, 1, LUAZMQ_PREFIX"message expected");
  if(!(zmsg->flags & LUAZMQ_FLAG_CLOSED)){
    zmq_msg_close(&zmsg->msg);
    zmsg->flags |= LUAZMQ_FLAG_CLOSED;
  }
  return luazmq_pass(L);
}

static int luazmq_msg_closed(lua_State *L) {
  zmessage *zmsg = (zmessage *)luazmq_checkudatap (L, 1, LUAZMQ_MESSAGE);
  luaL_argcheck (L, zmsg != NULL, 1, LUAZMQ_PREFIX"message expected");
  lua_pushboolean(L, zmsg->flags & LUAZMQ_FLAG_CLOSED);
  return 1;
}

static int luazmq_msg_move(lua_State *L){
  zmessage *dst, *src;
  int err;
  if(lua_gettop(L) == 1){
    src = luazmq_getmessage_at(L, 1);
    dst = luazmq_newudata(L, zmessage, LUAZMQ_MESSAGE);
    err = zmq_msg_init(&dst->msg);
    if(-1 == err) return luazmq_fail(L, NULL);
  }
  else{
    dst = luazmq_getmessage_at(L, 1);
    src = luazmq_getmessage_at(L, 2);
    lua_pushvalue(L, 1); // result
  }

  err = zmq_msg_move(&dst->msg, &src->msg);
  if(-1 == err) return luazmq_fail(L, NULL);
  return 1;
}

static int luazmq_msg_copy(lua_State *L){
  zmessage *dst, *src;
  int err;
  if(lua_gettop(L) == 1){
    src = luazmq_getmessage_at(L, 1);
    dst = luazmq_newudata(L, zmessage, LUAZMQ_MESSAGE);
    err = zmq_msg_init(&dst->msg);
    if(-1 == err) return luazmq_fail(L, NULL);
  }
  else{
    dst = luazmq_getmessage_at(L, 1);
    src = luazmq_getmessage_at(L, 2);
    lua_pushvalue(L, 1); // result
  }

  err = zmq_msg_copy(&dst->msg, &src->msg);
  if(-1 == err) return luazmq_fail(L, NULL);
  return 1;
}

static int luazmq_msg_size(lua_State *L){
  zmessage *zmsg = luazmq_getmessage(L);
  lua_pushnumber(L, zmq_msg_size(&zmsg->msg));
  return 1;
}

static int luazmq_msg_data(lua_State *L){
  zmessage *zmsg = luazmq_getmessage(L);
  lua_pushlstring(L, zmq_msg_data(&zmsg->msg), zmq_msg_size(&zmsg->msg));
  return 1;
}

static int luazmq_msg_pointer(lua_State *L){
  zmessage *zmsg = luazmq_getmessage(L);
  lua_pushlightuserdata(L, zmq_msg_data(&zmsg->msg));
  return 1;
}

static int luazmq_msg_set_data(lua_State *L){
  zmessage *zmsg = luazmq_getmessage(L);
  int start_pos = (lua_gettop(L) >= 3)?luaL_optint(L,2,1):1;
  size_t size;
  const char *data = luaL_checklstring(L, (lua_gettop(L) >= 3)?3:2, &size);
  int err;
  luaL_argcheck(L, start_pos >= 0, 2, "can not be negative or zero");
  start_pos = start_pos - 1;

  if((start_pos + size) > zmq_msg_size(&zmsg->msg)){
    zmq_msg_t msg;
    err = zmq_msg_init_size(&msg, start_pos + size);
    if(-1 == err)return luazmq_fail(L, NULL);
    memcpy(zmq_msg_data(&msg), zmq_msg_data(&zmsg->msg), zmq_msg_size(&zmsg->msg));
    err = zmq_msg_move(&zmsg->msg, &msg);
    if(-1 == err){
      zmq_msg_close(&msg);
      return luazmq_fail(L, NULL); 
    }
    zmq_msg_close(&msg); // @FIXME do not close message
  }
  memcpy( (char*)zmq_msg_data(&zmsg->msg) + start_pos, data, size);
  return luazmq_pass(L);
}

static int luazmq_msg_set_size(lua_State *L){
  zmessage *zmsg = luazmq_getmessage(L);
  size_t nsize = luaL_checkinteger(L, 2);
  size_t osize = zmq_msg_size(&zmsg->msg);
  int err; zmq_msg_t msg;

  if(nsize == osize) return luazmq_pass(L);

  err = zmq_msg_init_size(&msg, nsize);
  if(-1 == err)return luazmq_fail(L, NULL);

  memcpy(zmq_msg_data(&msg), zmq_msg_data(&zmsg->msg), (nsize>osize)?osize:nsize);
  err = zmq_msg_move(&zmsg->msg, &msg);
  if(-1 == err){
    zmq_msg_close(&msg);
    return luazmq_fail(L, NULL); 
  }
  zmq_msg_close(&msg); // @FIXME do not close message

  return luazmq_pass(L);
}

static int luazmq_msg_more(lua_State *L){
  zmessage *zmsg = luazmq_getmessage(L);
  lua_pushboolean(L, zmq_msg_more(&zmsg->msg));
  return 1;
}

static int luazmq_msg_get(lua_State *L){
  zmessage *zmsg = luazmq_getmessage(L);
  int optname = luaL_checkinteger(L,1);
  int err = zmq_msg_get(&zmsg->msg, optname);
  if(-1 == err)return luazmq_fail(L, NULL);
  lua_pushinteger(L, err);
  return 1;
}

#ifdef LUAZMQ_SUPPORT_MSG_GETS

static int luazmq_msg_gets(lua_State *L){
  zmessage *zmsg = luazmq_getmessage(L);
  const char* optname = luaL_checkstring(L,2);
  const char* value = zmq_msg_gets(&zmsg->msg, optname);

  if(!value) return luazmq_fail(L, NULL);

  lua_pushstring(L, value);
  return 1;
}

#endif

static int luazmq_msg_set(lua_State *L){
  zmessage *zmsg = luazmq_getmessage(L);
  int optname = luaL_checkinteger(L,1);
  int optval  = luaL_checkinteger(L,2);
  int err = zmq_msg_set(&zmsg->msg, optname, optval);
  if(-1 == err)return luazmq_fail(L, NULL);
  return luazmq_pass(L);
}

static int luazmq_msg_send(lua_State *L){
  zmessage *zmsg = luazmq_getmessage(L);
  zsocket  *zskt = luazmq_getsocket_at(L, 2);
  int flags = luaL_optint(L, 3, 0);
  int err = zmq_msg_send(&zmsg->msg, zskt->skt, flags);
  if(-1 == err)return luazmq_fail(L, zskt);
  return luazmq_pass(L);
}

static int luazmq_msg_send_more(lua_State *L){
  int flags = luaL_optint(L, 3, 0) | ZMQ_SNDMORE;
  lua_settop(L, 2);
  lua_pushinteger(L, flags);
  return luazmq_msg_send(L);
}

static int luazmq_msg_recv(lua_State *L){
  zmessage *zmsg = luazmq_getmessage(L);
  zsocket  *zskt = luazmq_getsocket_at(L, 2);
  int flags = luaL_optint(L, 3, 0);
  int err = zmq_msg_recv(&zmsg->msg, zskt->skt, flags);
  if(-1 == err)return luazmq_fail(L, zskt);
  lua_settop(L, 1);
  lua_pushboolean(L, zmq_msg_more(&zmsg->msg));
  return 2;
}

//{ Options
#define DEFINE_MSG_OPT(NAME, OPTNAME) \
  static int luazmq_msg_set_##NAME(lua_State *L){\
    lua_pushinteger(L, OPTNAME);\
    lua_insert(L, 2);\
    return luazmq_msg_set(L);\
  }\
  static int luazmq_msg_get_##NAME(lua_State *L){\
    lua_pushinteger(L, OPTNAME);\
    return luazmq_msg_get(L);\
  }

#define REGISTER_MSG_OPT_RW(NAME) {"set_"#NAME, luazmq_msg_set_##NAME}, {"get_"#NAME, luazmq_msg_get_##NAME}
#define REGISTER_MSG_OPT_RO(NAME) {      #NAME, luazmq_msg_get_##NAME}, {"get_"#NAME, luazmq_msg_get_##NAME}
#define REGISTER_MSG_OPT_WO(NAME) {"set_"#NAME, luazmq_msg_set_##NAME}, {      #NAME, luazmq_msg_set_##NAME}

#ifdef ZMQ_SRCFD
DEFINE_MSG_OPT(srcfd, ZMQ_SRCFD)
#endif

#ifdef ZMQ_SHARED
DEFINE_MSG_OPT(shared, ZMQ_SHARED)
#endif

//}

static const struct luaL_Reg luazmq_msg_methods[] = {
  { "close",      luazmq_msg_close       },
  { "closed",     luazmq_msg_closed      },
  { "move",       luazmq_msg_move        },
  { "copy",       luazmq_msg_copy        },
  { "size",       luazmq_msg_size        },
  { "set_size",   luazmq_msg_set_size    },
  { "pointer",    luazmq_msg_pointer     },
  { "data",       luazmq_msg_data        },
  { "set_data",   luazmq_msg_set_data    },
  { "more",       luazmq_msg_more        },
  { "get",        luazmq_msg_get         },
#ifdef LUAZMQ_SUPPORT_MSG_GETS
  { "gets",       luazmq_msg_gets        },
#endif
  { "set",        luazmq_msg_set         },
  { "send",       luazmq_msg_send        },
  { "send_more",  luazmq_msg_send_more   },
  { "recv",       luazmq_msg_recv        },
  { "__tostring", luazmq_msg_data        },
  { "__gc",       luazmq_msg_close       },

#ifdef ZMQ_SRCFD
  REGISTER_MSG_OPT_RO(srcfd),
#endif

#ifdef ZMQ_SHARED
  REGISTER_MSG_OPT_RO(shared),
#endif

  { NULL, NULL },
};

static const luazmq_int_const msg_options[] ={
  DEFINE_ZMQ_CONST(  MORE   ),

#ifdef ZMQ_SRCFD
  DEFINE_ZMQ_CONST(  SRCFD  ),
#endif

#ifdef ZMQ_SHARED
  DEFINE_ZMQ_CONST(  SHARED ),
#endif

  {NULL, 0}
};

void luazmq_message_initlib(lua_State *L, int nup){
#ifdef LUAZMQ_DEBUG
  int top = lua_gettop(L);
#endif

  luazmq_createmeta(L, LUAZMQ_MESSAGE, luazmq_msg_methods, nup);
  lua_pop(L, 1);

#ifdef LUAZMQ_DEBUG
  assert(top == (lua_gettop(L) + nup));
#endif

  luazmq_register_consts(L, msg_options);
}

