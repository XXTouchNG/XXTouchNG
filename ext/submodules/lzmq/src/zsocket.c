/*
  Author: Alexey Melnichuk <mimir@newmail.ru>

  Copyright (C) 2013-2017 Alexey Melnichuk <mimir@newmail.ru>

  Licensed according to the included 'LICENCE' document

  This file is part of lua-lzqm library.
 */

#include "zsocket.h"
#include "zmsg.h"
#include "lzutils.h"
#include "lzmq.h"
#include "zerror.h"
#include <stdint.h>
#include <assert.h>
#include <memory.h>
#include <stdlib.h>

#define fd_t lzmq_os_sock_t

#define DEFINE_SKT_METHOD_1(NAME)              \
                                               \
static int luazmq_skt_##NAME (lua_State *L) {  \
  zsocket *skt = luazmq_getsocket(L);          \
  size_t tlen, i;                              \
  int ret;                                     \
  const char *val;                             \
                                               \
  if(!lua_istable(L, 2)){                      \
    val = luaL_checkstring(L, 2);              \
    ret = zmq_##NAME(skt->skt, val);           \
    if (ret == -1) return luazmq_fail(L, skt); \
    return luazmq_pass(L);                     \
  }                                            \
                                               \
  tlen = lua_objlen(L,2);                      \
  for (i = 1; i <= tlen; i++){                 \
    lua_rawgeti(L, 2, i);                      \
    val = luaL_checkstring(L, -1);             \
    ret = zmq_##NAME(skt->skt, val);           \
    lua_pop(L, 1);                             \
    if (ret == -1){                            \
      int n = luazmq_fail(L, skt);             \
      lua_pushstring(L, val);                  \
      return n + 1;                            \
    }                                          \
  }                                            \
  return luazmq_pass(L);                       \
}

DEFINE_SKT_METHOD_1(bind)
DEFINE_SKT_METHOD_1(unbind)
DEFINE_SKT_METHOD_1(connect)
DEFINE_SKT_METHOD_1(disconnect)

#define RANDOM_PORT_BASE 0xC000
#define RANDOM_PORT_MAX  0xFFFF

static int luazmq_skt_bind_to_random_port (lua_State *L) {
  zsocket *skt = luazmq_getsocket(L);
  LUAZMQ_DEFINE_TEMP_BUFFER(buffer_storage);
  size_t dest_len; const char *base_address = luaL_checklstring(L, 2, &dest_len);
  int base_port = luaL_optint(L, 3, RANDOM_PORT_BASE);
  int max_tries = luaL_optint(L, 4, RANDOM_PORT_MAX - base_port + 1);
  char *dest;

  luaL_argcheck(L, ((base_port > 0) && (base_port <= RANDOM_PORT_MAX)), 3, "invalid port number");
  luaL_argcheck(L, (max_tries > 0), 4, "invalid max tries value");

  dest = LUAZMQ_ALLOC_TEMP(buffer_storage, dest_len + 10);
  memcpy(dest, base_address, dest_len);
  dest[dest_len] = ':';
  
  for(;(base_port <= RANDOM_PORT_MAX)&&(max_tries > 0); --max_tries, ++base_port){
    int ret;
    sprintf(&dest[dest_len+1], "%d", base_port);
    ret = zmq_bind(skt->skt, dest);
    if(ret != -1){
      LUAZMQ_FREE_TEMP(buffer_storage, dest);
      lua_pushinteger(L, base_port);
      return 1;
    }
    else{
      int err = zmq_errno();
      if(err == EADDRINUSE) continue;
      if(err == EACCES) continue;

#ifdef _WIN32
  #if !defined(_MSC_VER) || (_MSC_VER < 1600)
      if(strcmp(zmq_strerror(err), "Address in use") == 0) continue;
  #endif
#endif

      break;
    }
  }
  LUAZMQ_FREE_TEMP(buffer_storage, dest);

  return luazmq_fail(L, skt);
}

static int luazmq_skt_send (lua_State *L) {
  zsocket *skt = luazmq_getsocket(L);
  size_t len;
  const char *data = luaL_checklstring(L, 2, &len);
  int ret, flags = luaL_optint(L,3,0);

#ifdef LUAZMQ_USE_SEND_AS_BUF
  ret = zmq_send(skt->skt, data, len, flags);
#else
  zmq_msg_t msg;
  ret = zmq_msg_init_size(&msg, len);
  if(-1 == ret) return luazmq_fail(L, skt);
  memcpy(zmq_msg_data(&msg), data, len);
  ret = zmq_msg_send(&msg, skt->skt, flags);
  zmq_msg_close(&msg);
#endif

  if(-1 == ret) return luazmq_fail(L, skt);
  return luazmq_pass(L);
}

static int luazmq_skt_send_msg (lua_State *L) {
  zsocket *skt  = luazmq_getsocket(L);
  zmessage *msg = luazmq_getmessage_at(L,2);
  int flags = luaL_optint(L,3,0);
  int ret = zmq_msg_send(&msg->msg, skt->skt, flags);
  if(-1 == ret) return luazmq_fail(L, skt);
  return luazmq_pass(L);
}

static int luazmq_skt_send_more(lua_State *L) {
  int flags = luaL_optint(L, 3, 0);
  flags |= ZMQ_SNDMORE;
  lua_settop(L, 2);
  lua_pushinteger(L, flags);
  return luazmq_skt_send(L);
}

static int luazmq_skt_recv (lua_State *L) {
  zsocket *skt = luazmq_getsocket(L);
  zmq_msg_t msg;
  int flags = luaL_optint(L,2,0);
  int ret = zmq_msg_init(&msg);
  if(-1 == ret) return luazmq_fail(L, skt);
  ret = zmq_msg_recv(&msg, skt->skt, flags);
  if(-1 == ret){
    zmq_msg_close(&msg);
    return luazmq_fail(L, skt);
  }
  lua_pushlstring(L, zmq_msg_data(&msg), zmq_msg_size(&msg));
  if( zmq_msg_more(&msg) ){
    skt->flags |= LUAZMQ_FLAG_MORE;
    lua_pushboolean(L, 1);
  }
  else{
    skt->flags &= ~LUAZMQ_FLAG_MORE;
    lua_pushboolean(L, 0);
  }

  zmq_msg_close(&msg);
  return 2;
}

static int luazmq_skt_recv_len (lua_State *L) {
  zsocket *skt = luazmq_getsocket(L);
  size_t len = luaL_checkint(L, 2);
  int flags = luaL_optint(L,3,0);
  int ret, more;
  size_t more_size = sizeof(more);
  LUAZMQ_DEFINE_TEMP_BUFFER(tmp);
  char *buffer = LUAZMQ_ALLOC_TEMP(tmp, len);
  if(!buffer) return luazmq_allocfail(L);

  ret = zmq_recv(skt->skt, buffer, len, flags);
  if(-1 == ret){
    LUAZMQ_FREE_TEMP(tmp, buffer);
    return luazmq_fail(L, skt);
  }
  assert(ret >= 0);

  lua_pushlstring(L, buffer, (ret < len)?ret:len);
  LUAZMQ_FREE_TEMP(tmp, buffer);
  len = ret;
  ret = zmq_getsockopt(skt->skt, ZMQ_RCVMORE, &more, &more_size);
  if(-1 == ret) return luazmq_fail(L, skt);

  if( more ){
    skt->flags |= LUAZMQ_FLAG_MORE;
    lua_pushboolean(L, 1);
  }
  else{
    skt->flags &= ~LUAZMQ_FLAG_MORE;
    lua_pushboolean(L, 0);
  }

  lua_pushinteger(L, len);
  return 3;
}

static int luazmq_skt_recv_msg (lua_State *L) {
  zsocket *skt  = luazmq_getsocket(L);
  zmessage *msg = luazmq_getmessage_at(L,2);
  int flags     = luaL_optint(L,3,0);
  int ret = zmq_msg_recv(&msg->msg, skt->skt, flags);

  if(-1 == ret) return luazmq_fail(L, skt);

  lua_settop(L, 2); // remove flags
  if( zmq_msg_more(&msg->msg) ){
    skt->flags |= LUAZMQ_FLAG_MORE;
    lua_pushboolean(L, 1);
  }
  else{
    skt->flags &= ~LUAZMQ_FLAG_MORE;
    lua_pushboolean(L, 0);
  }
  return 2;
}

static int luazmq_skt_recv_event (lua_State *L) {
  zsocket *skt  = luazmq_getsocket(L);
  int rc, flags = luaL_optint(L, 2, 0);

#if ZMQ_VERSION_MAJOR == 3
  zmq_event_t event;

  zmq_msg_t msg;
  zmq_msg_init (&msg);

  rc = zmq_msg_recv (&msg, skt->skt, flags);
  if(rc == -1){
    zmq_msg_close(&msg);
    return luazmq_fail(L, skt);
  }

  memcpy (&event, zmq_msg_data (&msg), sizeof (event));

  lua_pushnumber(L, event.event);
  lua_pushnumber(L, event.data.connected.fd);
  if(event.data.connected.addr){
    lua_pushstring(L, event.data.connected.addr);
    zmq_msg_close(&msg);
    return 3;
  }
  zmq_msg_close(&msg);
  return 2;

#else // 4.0+

  uint16_t event_id;     // id of the event as bitfield
  int32_t  event_value;  // value is either error code, fd or reconnect interval
  zmq_msg_t msg1, msg2;  // binary and address parts

  zmq_msg_init (&msg1); zmq_msg_init (&msg2);

  rc = zmq_msg_recv (&msg1, skt->skt, flags);
  if(rc == -1){
    zmq_msg_close(&msg1);
    zmq_msg_close(&msg2);
    return luazmq_fail(L, skt);
  }

  assert (zmq_msg_more(&msg1) != 0);
  assert (zmq_msg_size(&msg1) == (sizeof(event_id) + sizeof(event_value)));

  rc = zmq_msg_recv (&msg2, skt->skt, flags);
  if(rc == -1){
    zmq_msg_close(&msg1);
    zmq_msg_close(&msg2);
    return luazmq_fail(L, skt);
  }

  assert (zmq_msg_more(&msg2) == 0);

  { // copy binary data to event struct
    const char* data = (char*)zmq_msg_data(&msg1);
    memcpy(&(event_id), data, sizeof(event_id));
    memcpy(&(event_value), data + sizeof(event_id), sizeof(event_value));
    zmq_msg_close(&msg1);
  }

  lua_pushnumber(L, event_id);
  lua_pushnumber(L, event_value);
  lua_pushlstring(L, zmq_msg_data(&msg2), zmq_msg_size(&msg2));
  zmq_msg_close(&msg2);
  return 3;
#endif
}

static int luazmq_skt_recv_new_msg (lua_State *L){
  if(lua_isuserdata(L,2)) return luazmq_skt_recv_msg(L);
  luaL_optint(L, 2, 0);
  {
    int n = luazmq_msg_init(L);
    if(n != 1)return n;
    lua_insert(L, 2);
    n = luazmq_skt_recv_msg(L);
    if(lua_isnil(L, -n)){
      zmessage *msg = luazmq_getmessage_at(L, 2);
      zmq_msg_close(&msg->msg);
      msg->flags |= LUAZMQ_FLAG_CLOSED;
    }
    return n;
  }
}

static int luazmq_skt_more (lua_State *L) {
  zsocket *skt = luazmq_getsocket(L);
  lua_pushboolean(L, skt->flags & LUAZMQ_FLAG_MORE);
  return 1;
}

static int luazmq_skt_send_all (lua_State *L) {
  zsocket *skt = luazmq_getsocket(L);
  int flags = luaL_optint(L,3,0);
  int n, i = luaL_optint(L,4,1);
  if(lua_isnoneornil(L, 5)){
    n = lua_objlen(L, 2);
  }
  else{
    n = luaL_checkint(L, 5);
    luaL_argcheck(L, n >= i, 5, "invalid range");
  }

  if(flags & (~ZMQ_SNDMORE)){
    lua_pushnil(L);
    luazmq_error_create(L, ENOTSUP);
    return 2;
  }
  
  for(;i <= n; ++i){
    zmq_msg_t msg;
    const char *data;size_t len;
    int ret;
    lua_rawgeti(L, 2, i);
    data = luaL_checklstring(L, -1, &len);
    ret = zmq_msg_init_size(&msg, len);
    if(-1 == ret){
      ret = luazmq_fail(L, skt);
      lua_pushinteger(L, i);
      return ret + 1;
    }
    memcpy(zmq_msg_data(&msg), data, len);
    ret = zmq_msg_send(&msg, skt->skt, (i == n)?flags:ZMQ_SNDMORE);
    zmq_msg_close(&msg);
    if(-1 == ret){
      ret = luazmq_fail(L, skt);
      lua_pushinteger(L, i);
      return ret + 1;
    }
  }
  return luazmq_pass(L);
}

static int luazmq_skt_sendx_impl(lua_State *L, int last_flag) {
  zsocket *skt = luazmq_getsocket(L);
  size_t i, n = lua_gettop(L);
  for(i = 2; i<=n; ++i){
    zmq_msg_t msg;
    size_t len; const char *data = luaL_checklstring(L, i, &len);
    int ret = zmq_msg_init_size(&msg, len);
    if(-1 == ret){
      ret = luazmq_fail(L, skt);
      lua_pushinteger(L, i);
      return ret + 1;
    }
    memcpy(zmq_msg_data(&msg), data, len);
    ret = zmq_msg_send(&msg, skt->skt, (i == n)?last_flag:ZMQ_SNDMORE);
    zmq_msg_close(&msg);
    if(-1 == ret){
      ret = luazmq_fail(L, skt);
      lua_pushinteger(L, i);
      return ret + 1;
    }
  }
  return luazmq_pass(L);
}

static int luazmq_skt_sendv_impl(lua_State *L, int flags) {
  zsocket *skt = luazmq_getsocket(L);
  size_t i, size = 0, top = lua_gettop(L);
  zmq_msg_t msg;
  int ret;

  for(i = 2; i<=top; ++i){
    size_t s;
    luaL_checklstring(L,i,&s);
    size += s;
  }

  if (0 == size){
    ret = zmq_msg_init(&msg);
  }
  else {
    ret = zmq_msg_init_size(&msg, size);
  }
  if(-1 == ret) return luazmq_fail(L, skt);

  {
    size_t pos;
    for(pos = 0, i = 2; i<=top; ++i){
      const char *data = luaL_checklstring(L,i,&size);
      memcpy((char*)zmq_msg_data(&msg) + pos, data, size);
      pos += size;
    }
  }

  ret = zmq_msg_send(&msg, skt->skt, flags);
  zmq_msg_close(&msg);

  if(-1 == ret) return luazmq_fail(L, skt);
  return luazmq_pass(L);

}

static int luazmq_skt_sendx(lua_State *L){
  return luazmq_skt_sendx_impl(L, 0);
}

static int luazmq_skt_sendx_more(lua_State *L){
  return luazmq_skt_sendx_impl(L, ZMQ_SNDMORE);
}

static int luazmq_skt_sendv(lua_State *L){
  return luazmq_skt_sendv_impl(L, 0);
}

static int luazmq_skt_sendv_more(lua_State *L){
  return luazmq_skt_sendv_impl(L, ZMQ_SNDMORE);
}

static int luazmq_skt_recv_all (lua_State *L) {
  zsocket *skt = luazmq_getsocket(L);
  zmq_msg_t msg;
  int flags = luaL_optint(L,2,0);
  int i = 0;
  int result_index = lua_gettop(L) + 1;
  lua_newtable(L);
  while(1){
    int ret = zmq_msg_init(&msg);
    if(-1 == ret){
      ret = luazmq_fail(L, skt);
      lua_pushvalue(L,result_index);
      return ret + 1;
    }
      
    ret = zmq_msg_recv(&msg, skt->skt, flags);
    if(-1 == ret){
      ret = luazmq_fail(L, skt);
      zmq_msg_close(&msg);
      lua_pushvalue(L,result_index);
      return ret + 1;
    }

    lua_pushlstring(L, zmq_msg_data(&msg), zmq_msg_size(&msg));
    lua_rawseti(L, result_index, ++i);
    ret = zmq_msg_more(&msg);
    zmq_msg_close(&msg);
    if(!ret) break;
  }
  return 1;
}

static int luazmq_skt_recvx (lua_State *L) {
  zsocket *skt = luazmq_getsocket(L);
  zmq_msg_t msg;
  int flags = luaL_optint(L,2,0);
  int i = 0;
  lua_settop(L, 1);

  while(1){
    int ret = zmq_msg_init(&msg);
    if(-1 == ret){
      ret = luazmq_fail(L, skt);
      {int j;for(j = ret; j >= 0; --j){
        lua_insert(L, 1);
      }}
      return ret + i;
    }

    ret = zmq_msg_recv(&msg, skt->skt, flags);
    if(-1 == ret){
      zmq_msg_close(&msg);
      ret = luazmq_fail(L, skt);
      {int j;for(j = ret; j >= 0; --j){
        lua_insert(L, 1);
      }}
      return ret + i;
    }

    i++;
    lua_checkstack(L, i);
    lua_pushlstring(L, zmq_msg_data(&msg), zmq_msg_size(&msg));
    ret = zmq_msg_more(&msg);
    zmq_msg_close(&msg);
    if(!ret) break;
  }
  return i;
}

static int luazmq_skt_poll (lua_State *L) {
  zsocket *skt = luazmq_getsocket(L);
  int timeout  = luaL_optint(L, 2, -1);
  int mask     = luaL_optint(L, 3, ZMQ_POLLIN);
  zmq_pollitem_t items [] = { { skt->skt, 0, mask, 0 } };

  if(-1 == zmq_poll (items, 1, timeout)){
    return luazmq_fail(L, skt);
  }

  lua_pushboolean(L, (items[0].revents & mask)?1:0);
  lua_pushinteger(L, items[0].revents);
  return 2;
}

static int luazmq_skt_monitor (lua_State *L) {
  zsocket *skt = luazmq_getsocket(L);
  char endpoint[128];
  const char *bind;
  int ret, events;

  
  if( 
    (lua_gettop(L) == 1) ||         /* s:monitor()          */
    (lua_type(L, 2) == LUA_TNUMBER) /* s:monitor(EVENT_ALL) */
  ){
#ifdef _MSC_VER
    sprintf_s(endpoint, sizeof(endpoint), "inproc://lzmq.monitor.%p", skt->skt);
#else
    sprintf(endpoint, "inproc://lzmq.monitor.%p", skt->skt);
#endif
    bind = endpoint;
    events = luaL_optint(L, 2, ZMQ_EVENT_ALL);
  }
  else{
    bind = luaL_checkstring(L, 2);
    events = luaL_optint(L, 3, ZMQ_EVENT_ALL);
  }

  ret = zmq_socket_monitor (skt->skt, bind, events);
  if(-1 == ret){
    return luazmq_fail(L, skt);
  }

  lua_pushstring(L, bind);
  return 1;
}

static int luazmq_skt_reset_monitor (lua_State *L) {
  zsocket *skt = luazmq_getsocket(L);
  int ret = zmq_socket_monitor (skt->skt, NULL, 0);
  if(-1 == ret){
    return luazmq_fail(L, skt);
  }

  return luazmq_pass(L);
}

static int luazmq_skt_context (lua_State *L) {
  zsocket *skt = luazmq_getsocket(L);
  lua_rawgeti(L, LUAZMQ_LUA_REGISTRY, skt->ctx_ref);
  return 1;
}

static int luazmq_skt_handle (lua_State *L) {
  zsocket *skt = luazmq_getsocket(L);
  lua_pushlightuserdata(L, skt->skt);
  return 1;
}

static int luazmq_skt_reset_handle(lua_State *L) {
  zsocket *skt = luazmq_getsocket(L);
  void *src = lua_touserdata(L, 2);
  int own   =  lua_isnoneornil(L, 3) ? 
    ((skt->flags & LUAZMQ_FLAG_DONT_DESTROY)?0:1) :
    lua_toboolean(L, 3);
  int close = lua_toboolean(L, 4);
  void *h   = skt->skt;

  luaL_argcheck(L, lua_islightuserdata(L, 2), 2, "lightuserdata expected");

  skt->skt = src;
  if(own) skt->flags &= ~LUAZMQ_FLAG_DONT_DESTROY;
  else    skt->flags |=  LUAZMQ_FLAG_DONT_DESTROY;

  if(close){
    zmq_close(h);
    lua_pushboolean(L, 1);
  }
  else{
    lua_pushlightuserdata(L, h);
  }

  return 1;
}

int luazmq_skt_before_close (lua_State *L, zsocket *skt) {
  luaL_unref(L, LUAZMQ_LUA_REGISTRY, skt->ctx_ref);
  skt->ctx_ref = LUA_NOREF;

  if(LUA_NOREF == skt->onclose_ref) return 0;
  lua_rawgeti(L, LUAZMQ_LUA_REGISTRY, skt->onclose_ref);

  lua_pcall(L, 0, 0, 0);

  luaL_unref(L, LUAZMQ_LUA_REGISTRY, skt->onclose_ref);
  skt->onclose_ref = LUA_NOREF;
  return 0;
}

static int luazmq_skt_on_close (lua_State *L) {
  zsocket *skt = luazmq_getsocket(L);
  lua_settop(L, 2);
  if(LUA_NOREF != skt->onclose_ref){
    if(lua_isnil(L, 2)){
      luaL_unref(L, LUAZMQ_LUA_REGISTRY, skt->onclose_ref);
      skt->onclose_ref = LUA_NOREF;
      return 0;
    }
  }
  skt->onclose_ref = luaL_ref(L, LUAZMQ_LUA_REGISTRY);
  return 0;
}

static int luazmq_skt_destroy (lua_State *L) {
  zsocket *skt = (zsocket *)luazmq_checkudatap (L, 1, LUAZMQ_SOCKET);
  luaL_argcheck (L, skt != NULL, 1, LUAZMQ_PREFIX"socket expected");
  if(!(skt->flags & LUAZMQ_FLAG_CLOSED)){
    int ret;
    luazmq_skt_before_close(L, skt);
    if(!(skt->flags & LUAZMQ_FLAG_DONT_DESTROY)){
      if(lua_isnumber(L, 2)){
        int linger = luaL_optint(L, 2, 0);
        zmq_setsockopt(skt->skt, ZMQ_LINGER, &linger, sizeof(linger));
      }
      ret = zmq_close(skt->skt);
      assert(ret != -1);
      // if(ret == -1)return luazmq_fail(L, skt);
    }

#if LZMQ_SOCKET_COUNT
    if(skt->ctx){
      skt->ctx->socket_count--;
      assert(skt->ctx->socket_count >= 0);
    }
#endif

    skt->flags |= LUAZMQ_FLAG_CLOSED;
  }
  return luazmq_pass(L);
}

static int luazmq_skt_closed (lua_State *L) {
  zsocket *skt = (zsocket *)luazmq_checkudatap (L, 1, LUAZMQ_SOCKET);
  luaL_argcheck (L, skt != NULL, 1, LUAZMQ_PREFIX"socket expected");
  lua_pushboolean(L, skt->flags & LUAZMQ_FLAG_CLOSED);
  return 1;
}

static const char* luazmq_skt_type_name(int typ){
  switch(typ){
#ifdef ZMQ_PAIR
    case ZMQ_PAIR:    {static const char *name = "PAIR"; return name;}
#endif
#ifdef ZMQ_PUB
    case ZMQ_PUB:     {static const char *name = "PUB"; return name;}
#endif
#ifdef ZMQ_SUB
    case ZMQ_SUB:     {static const char *name = "SUB"; return name;}
#endif
#ifdef ZMQ_REQ
    case ZMQ_REQ:     {static const char *name = "REQ"; return name;}
#endif
#ifdef ZMQ_REP
    case ZMQ_REP:     {static const char *name = "REP"; return name;}
#endif
#ifdef ZMQ_DEALER
    case ZMQ_DEALER:  {static const char *name = "DEALER"; return name;}
#endif
#ifdef ZMQ_ROUTER
    case ZMQ_ROUTER:  {static const char *name = "ROUTER"; return name;}
#endif
#ifdef ZMQ_PULL
    case ZMQ_PULL:    {static const char *name = "PULL"; return name;}
#endif
#ifdef ZMQ_PUSH
    case ZMQ_PUSH:    {static const char *name = "PUSH"; return name;}
#endif
#ifdef ZMQ_XPUB
    case ZMQ_XPUB:    {static const char *name = "XPUB"; return name;}
#endif
#ifdef ZMQ_XSUB
    case ZMQ_XSUB:    {static const char *name = "XSUB"; return name;}
#endif
#ifdef ZMQ_STREAM
    case ZMQ_STREAM:  {static const char *name = "STREAM"; return name;}
#endif
#ifdef ZMQ_SERVER
    case ZMQ_SERVER:  {static const char *name = "SERVER"; return name;}
#endif
#ifdef ZMQ_CLIENT
    case ZMQ_CLIENT:  {static const char *name = "CLIENT"; return name;}
#endif
#ifdef ZMQ_RADIO
    case ZMQ_RADIO:   {static const char *name = "RADIO"; return name;}
#endif
#ifdef ZMQ_DISH
    case ZMQ_DISH:    {static const char *name = "DISH"; return name;}
#endif
#ifdef ZMQ_GATHER
    case ZMQ_GATHER:  {static const char *name = "GATHER"; return name;}
#endif
#ifdef ZMQ_SCATTER
    case ZMQ_SCATTER: {static const char *name = "SCATTER"; return name;}
#endif
#ifdef ZMQ_DGRAM
    case ZMQ_DGRAM:   {static const char *name = "DGRAM"; return name;}
#endif
  }
  return NULL;
}

static int luazmq_skt_tostring (lua_State *L) {
  zsocket *skt = (zsocket *)luazmq_checkudatap (L, 1, LUAZMQ_SOCKET);
  luaL_argcheck (L, skt != NULL, 1, LUAZMQ_PREFIX"socket expected");
  if(skt->flags & LUAZMQ_FLAG_CLOSED){
    lua_pushfstring(L, LUAZMQ_PREFIX"Socket[-1] (%p) - closed", skt);
  }
  else{
    int typ; size_t len = sizeof(typ);
    int rc = zmq_getsockopt(skt->skt, ZMQ_TYPE, &typ, &len);
    const char *name = NULL;
    if (rc != -1) {
      name = luazmq_skt_type_name(typ);
      if(name){
        lua_pushfstring(L, LUAZMQ_PREFIX"Socket[%s] (%p)", name, skt);
      }
      else{
        lua_pushfstring(L, LUAZMQ_PREFIX"Socket[%d] (%p)", typ, skt);
      }
    }
    else{
      lua_pushfstring(L, LUAZMQ_PREFIX"Socket[-1] (%p)", skt);
    }
  }
  return 1;
}

static int luazmq_skt_has_event (lua_State *L) {
  zsocket *skt = luazmq_getsocket(L);
  int i, top = lua_gettop(L);
  int option_value; size_t len = sizeof(option_value);
  int ret = zmq_getsockopt(skt->skt, ZMQ_EVENTS, &option_value, &len);
  if (ret == -1) return luazmq_fail(L, skt);

  luaL_checkint(L, 2); /* we need at least one event */

  for(i = 2; i <= top; ++i){
    lua_pushboolean(L, option_value & luaL_checkint(L, i));
    lua_replace(L, i);
  }

  return top - 1;
}

static int luazmq_skt_set_int (lua_State *L, int option_name) {
  zsocket *skt = luazmq_getsocket(L);
  int option_value = luaL_checkint(L, 2);
  int ret = zmq_setsockopt(skt->skt, option_name, &option_value, sizeof(option_value));
  if (ret == -1) return luazmq_fail(L, skt);
  return luazmq_pass(L);
}

static int luazmq_skt_set_u64 (lua_State *L, int option_name) {
  zsocket *skt = luazmq_getsocket(L);
  uint64_t option_value = (uint64_t)luaL_checknumber(L, 2);
  int ret = zmq_setsockopt(skt->skt, option_name, &option_value, sizeof(option_value));
  if (ret == -1) return luazmq_fail(L, skt);
  return luazmq_pass(L);
}

static int luazmq_skt_set_i64 (lua_State *L, int option_name) {
  zsocket *skt = luazmq_getsocket(L);
  int64_t option_value = (int64_t)luaL_checknumber(L, 2);
  int ret = zmq_setsockopt(skt->skt, option_name, &option_value, sizeof(option_value));
  if (ret == -1) return luazmq_fail(L, skt);
  return luazmq_pass(L);
}

static int luazmq_skt_set_str (lua_State *L, int option_name) {
  zsocket *skt = luazmq_getsocket(L);
  size_t len;
  const char *option_value = luaL_checklstring(L, 2, &len);
  int ret = zmq_setsockopt(skt->skt, option_name, option_value, len);
  if (ret == -1) return luazmq_fail(L, skt);
  return luazmq_pass(L);
}

static int luazmq_skt_get_int (lua_State *L, int option_name) {
  zsocket *skt = luazmq_getsocket(L);
  int option_value; size_t len = sizeof(option_value);
  int ret = zmq_getsockopt(skt->skt, option_name, &option_value, &len);
  if (ret == -1) return luazmq_fail(L, skt);
  lua_pushinteger(L, option_value);
  return 1;
}

static int luazmq_skt_get_fdt (lua_State *L, int option_name) {
  /** @fixme return lightuserdata because of SOCKET has 64 bit
   * on Windows x64.
   */
  zsocket *skt = luazmq_getsocket(L);
  int ret;
  fd_t option_value; 

#if defined(ZMQ_IDENTITY_FD)
  if(option_name == ZMQ_IDENTITY_FD){
    char buffer[255];
    size_t len; const char *id = luaL_checklstring(L, 2, &len);
    luaL_argcheck(L, len <= sizeof(buffer), 2, "identity too big");

    memcpy(buffer, id, len);
    ret = zmq_getsockopt(skt->skt, option_name, buffer, &len);
    memcpy(&option_value, buffer, sizeof(option_value));
  }
  else
#endif
  {
    size_t len = sizeof(option_value);
    ret = zmq_getsockopt(skt->skt, option_name, &option_value, &len);
  }

  if (ret == -1) return luazmq_fail(L, skt);
  luazmq_push_os_socket(L, option_value);
  return 1;
}

static int luazmq_skt_set_fdt (lua_State *L, int option_name) {
  zsocket *skt = luazmq_getsocket(L);
  fd_t option_value = luazmq_check_os_socket(L, 2, "file descriptor expected");
  int ret;
  ret = zmq_setsockopt(skt->skt, option_name, &option_value, sizeof(option_value));
  if (ret == -1) return luazmq_fail(L, skt);
  return luazmq_pass(L);
}

static int luazmq_skt_get_u64 (lua_State *L, int option_name) {
  zsocket *skt = luazmq_getsocket(L);
  uint64_t option_value;  size_t len = sizeof(option_value);
  int ret = zmq_getsockopt(skt->skt, option_name, &option_value, &len);
  if (ret == -1) return luazmq_fail(L, skt);
  lua_pushnumber(L, (lua_Number)option_value);
  return 1;
}

static int luazmq_skt_get_i64 (lua_State *L, int option_name) {
  zsocket *skt = luazmq_getsocket(L);
  int64_t option_value;  size_t len = sizeof(option_value);
  int ret = zmq_getsockopt(skt->skt, option_name, &option_value, &len);
  if (ret == -1) return luazmq_fail(L, skt);
  lua_pushnumber(L, (lua_Number)option_value);
  return 1;
}

static int luazmq_skt_get_str (lua_State *L, int option_name) {
  zsocket *skt = luazmq_getsocket(L);
  char option_value[255]; size_t len = sizeof(option_value);
  int ret = zmq_getsockopt(skt->skt, option_name, option_value, &len);
  if (ret == -1) return luazmq_fail(L, skt);
  lua_pushlstring(L, option_value, len);
  return 1;
}

static int luazmq_skt_set_str_arr (lua_State *L, int option_name) {
  zsocket *skt;
  size_t len, tlen, i;
  const char *option_value;
  int ret;

  if(!lua_istable(L, 2)) return luazmq_skt_set_str(L, option_name);

  skt = luazmq_getsocket(L);
  tlen = lua_objlen(L,2);
  for (i = 1; i <= tlen; i++){
    lua_rawgeti(L, 2, i);
    option_value = luaL_checklstring(L, -1, &len);
    ret = zmq_setsockopt(skt->skt, option_name, option_value, len);
    if (ret == -1){
      int n = luazmq_fail(L, skt);
      lua_pushnumber(L, i);
      return n + 1;
    }
  }
  return luazmq_pass(L);
}

#define DEFINE_SKT_OPT_WO(NAME, OPTNAME, TYPE) \
  static int luazmq_skt_set_##NAME(lua_State *L){return luazmq_skt_set_##TYPE(L, OPTNAME);}

#define DEFINE_SKT_OPT_RO(NAME, OPTNAME, TYPE) \
  static int luazmq_skt_get_##NAME(lua_State *L){return luazmq_skt_get_##TYPE(L, OPTNAME);}

#define DEFINE_SKT_OPT_RW(NAME, OPTNAME, TYPE) \
  DEFINE_SKT_OPT_WO(NAME, OPTNAME, TYPE) \
  DEFINE_SKT_OPT_RO(NAME, OPTNAME, TYPE)


#define REGISTER_SKT_OPT_WO(NAME) {"set_"#NAME, luazmq_skt_set_##NAME},{#NAME, luazmq_skt_set_##NAME}
#define REGISTER_SKT_OPT_RO(NAME) {"get_"#NAME, luazmq_skt_get_##NAME},{#NAME, luazmq_skt_get_##NAME}
#define REGISTER_SKT_OPT_RW(NAME) {"set_"#NAME, luazmq_skt_set_##NAME},{"get_"#NAME, luazmq_skt_get_##NAME}

//{ options

#if defined(ZMQ_AFFINITY)
  DEFINE_SKT_OPT_RW(affinity,                 ZMQ_AFFINITY,                       u64       )
#endif
#if defined(ZMQ_IDENTITY)
  DEFINE_SKT_OPT_RW(identity,                 ZMQ_IDENTITY,                       str       )
#endif
#if defined(ZMQ_SUBSCRIBE)
  DEFINE_SKT_OPT_WO(subscribe,                ZMQ_SUBSCRIBE,                      str_arr   )
#endif
#if defined(ZMQ_UNSUBSCRIBE)
  DEFINE_SKT_OPT_WO(unsubscribe,              ZMQ_UNSUBSCRIBE,                    str_arr   )
#endif
#if defined(ZMQ_RATE)
  DEFINE_SKT_OPT_RW(rate,                     ZMQ_RATE,                           int       )
#endif
#if defined(ZMQ_RECOVERY_IVL)
  DEFINE_SKT_OPT_RW(recovery_ivl,             ZMQ_RECOVERY_IVL,                   int       )
#endif
#if defined(ZMQ_SNDBUF)
  DEFINE_SKT_OPT_RW(sndbuf,                   ZMQ_SNDBUF,                         int       )
#endif
#if defined(ZMQ_RCVBUF)
  DEFINE_SKT_OPT_RW(rcvbuf,                   ZMQ_RCVBUF,                         int       )
#endif
#if defined(ZMQ_RCVMORE)
  DEFINE_SKT_OPT_RO(rcvmore,                  ZMQ_RCVMORE,                        int       )
#endif
#if defined(ZMQ_FD)
  DEFINE_SKT_OPT_RO(fd,                       ZMQ_FD,                             fdt       )
#endif
#if defined(ZMQ_EVENTS)
  DEFINE_SKT_OPT_RO(events,                   ZMQ_EVENTS,                         int       )
#endif
#if defined(ZMQ_TYPE)
  DEFINE_SKT_OPT_RO(type,                     ZMQ_TYPE,                           int       )
#endif
#if defined(ZMQ_LINGER)
  DEFINE_SKT_OPT_RW(linger,                   ZMQ_LINGER,                         int       )
#endif
#if defined(ZMQ_RECONNECT_IVL)
  DEFINE_SKT_OPT_RW(reconnect_ivl,            ZMQ_RECONNECT_IVL,                  int       )
#endif
#if defined(ZMQ_BACKLOG)
  DEFINE_SKT_OPT_RW(backlog,                  ZMQ_BACKLOG,                        int       )
#endif
#if defined(ZMQ_RECONNECT_IVL_MAX)
  DEFINE_SKT_OPT_RW(reconnect_ivl_max,        ZMQ_RECONNECT_IVL_MAX,              int       )
#endif
#if defined(ZMQ_MAXMSGSIZE)
  DEFINE_SKT_OPT_RW(maxmsgsize,               ZMQ_MAXMSGSIZE,                     i64       )
#endif
#if defined(ZMQ_SNDHWM)
  DEFINE_SKT_OPT_RW(sndhwm,                   ZMQ_SNDHWM,                         int       )
#endif
#if defined(ZMQ_RCVHWM)
  DEFINE_SKT_OPT_RW(rcvhwm,                   ZMQ_RCVHWM,                         int       )
#endif
#if defined(ZMQ_MULTICAST_HOPS)
  DEFINE_SKT_OPT_RW(multicast_hops,           ZMQ_MULTICAST_HOPS,                 int       )
#endif
#if defined(ZMQ_RCVTIMEO)
  DEFINE_SKT_OPT_RW(rcvtimeo,                 ZMQ_RCVTIMEO,                       int       )
#endif
#if defined(ZMQ_SNDTIMEO)
  DEFINE_SKT_OPT_RW(sndtimeo,                 ZMQ_SNDTIMEO,                       int       )
#endif
#if defined(ZMQ_IPV4ONLY)
  DEFINE_SKT_OPT_RW(ipv4only,                 ZMQ_IPV4ONLY,                       int       )
#endif
#if defined(ZMQ_LAST_ENDPOINT)
  DEFINE_SKT_OPT_RO(last_endpoint,            ZMQ_LAST_ENDPOINT,                  str       )
#endif
#if defined(ZMQ_ROUTER_MANDATORY)
  DEFINE_SKT_OPT_WO(router_mandatory,         ZMQ_ROUTER_MANDATORY,               int       )
#endif
#if defined(ZMQ_TCP_KEEPALIVE)
  DEFINE_SKT_OPT_RW(tcp_keepalive,            ZMQ_TCP_KEEPALIVE,                  int       )
#endif
#if defined(ZMQ_TCP_KEEPALIVE_CNT)
  DEFINE_SKT_OPT_RW(tcp_keepalive_cnt,        ZMQ_TCP_KEEPALIVE_CNT,              int       )
#endif
#if defined(ZMQ_TCP_KEEPALIVE_IDLE)
  DEFINE_SKT_OPT_RW(tcp_keepalive_idle,       ZMQ_TCP_KEEPALIVE_IDLE,             int       )
#endif
#if defined(ZMQ_TCP_KEEPALIVE_INTVL)
  DEFINE_SKT_OPT_RW(tcp_keepalive_intvl,      ZMQ_TCP_KEEPALIVE_INTVL,            int       )
#endif
#if defined(ZMQ_TCP_ACCEPT_FILTER)
  DEFINE_SKT_OPT_WO(tcp_accept_filter,        ZMQ_TCP_ACCEPT_FILTER,              str_arr   )
#endif
#if defined(ZMQ_IMMEDIATE)
  DEFINE_SKT_OPT_RW(immediate,                ZMQ_IMMEDIATE,                      int       )
#endif
#if defined(ZMQ_DELAY_ATTACH_ON_CONNECT)
  DEFINE_SKT_OPT_RW(delay_attach_on_connect,  ZMQ_DELAY_ATTACH_ON_CONNECT,        int       )
#endif
#if defined(ZMQ_XPUB_VERBOSE)
  DEFINE_SKT_OPT_RW(xpub_verbose,             ZMQ_XPUB_VERBOSE,                   int       )
#endif
#if defined(ZMQ_ROUTER_RAW)
  DEFINE_SKT_OPT_RW(router_raw,               ZMQ_ROUTER_RAW,                     int       )
#endif
#if defined(ZMQ_IPV6)
  DEFINE_SKT_OPT_RW(ipv6,                     ZMQ_IPV6,                           int       )
#endif
#if defined(ZMQ_MECHANISM)
  DEFINE_SKT_OPT_RO(mechanism,                ZMQ_MECHANISM,                      int       )
#endif
#if defined(ZMQ_PLAIN_SERVER)
  DEFINE_SKT_OPT_RW(plain_server,             ZMQ_PLAIN_SERVER,                   int       )
#endif
#if defined(ZMQ_PLAIN_USERNAME)
  DEFINE_SKT_OPT_RW(plain_username,           ZMQ_PLAIN_USERNAME,                 str       )
#endif
#if defined(ZMQ_PLAIN_PASSWORD)
  DEFINE_SKT_OPT_RW(plain_password,           ZMQ_PLAIN_PASSWORD,                 str       )
#endif
#if defined(ZMQ_CURVE_SERVER)
  DEFINE_SKT_OPT_RW(curve_server,             ZMQ_CURVE_SERVER,                   int       )
#endif
#if defined(ZMQ_CURVE_PUBLICKEY)
  DEFINE_SKT_OPT_RW(curve_publickey,          ZMQ_CURVE_PUBLICKEY,                str       )
#endif
#if defined(ZMQ_CURVE_SECRETKEY)
  DEFINE_SKT_OPT_RW(curve_secretkey,          ZMQ_CURVE_SECRETKEY,                str       )
#endif
#if defined(ZMQ_CURVE_SERVERKEY)
  DEFINE_SKT_OPT_RW(curve_serverkey,          ZMQ_CURVE_SERVERKEY,                str       )
#endif
#if defined(ZMQ_PROBE_ROUTER)
  DEFINE_SKT_OPT_WO(probe_router,             ZMQ_PROBE_ROUTER,                   int       )
#endif
#if defined(ZMQ_REQ_CORRELATE)
  DEFINE_SKT_OPT_WO(req_correlate,            ZMQ_REQ_CORRELATE,                  int       )
#endif
#if defined(ZMQ_REQ_RELAXED)
  DEFINE_SKT_OPT_WO(req_relaxed,              ZMQ_REQ_RELAXED,                    int       )
#endif
#if defined(ZMQ_CONFLATE)
  DEFINE_SKT_OPT_WO(conflate,                 ZMQ_CONFLATE,                       int       )
#endif
#if defined(ZMQ_ZAP_DOMAIN)
  DEFINE_SKT_OPT_RW(zap_domain,               ZMQ_ZAP_DOMAIN,                     str       )
#endif
#if defined(ZMQ_ROUTER_HANDOVER)
  DEFINE_SKT_OPT_WO(router_handover,          ZMQ_ROUTER_HANDOVER,                int       )
#endif
#if defined(ZMQ_TOS)
  DEFINE_SKT_OPT_RW(tos,                      ZMQ_TOS,                            int       )
#endif
#if defined(ZMQ_IPC_FILTER_PID)
  DEFINE_SKT_OPT_WO(ipc_filter_pid,           ZMQ_IPC_FILTER_PID,                 int       )
#endif
#if defined(ZMQ_IPC_FILTER_UID)
  DEFINE_SKT_OPT_WO(ipc_filter_uid,           ZMQ_IPC_FILTER_UID,                 int       )
#endif
#if defined(ZMQ_IPC_FILTER_GID)
  DEFINE_SKT_OPT_WO(ipc_filter_gid,           ZMQ_IPC_FILTER_GID,                 int       )
#endif
#if defined(ZMQ_CONNECT_RID)
  DEFINE_SKT_OPT_WO(connect_rid,              ZMQ_CONNECT_RID,                    str       )
#endif
#if defined(ZMQ_GSSAPI_SERVER)
  DEFINE_SKT_OPT_RW(gssapi_server,            ZMQ_GSSAPI_SERVER,                  int       )
#endif
#if defined(ZMQ_GSSAPI_PRINCIPAL)
  DEFINE_SKT_OPT_RW(gssapi_principal,         ZMQ_GSSAPI_PRINCIPAL,               str       )
#endif
#if defined(ZMQ_GSSAPI_SERVICE_PRINCIPAL)
  DEFINE_SKT_OPT_RW(gssapi_service_principal, ZMQ_GSSAPI_SERVICE_PRINCIPAL,       str       )
#endif
#if defined(ZMQ_GSSAPI_PLAINTEXT)
  DEFINE_SKT_OPT_RW(gssapi_plaintext,         ZMQ_GSSAPI_PLAINTEXT,               str       )
#endif
#if defined(ZMQ_HANDSHAKE_IVL)
  DEFINE_SKT_OPT_RW(handshake_ivl,            ZMQ_HANDSHAKE_IVL,                  int       )
#endif
#if defined(ZMQ_IDENTITY_FD)
  DEFINE_SKT_OPT_RO(identity_fd,              ZMQ_IDENTITY_FD,                    fdt       )
#endif
#if defined(ZMQ_SOCKS_PROXY)
  DEFINE_SKT_OPT_RW(socks_proxy,              ZMQ_SOCKS_PROXY,                    str       )
#endif
#if defined(ZMQ_XPUB_NODROP)
  DEFINE_SKT_OPT_WO(xpub_nodrop,              ZMQ_XPUB_NODROP,                    int       )
#endif
#if defined(ZMQ_BLOCKY)
  DEFINE_SKT_OPT_RW(blocky,                   ZMQ_BLOCKY,                         int       )
#endif
#if defined(ZMQ_XPUB_MANUAL)
  DEFINE_SKT_OPT_WO(xpub_manual,              ZMQ_XPUB_MANUAL,                    int       )
#endif
#if defined(ZMQ_XPUB_WELCOME_MSG)
  DEFINE_SKT_OPT_WO(xpub_welcome_msg,         ZMQ_XPUB_WELCOME_MSG,               str       )
#endif
#if defined(ZMQ_STREAM_NOTIFY)
  DEFINE_SKT_OPT_WO(stream_notify,            ZMQ_STREAM_NOTIFY,                  int       )
#endif
#if defined(ZMQ_INVERT_MATCHING)
  DEFINE_SKT_OPT_RW(invert_matching,          ZMQ_INVERT_MATCHING,                int       )
#endif
#if defined(ZMQ_HEARTBEAT_IVL)
  DEFINE_SKT_OPT_WO(heartbeat_ivl,            ZMQ_HEARTBEAT_IVL,                  int       )
#endif
#if defined(ZMQ_HEARTBEAT_TTL)
  DEFINE_SKT_OPT_WO(heartbeat_ttl,            ZMQ_HEARTBEAT_TTL,                  int       )
#endif
#if defined(ZMQ_HEARTBEAT_TIMEOUT)
  DEFINE_SKT_OPT_WO(heartbeat_timeout,        ZMQ_HEARTBEAT_TIMEOUT,              int       )
#endif
#if defined(ZMQ_XPUB_VERBOSER)
  DEFINE_SKT_OPT_WO(xpub_verboser,            ZMQ_XPUB_VERBOSER,                  int       )
#endif
#if defined(ZMQ_CONNECT_TIMEOUT)
  DEFINE_SKT_OPT_RW(connect_timeout,          ZMQ_CONNECT_TIMEOUT,                int       )
#endif
#if defined(ZMQ_TCP_MAXRT)
  DEFINE_SKT_OPT_RW(tcp_maxrt,                ZMQ_TCP_MAXRT,                      int       )
#endif
#if defined(ZMQ_THREAD_SAFE)
  DEFINE_SKT_OPT_RO(thread_safe,              ZMQ_THREAD_SAFE,                    int       )
#endif
#if defined(ZMQ_MULTICAST_MAXTPDU)
  DEFINE_SKT_OPT_RW(multicast_maxtpdu,        ZMQ_MULTICAST_MAXTPDU,              int       )
#endif
#if defined(ZMQ_VMCI_BUFFER_SIZE)
  DEFINE_SKT_OPT_RW(vmci_buffer_size,         ZMQ_VMCI_BUFFER_SIZE,               u64       )
#endif
#if defined(ZMQ_VMCI_BUFFER_MIN_SIZE)
  DEFINE_SKT_OPT_RW(vmci_buffer_min_size,     ZMQ_VMCI_BUFFER_MIN_SIZE,           u64       )
#endif
#if defined(ZMQ_VMCI_BUFFER_MAX_SIZE)
  DEFINE_SKT_OPT_RW(vmci_buffer_max_size,     ZMQ_VMCI_BUFFER_MAX_SIZE,           u64       )
#endif
#if defined(ZMQ_VMCI_CONNECT_TIMEOUT)
  DEFINE_SKT_OPT_RW(vmci_connect_timeout,     ZMQ_VMCI_CONNECT_TIMEOUT,           int       )
#endif
#if defined(ZMQ_USE_FD)
  DEFINE_SKT_OPT_RW(use_fd,                   ZMQ_USE_FD,                         fdt       )
#endif

//}

static int luazmq_skt_getopt_int(lua_State *L){ return luazmq_skt_get_int(L, luaL_checkint(L,2)); }
static int luazmq_skt_getopt_i64(lua_State *L){ return luazmq_skt_get_i64(L, luaL_checkint(L,2)); }
static int luazmq_skt_getopt_u64(lua_State *L){ return luazmq_skt_get_u64(L, luaL_checkint(L,2)); }
static int luazmq_skt_getopt_str(lua_State *L){
  int optname = luaL_checkint(L,2);
  lua_remove(L, 2);
  return luazmq_skt_get_str(L,  optname);
}

static int luazmq_skt_setopt_int(lua_State *L){ return luazmq_skt_set_int(L, luaL_checkint(L,2)); }
static int luazmq_skt_setopt_i64(lua_State *L){ return luazmq_skt_set_i64(L, luaL_checkint(L,2)); }
static int luazmq_skt_setopt_u64(lua_State *L){ return luazmq_skt_set_u64(L, luaL_checkint(L,2)); }
static int luazmq_skt_setopt_str(lua_State *L){ return luazmq_skt_set_str(L, luaL_checkint(L,2)); }

static const struct luaL_Reg luazmq_skt_methods[] = {
  {"bind",           luazmq_skt_bind         },
  {"unbind",         luazmq_skt_unbind       },
  {"connect",        luazmq_skt_connect      },
  {"disconnect",     luazmq_skt_disconnect   },
  {"poll",           luazmq_skt_poll         },
  {"send",           luazmq_skt_send         },
  {"send_msg",       luazmq_skt_send_msg     },
  {"sendx",          luazmq_skt_sendx        },
  {"sendx_more",     luazmq_skt_sendx_more   },
  {"sendv",          luazmq_skt_sendv        },
  {"sendv_more",     luazmq_skt_sendv_more   },
  {"send_more",      luazmq_skt_send_more    },
  {"recv",           luazmq_skt_recv         },
  {"recvx",          luazmq_skt_recvx        },
  {"recv_msg",       luazmq_skt_recv_msg     },
  {"recv_new_msg",   luazmq_skt_recv_new_msg },
  {"recv_len",       luazmq_skt_recv_len     },
  {"recv_event",     luazmq_skt_recv_event   },
  {"send_all",       luazmq_skt_send_all     },
  {"recv_all",       luazmq_skt_recv_all     },
  {"send_multipart", luazmq_skt_send_all     },
  {"recv_multipart", luazmq_skt_recv_all     },
  {"more",           luazmq_skt_more         },
  {"monitor",        luazmq_skt_monitor      },
  {"reset_monitor",  luazmq_skt_reset_monitor},
  {"handle",         luazmq_skt_handle       },
  {"reset_handle",   luazmq_skt_reset_handle },
  {"lightuserdata",  luazmq_skt_handle       },
  {"context",        luazmq_skt_context      },
  {"bind_to_random_port", luazmq_skt_bind_to_random_port},

  {"has_event",      luazmq_skt_has_event    },

  {"getopt_int",     luazmq_skt_getopt_int   },
  {"getopt_i64",     luazmq_skt_getopt_i64   },
  {"getopt_u64",     luazmq_skt_getopt_u64   },
  {"getopt_str",     luazmq_skt_getopt_str   },
  {"setopt_int",     luazmq_skt_setopt_int   },
  {"setopt_i64",     luazmq_skt_setopt_i64   },
  {"setopt_u64",     luazmq_skt_setopt_u64   },
  {"setopt_str",     luazmq_skt_setopt_str   },

  {"__tostring",     luazmq_skt_tostring     },
  {"on_close",       luazmq_skt_on_close     },
  {"__gc",           luazmq_skt_destroy      },
  {"close",          luazmq_skt_destroy      },
  {"closed",         luazmq_skt_closed       },

  //{ options
#if defined(ZMQ_AFFINITY)
  REGISTER_SKT_OPT_RW(affinity                  ),
#endif
#if defined(ZMQ_IDENTITY)
  REGISTER_SKT_OPT_RW(identity                  ),
#endif
#if defined(ZMQ_SUBSCRIBE)
  REGISTER_SKT_OPT_WO(subscribe                 ),
#endif
#if defined(ZMQ_UNSUBSCRIBE)
  REGISTER_SKT_OPT_WO(unsubscribe               ),
#endif
#if defined(ZMQ_RATE)
  REGISTER_SKT_OPT_RW(rate                      ),
#endif
#if defined(ZMQ_RECOVERY_IVL)
  REGISTER_SKT_OPT_RW(recovery_ivl              ),
#endif
#if defined(ZMQ_SNDBUF)
  REGISTER_SKT_OPT_RW(sndbuf                    ),
#endif
#if defined(ZMQ_RCVBUF)
  REGISTER_SKT_OPT_RW(rcvbuf                    ),
#endif
#if defined(ZMQ_RCVMORE)
  REGISTER_SKT_OPT_RO(rcvmore                   ),
#endif
#if defined(ZMQ_FD)
  REGISTER_SKT_OPT_RO(fd                        ),
#endif
#if defined(ZMQ_EVENTS)
  REGISTER_SKT_OPT_RO(events                    ),
#endif
#if defined(ZMQ_TYPE)
  REGISTER_SKT_OPT_RO(type                      ),
#endif
#if defined(ZMQ_LINGER)
  REGISTER_SKT_OPT_RW(linger                    ),
#endif
#if defined(ZMQ_RECONNECT_IVL)
  REGISTER_SKT_OPT_RW(reconnect_ivl             ),
#endif
#if defined(ZMQ_BACKLOG)
  REGISTER_SKT_OPT_RW(backlog                   ),
#endif
#if defined(ZMQ_RECONNECT_IVL_MAX)
  REGISTER_SKT_OPT_RW(reconnect_ivl_max         ),
#endif
#if defined(ZMQ_MAXMSGSIZE)
  REGISTER_SKT_OPT_RW(maxmsgsize                ),
#endif
#if defined(ZMQ_SNDHWM)
  REGISTER_SKT_OPT_RW(sndhwm                    ),
#endif
#if defined(ZMQ_RCVHWM)
  REGISTER_SKT_OPT_RW(rcvhwm                    ),
#endif
#if defined(ZMQ_MULTICAST_HOPS)
  REGISTER_SKT_OPT_RW(multicast_hops            ),
#endif
#if defined(ZMQ_RCVTIMEO)
  REGISTER_SKT_OPT_RW(rcvtimeo                  ),
#endif
#if defined(ZMQ_SNDTIMEO)
  REGISTER_SKT_OPT_RW(sndtimeo                  ),
#endif
#if defined(ZMQ_IPV4ONLY)
  REGISTER_SKT_OPT_RW(ipv4only                  ),
#endif
#if defined(ZMQ_LAST_ENDPOINT)
  REGISTER_SKT_OPT_RO(last_endpoint             ),
#endif
#if defined(ZMQ_ROUTER_MANDATORY)
  REGISTER_SKT_OPT_WO(router_mandatory          ),
#endif
#if defined(ZMQ_TCP_KEEPALIVE)
  REGISTER_SKT_OPT_RW(tcp_keepalive             ),
#endif
#if defined(ZMQ_TCP_KEEPALIVE_CNT)
  REGISTER_SKT_OPT_RW(tcp_keepalive_cnt         ),
#endif
#if defined(ZMQ_TCP_KEEPALIVE_IDLE)
  REGISTER_SKT_OPT_RW(tcp_keepalive_idle        ),
#endif
#if defined(ZMQ_TCP_KEEPALIVE_INTVL)
  REGISTER_SKT_OPT_RW(tcp_keepalive_intvl       ),
#endif
#if defined(ZMQ_TCP_ACCEPT_FILTER)
  REGISTER_SKT_OPT_WO(tcp_accept_filter         ),
#endif
#if defined(ZMQ_IMMEDIATE)
  REGISTER_SKT_OPT_RW(immediate                 ),
#endif
#if defined(ZMQ_DELAY_ATTACH_ON_CONNECT)
  REGISTER_SKT_OPT_RW(delay_attach_on_connect   ),
#endif
#if defined(ZMQ_XPUB_VERBOSE)
  REGISTER_SKT_OPT_RW(xpub_verbose              ),
#endif
#if defined(ZMQ_ROUTER_RAW)
  REGISTER_SKT_OPT_RW(router_raw                ),
#endif
#if defined(ZMQ_IPV6)
  REGISTER_SKT_OPT_RW(ipv6                      ),
#endif
#if defined(ZMQ_MECHANISM)
  REGISTER_SKT_OPT_RO(mechanism                 ),
#endif
#if defined(ZMQ_PLAIN_SERVER)
  REGISTER_SKT_OPT_RW(plain_server              ),
#endif
#if defined(ZMQ_PLAIN_USERNAME)
  REGISTER_SKT_OPT_RW(plain_username            ),
#endif
#if defined(ZMQ_PLAIN_PASSWORD)
  REGISTER_SKT_OPT_RW(plain_password            ),
#endif
#if defined(ZMQ_CURVE_SERVER)
  REGISTER_SKT_OPT_RW(curve_server              ),
#endif
#if defined(ZMQ_CURVE_PUBLICKEY)
  REGISTER_SKT_OPT_RW(curve_publickey           ),
#endif
#if defined(ZMQ_CURVE_SECRETKEY)
  REGISTER_SKT_OPT_RW(curve_secretkey           ),
#endif
#if defined(ZMQ_CURVE_SERVERKEY)
  REGISTER_SKT_OPT_RW(curve_serverkey           ),
#endif
#if defined(ZMQ_PROBE_ROUTER)
  REGISTER_SKT_OPT_WO(probe_router              ),
#endif
#if defined(ZMQ_REQ_CORRELATE)
  REGISTER_SKT_OPT_WO(req_correlate             ),
#endif
#if defined(ZMQ_REQ_RELAXED)
  REGISTER_SKT_OPT_WO(req_relaxed               ),
#endif
#if defined(ZMQ_CONFLATE)
  REGISTER_SKT_OPT_WO(conflate                  ),
#endif
#if defined(ZMQ_ZAP_DOMAIN)
  REGISTER_SKT_OPT_RW(zap_domain                ),
#endif
#if defined(ZMQ_ROUTER_HANDOVER)
  REGISTER_SKT_OPT_WO(router_handover           ),
#endif
#if defined(ZMQ_TOS)
  REGISTER_SKT_OPT_RW(tos                       ),
#endif
#if defined(ZMQ_IPC_FILTER_PID)
  REGISTER_SKT_OPT_WO(ipc_filter_pid            ),
#endif
#if defined(ZMQ_IPC_FILTER_UID)
  REGISTER_SKT_OPT_WO(ipc_filter_uid            ),
#endif
#if defined(ZMQ_IPC_FILTER_GID)
  REGISTER_SKT_OPT_WO(ipc_filter_gid            ),
#endif
#if defined(ZMQ_CONNECT_RID)
  REGISTER_SKT_OPT_WO(connect_rid               ),
#endif
#if defined(ZMQ_GSSAPI_SERVER)
  REGISTER_SKT_OPT_RW(gssapi_server             ),
#endif
#if defined(ZMQ_GSSAPI_PRINCIPAL)
  REGISTER_SKT_OPT_RW(gssapi_principal          ),
#endif
#if defined(ZMQ_GSSAPI_SERVICE_PRINCIPAL)
  REGISTER_SKT_OPT_RW(gssapi_service_principal  ),
#endif
#if defined(ZMQ_GSSAPI_PLAINTEXT)
  REGISTER_SKT_OPT_RW(gssapi_plaintext          ),
#endif
#if defined(ZMQ_HANDSHAKE_IVL)
  REGISTER_SKT_OPT_RW(handshake_ivl             ),
#endif
#if defined(ZMQ_IDENTITY_FD)
  REGISTER_SKT_OPT_RO(identity_fd               ),
#endif
#if defined(ZMQ_SOCKS_PROXY)
  REGISTER_SKT_OPT_RW(socks_proxy               ),
#endif
#if defined(ZMQ_XPUB_NODROP)
  REGISTER_SKT_OPT_WO(xpub_nodrop               ),
#endif
#if defined(ZMQ_BLOCKY)
  REGISTER_SKT_OPT_RW(blocky                    ),
#endif
#if defined(ZMQ_XPUB_MANUAL)
  REGISTER_SKT_OPT_WO(xpub_manual               ),
#endif
#if defined(ZMQ_XPUB_WELCOME_MSG)
  REGISTER_SKT_OPT_WO(xpub_welcome_msg          ),
#endif
#if defined(ZMQ_STREAM_NOTIFY)
  REGISTER_SKT_OPT_WO(stream_notify             ),
#endif
#if defined(ZMQ_INVERT_MATCHING)
  REGISTER_SKT_OPT_RW(invert_matching           ),
#endif
#if defined(ZMQ_HEARTBEAT_IVL)
  REGISTER_SKT_OPT_WO(heartbeat_ivl             ),
#endif
#if defined(ZMQ_HEARTBEAT_TTL)
  REGISTER_SKT_OPT_WO(heartbeat_ttl             ),
#endif
#if defined(ZMQ_HEARTBEAT_TIMEOUT)
  REGISTER_SKT_OPT_WO(heartbeat_timeout         ),
#endif
#if defined(ZMQ_XPUB_VERBOSER)
  REGISTER_SKT_OPT_WO(xpub_verboser             ),
#endif
#if defined(ZMQ_CONNECT_TIMEOUT)
  REGISTER_SKT_OPT_RW(connect_timeout           ),
#endif
#if defined(ZMQ_TCP_MAXRT)
  REGISTER_SKT_OPT_RW(tcp_maxrt                 ),
#endif
#if defined(ZMQ_THREAD_SAFE)
  REGISTER_SKT_OPT_RO(thread_safe               ),
#endif
#if defined(ZMQ_MULTICAST_MAXTPDU)
  REGISTER_SKT_OPT_RW(multicast_maxtpdu         ),
#endif
#if defined(ZMQ_VMCI_BUFFER_SIZE)
  REGISTER_SKT_OPT_RW(vmci_buffer_size          ),
#endif
#if defined(ZMQ_VMCI_BUFFER_MIN_SIZE)
  REGISTER_SKT_OPT_RW(vmci_buffer_min_size      ),
#endif
#if defined(ZMQ_VMCI_BUFFER_MAX_SIZE)
  REGISTER_SKT_OPT_RW(vmci_buffer_max_size      ),
#endif
#if defined(ZMQ_VMCI_CONNECT_TIMEOUT)
  REGISTER_SKT_OPT_RW(vmci_connect_timeout      ),
#endif
#if defined(ZMQ_USE_FD)
  REGISTER_SKT_OPT_RW(use_fd                    ),
#endif
  //}

  {NULL,NULL}
};

static const luazmq_int_const skt_types[] ={
  DEFINE_ZMQ_CONST(  PAIR   ),
  DEFINE_ZMQ_CONST(  PUB    ),
  DEFINE_ZMQ_CONST(  SUB    ),
  DEFINE_ZMQ_CONST(  REQ    ),
  DEFINE_ZMQ_CONST(  REP    ),
  DEFINE_ZMQ_CONST(  DEALER ),
  DEFINE_ZMQ_CONST(  ROUTER ),
  DEFINE_ZMQ_CONST(  PULL   ),
  DEFINE_ZMQ_CONST(  PUSH   ),
  DEFINE_ZMQ_CONST(  XPUB   ),
  DEFINE_ZMQ_CONST(  XSUB   ),
  DEFINE_ZMQ_CONST(  XREQ   ),
  DEFINE_ZMQ_CONST(  XREP   ),

#ifdef ZMQ_STREAM
  DEFINE_ZMQ_CONST(  STREAM ),
#endif

  {NULL, 0}
};

static const luazmq_int_const skt_options[] ={
#if defined(ZMQ_AFFINITY)
  DEFINE_ZMQ_CONST(AFFINITY                  ),
#endif
#if defined(ZMQ_IDENTITY)
  DEFINE_ZMQ_CONST(IDENTITY                  ),
#endif
#if defined(ZMQ_SUBSCRIBE)
  DEFINE_ZMQ_CONST(SUBSCRIBE                 ),
#endif
#if defined(ZMQ_UNSUBSCRIBE)
  DEFINE_ZMQ_CONST(UNSUBSCRIBE               ),
#endif
#if defined(ZMQ_RATE)
  DEFINE_ZMQ_CONST(RATE                      ),
#endif
#if defined(ZMQ_RECOVERY_IVL)
  DEFINE_ZMQ_CONST(RECOVERY_IVL              ),
#endif
#if defined(ZMQ_SNDBUF)
  DEFINE_ZMQ_CONST(SNDBUF                    ),
#endif
#if defined(ZMQ_RCVBUF)
  DEFINE_ZMQ_CONST(RCVBUF                    ),
#endif
#if defined(ZMQ_RCVMORE)
  DEFINE_ZMQ_CONST(RCVMORE                   ),
#endif
#if defined(ZMQ_FD)
  DEFINE_ZMQ_CONST(FD                        ),
#endif
#if defined(ZMQ_EVENTS)
  DEFINE_ZMQ_CONST(EVENTS                    ),
#endif
#if defined(ZMQ_TYPE)
  DEFINE_ZMQ_CONST(TYPE                      ),
#endif
#if defined(ZMQ_LINGER)
  DEFINE_ZMQ_CONST(LINGER                    ),
#endif
#if defined(ZMQ_RECONNECT_IVL)
  DEFINE_ZMQ_CONST(RECONNECT_IVL             ),
#endif
#if defined(ZMQ_BACKLOG)
  DEFINE_ZMQ_CONST(BACKLOG                   ),
#endif
#if defined(ZMQ_RECONNECT_IVL_MAX)
  DEFINE_ZMQ_CONST(RECONNECT_IVL_MAX         ),
#endif
#if defined(ZMQ_MAXMSGSIZE)
  DEFINE_ZMQ_CONST(MAXMSGSIZE                ),
#endif
#if defined(ZMQ_SNDHWM)
  DEFINE_ZMQ_CONST(SNDHWM                    ),
#endif
#if defined(ZMQ_RCVHWM)
  DEFINE_ZMQ_CONST(RCVHWM                    ),
#endif
#if defined(ZMQ_MULTICAST_HOPS)
  DEFINE_ZMQ_CONST(MULTICAST_HOPS            ),
#endif
#if defined(ZMQ_RCVTIMEO)
  DEFINE_ZMQ_CONST(RCVTIMEO                  ),
#endif
#if defined(ZMQ_SNDTIMEO)
  DEFINE_ZMQ_CONST(SNDTIMEO                  ),
#endif
#if defined(ZMQ_IPV4ONLY)
  DEFINE_ZMQ_CONST(IPV4ONLY                  ),
#endif
#if defined(ZMQ_LAST_ENDPOINT)
  DEFINE_ZMQ_CONST(LAST_ENDPOINT             ),
#endif
#if defined(ZMQ_ROUTER_MANDATORY)
  DEFINE_ZMQ_CONST(ROUTER_MANDATORY          ),
#endif
#if defined(ZMQ_TCP_KEEPALIVE)
  DEFINE_ZMQ_CONST(TCP_KEEPALIVE             ),
#endif
#if defined(ZMQ_TCP_KEEPALIVE_CNT)
  DEFINE_ZMQ_CONST(TCP_KEEPALIVE_CNT         ),
#endif
#if defined(ZMQ_TCP_KEEPALIVE_IDLE)
  DEFINE_ZMQ_CONST(TCP_KEEPALIVE_IDLE        ),
#endif
#if defined(ZMQ_TCP_KEEPALIVE_INTVL)
  DEFINE_ZMQ_CONST(TCP_KEEPALIVE_INTVL       ),
#endif
#if defined(ZMQ_TCP_ACCEPT_FILTER)
  DEFINE_ZMQ_CONST(TCP_ACCEPT_FILTER         ),
#endif
#if defined(ZMQ_IMMEDIATE)
  DEFINE_ZMQ_CONST(IMMEDIATE                 ),
#endif
#if defined(ZMQ_DELAY_ATTACH_ON_CONNECT)
  DEFINE_ZMQ_CONST(DELAY_ATTACH_ON_CONNECT   ),
#endif
#if defined(ZMQ_XPUB_VERBOSE)
  DEFINE_ZMQ_CONST(XPUB_VERBOSE              ),
#endif
#if defined(ZMQ_ROUTER_RAW)
  DEFINE_ZMQ_CONST(ROUTER_RAW                ),
#endif
#if defined(ZMQ_IPV6)
  DEFINE_ZMQ_CONST(IPV6                      ),
#endif
#if defined(ZMQ_MECHANISM)
  DEFINE_ZMQ_CONST(MECHANISM                 ),
#endif
#if defined(ZMQ_PLAIN_SERVER)
  DEFINE_ZMQ_CONST(PLAIN_SERVER              ),
#endif
#if defined(ZMQ_PLAIN_USERNAME)
  DEFINE_ZMQ_CONST(PLAIN_USERNAME            ),
#endif
#if defined(ZMQ_PLAIN_PASSWORD)
  DEFINE_ZMQ_CONST(PLAIN_PASSWORD            ),
#endif
#if defined(ZMQ_CURVE_SERVER)
  DEFINE_ZMQ_CONST(CURVE_SERVER              ),
#endif
#if defined(ZMQ_CURVE_PUBLICKEY)
  DEFINE_ZMQ_CONST(CURVE_PUBLICKEY           ),
#endif
#if defined(ZMQ_CURVE_SECRETKEY)
  DEFINE_ZMQ_CONST(CURVE_SECRETKEY           ),
#endif
#if defined(ZMQ_CURVE_SERVERKEY)
  DEFINE_ZMQ_CONST(CURVE_SERVERKEY           ),
#endif
#if defined(ZMQ_PROBE_ROUTER)
  DEFINE_ZMQ_CONST(PROBE_ROUTER              ),
#endif
#if defined(ZMQ_REQ_CORRELATE)
  DEFINE_ZMQ_CONST(REQ_CORRELATE             ),
#endif
#if defined(ZMQ_REQ_RELAXED)
  DEFINE_ZMQ_CONST(REQ_RELAXED               ),
#endif
#if defined(ZMQ_CONFLATE)
  DEFINE_ZMQ_CONST(CONFLATE                  ),
#endif
#if defined(ZMQ_ZAP_DOMAIN)
  DEFINE_ZMQ_CONST(ZAP_DOMAIN                ),
#endif
#if defined(ZMQ_ROUTER_HANDOVER)
  DEFINE_ZMQ_CONST(ROUTER_HANDOVER           ),
#endif
#if defined(ZMQ_TOS)
  DEFINE_ZMQ_CONST(TOS                       ),
#endif
#if defined(ZMQ_IPC_FILTER_PID)
  DEFINE_ZMQ_CONST(IPC_FILTER_PID            ),
#endif
#if defined(ZMQ_IPC_FILTER_UID)
  DEFINE_ZMQ_CONST(IPC_FILTER_UID            ),
#endif
#if defined(ZMQ_IPC_FILTER_GID)
  DEFINE_ZMQ_CONST(IPC_FILTER_GID            ),
#endif
#if defined(ZMQ_CONNECT_RID)
  DEFINE_ZMQ_CONST(CONNECT_RID               ),
#endif
#if defined(ZMQ_GSSAPI_SERVER)
  DEFINE_ZMQ_CONST(GSSAPI_SERVER             ),
#endif
#if defined(ZMQ_GSSAPI_PRINCIPAL)
  DEFINE_ZMQ_CONST(GSSAPI_PRINCIPAL          ),
#endif
#if defined(ZMQ_GSSAPI_SERVICE_PRINCIPAL)
  DEFINE_ZMQ_CONST(GSSAPI_SERVICE_PRINCIPAL  ),
#endif
#if defined(ZMQ_GSSAPI_PLAINTEXT)
  DEFINE_ZMQ_CONST(GSSAPI_PLAINTEXT          ),
#endif
#if defined(ZMQ_HANDSHAKE_IVL)
  DEFINE_ZMQ_CONST(HANDSHAKE_IVL             ),
#endif
#if defined(ZMQ_IDENTITY_FD)
  DEFINE_ZMQ_CONST(IDENTITY_FD               ),
#endif
#if defined(ZMQ_SOCKS_PROXY)
  DEFINE_ZMQ_CONST(SOCKS_PROXY               ),
#endif
#if defined(ZMQ_XPUB_NODROP)
  DEFINE_ZMQ_CONST(XPUB_NODROP               ),
#endif
#if defined(ZMQ_BLOCKY)
  DEFINE_ZMQ_CONST(BLOCKY                    ),
#endif
#if defined(ZMQ_XPUB_MANUAL)
  DEFINE_ZMQ_CONST(XPUB_MANUAL               ),
#endif
#if defined(ZMQ_XPUB_WELCOME_MSG)
  DEFINE_ZMQ_CONST(XPUB_WELCOME_MSG          ),
#endif
#if defined(ZMQ_STREAM_NOTIFY)
  DEFINE_ZMQ_CONST(STREAM_NOTIFY             ),
#endif
#if defined(ZMQ_INVERT_MATCHING)
  DEFINE_ZMQ_CONST(INVERT_MATCHING           ),
#endif
#if defined(ZMQ_HEARTBEAT_IVL)
  DEFINE_ZMQ_CONST(HEARTBEAT_IVL             ),
#endif
#if defined(ZMQ_HEARTBEAT_TTL)
  DEFINE_ZMQ_CONST(HEARTBEAT_TTL             ),
#endif
#if defined(ZMQ_HEARTBEAT_TIMEOUT)
  DEFINE_ZMQ_CONST(HEARTBEAT_TIMEOUT         ),
#endif
#if defined(ZMQ_XPUB_VERBOSER)
  DEFINE_ZMQ_CONST(XPUB_VERBOSER             ),
#endif
#if defined(ZMQ_CONNECT_TIMEOUT)
  DEFINE_ZMQ_CONST(CONNECT_TIMEOUT           ),
#endif
#if defined(ZMQ_TCP_MAXRT)
  DEFINE_ZMQ_CONST(TCP_MAXRT                 ),
#endif
#if defined(ZMQ_THREAD_SAFE)
  DEFINE_ZMQ_CONST(THREAD_SAFE               ),
#endif
#if defined(ZMQ_MULTICAST_MAXTPDU)
  DEFINE_ZMQ_CONST(MULTICAST_MAXTPDU         ),
#endif
#if defined(ZMQ_VMCI_BUFFER_SIZE)
  DEFINE_ZMQ_CONST(VMCI_BUFFER_SIZE          ),
#endif
#if defined(ZMQ_VMCI_BUFFER_MIN_SIZE)
  DEFINE_ZMQ_CONST(VMCI_BUFFER_MIN_SIZE      ),
#endif
#if defined(ZMQ_VMCI_BUFFER_MAX_SIZE)
  DEFINE_ZMQ_CONST(VMCI_BUFFER_MAX_SIZE      ),
#endif
#if defined(ZMQ_VMCI_CONNECT_TIMEOUT)
  DEFINE_ZMQ_CONST(VMCI_CONNECT_TIMEOUT      ),
#endif
#if defined(ZMQ_USE_FD)
  DEFINE_ZMQ_CONST(USE_FD                    ),
#endif
  {NULL, 0}
};

static const luazmq_int_const skt_flags[] ={
  DEFINE_ZMQ_CONST(  SNDMORE             ),
  DEFINE_ZMQ_CONST(  DONTWAIT            ),
#ifdef ZMQ_NOBLOCK
  DEFINE_ZMQ_CONST(  NOBLOCK             ),
#endif

  {NULL, 0}
};

static const luazmq_int_const skt_security_mechanism[] ={
#ifdef ZMQ_NULL
  DEFINE_ZMQ_CONST(  NULL             ),
#endif
#ifdef ZMQ_PLAIN
  DEFINE_ZMQ_CONST(  PLAIN            ),
#endif
#ifdef ZMQ_CURVE
  DEFINE_ZMQ_CONST(  CURVE           ),
#endif

  {NULL, 0}
};

void luazmq_socket_initlib (lua_State *L, int nup){
#ifdef LUAZMQ_DEBUG
  int top = lua_gettop(L);
#endif

  luazmq_createmeta(L, LUAZMQ_SOCKET, luazmq_skt_methods, nup);
  lua_pop(L, 1);

#ifdef LUAZMQ_DEBUG
  assert(top == (lua_gettop(L) + nup));
#endif

  luazmq_register_consts(L, skt_types);
  luazmq_register_consts(L, skt_options);
  luazmq_register_consts(L, skt_flags);
  luazmq_register_consts(L, skt_security_mechanism);
}
