/*
  Author: Alexey Melnichuk <mimir@newmail.ru>

  Copyright (C) 2013-2014 Alexey Melnichuk <mimir@newmail.ru>

  Licensed according to the included 'LICENCE' document

  This file is part of lua-lzqm library.
 */

#include "zpoller.h"
#include "poller.h"
#include "lzutils.h"
#include "lzmq.h"
#include <assert.h>

#define luazmq_check_socket(L, idx, zs, fd) \
  if (lua_isuserdata(L, idx) && !lua_islightuserdata(L, idx)) zs = luazmq_getsocket_at(L, idx);\
  else fd = (socket_t)luazmq_check_os_socket(L, idx, "number or ZMQ socket");

#define LUAZMQ_DEFAULT_POLLER_LEN 10

int luazmq_poller_create(lua_State *L){
  unsigned int n = luaL_optinteger(L,1,LUAZMQ_DEFAULT_POLLER_LEN);
  zpoller *poller = luazmq_newudata(L, zpoller, LUAZMQ_POLLER);
  poller_init(poller, n);
  if(!poller->items){
    lua_pushnil(L);
    lua_pushliteral(L, "memory allocation error");
    return 2;
  }
  return 1;
}

static int luazmq_plr_close(lua_State *L){
  zpoller *poller = (zpoller *)luazmq_checkudatap (L, 1, LUAZMQ_POLLER);
  luaL_argcheck (L, poller != NULL, 1, LUAZMQ_PREFIX"poller expected");
  if(poller->items) poller_cleanup(poller);
  return luazmq_pass(L);
}

static int luazmq_plr_closed (lua_State *L) {
  zpoller *poller = (zpoller *)luazmq_checkudatap (L, 1, LUAZMQ_POLLER);
  luaL_argcheck (L, poller != NULL, 1, LUAZMQ_PREFIX"poller expected");
  lua_pushboolean(L, poller->items == NULL);
  return 1;
}

/* method: add */
static int luazmq_plr_add(lua_State *L) {
  zpoller *poller = luazmq_getpoller(L);
  short events    = luaL_checkinteger(L,3);
  int idx = 0;
  zmq_pollitem_t *item;
  zsocket *sock = NULL;
  socket_t fd = 0;

  luazmq_check_socket(L, 2, sock, fd);

  idx = poller_get_free_item(poller);
  item = &(poller->items[idx]);
  item->socket = sock ? sock->skt : 0;
  item->fd = fd;
  item->events = events;

  lua_pushinteger(L, idx);
  return 1;
}

/* method: modify */
static int luazmq_plr_modify(lua_State *L){
  zpoller *poller = luazmq_getpoller(L);
  short events    = luaL_checkinteger(L,3);
  int idx = 0;
  zmq_pollitem_t *item;
  zsocket *sock = NULL;
  socket_t fd = 0;

  luazmq_check_socket(L, 2, sock, fd);

  if(sock)
    idx = poller_find_sock_item(poller, sock->skt);
  else
    idx = poller_find_fd_item(poller, fd);

  if(events != 0) {
    if(idx < 0) idx = poller_get_free_item(poller);
    item = &(poller->items[idx]);
    item->socket = sock->skt;
    item->fd = fd;
    item->events = events;
  } else if(idx >= 0) {
    /* no events remove socket/fd. */
    poller_remove_item(poller, idx);
  }

  lua_pushinteger(L, idx);
  return 1;
}

/* method: remove */
static int luazmq_plr_remove(lua_State *L) {
  zpoller *poller = luazmq_getpoller(L);
  int idx = 0;
  zsocket *sock = NULL;
  socket_t fd = 0;

  luazmq_check_socket(L, 2, sock, fd);

  if(sock)
    idx = poller_find_sock_item(poller, sock->skt);
  else
    idx = poller_find_fd_item(poller, fd);

  /* if sock/fd was found. */
  if(idx >= 0) {
    poller_remove_item(poller, idx);
  }

  lua_pushinteger(L, idx);
  return 1;
}

/* method: poll */
static int luazmq_plr_poll(lua_State *L) {
  zpoller *poller = luazmq_getpoller(L);
  long timeout = luaL_checkinteger(L,2);
  int err = poller_poll(poller, timeout);

  poller->next = (err > 0)?(poller->count-1):-1;
  if(-1 == err) {
    //err = zmq_errno();
    //if (err != ENOTSOCK)
      return luazmq_fail(L, NULL);
    //err = 1;
    //poller->next = 0;
  }

  assert(err >= 0); /* count of sockets*/

  lua_pushinteger(L, err); 
  return 1;
}

/* method: next_revents_idx */
static int luazmq_plr_next_revents_idx(lua_State *L) {
  zpoller *poller = luazmq_getpoller(L);
  int revents = 0;
  int idx = poller_next_revents(poller, &(revents));

  lua_pushinteger(L, idx);
  lua_pushinteger(L, revents);
  return 2;
}

/* method: count */
static int luazmq_plr_count(lua_State *L) {
  zpoller *poller = luazmq_getpoller(L);
  lua_pushinteger(L, poller->count);
  return 1;
}

static const struct luaL_Reg luazmq_plr_methods[] = {
  {"add",              luazmq_plr_add              },
  {"modify",           luazmq_plr_modify           },
  {"remove",           luazmq_plr_remove           },
  {"poll",             luazmq_plr_poll             },
  {"next_revents_idx", luazmq_plr_next_revents_idx },
  {"count",            luazmq_plr_count            },
  {"close",            luazmq_plr_close            },
  {"closed",           luazmq_plr_closed           },
  {"__gc",             luazmq_plr_close            },
  {NULL,NULL}
};

static const luazmq_int_const poll_flags[] ={
  DEFINE_ZMQ_CONST(  POLLIN   ),
  DEFINE_ZMQ_CONST(  POLLOUT  ),
  DEFINE_ZMQ_CONST(  POLLERR  ),

  {NULL, 0}
};


void luazmq_poller_initlib (lua_State *L, int nup){
#ifdef LUAZMQ_DEBUG
  int top = lua_gettop(L);
#endif

  luazmq_createmeta(L, LUAZMQ_POLLER,  luazmq_plr_methods, nup);
  lua_pop(L, 1);

#ifdef LUAZMQ_DEBUG
  assert(top == (lua_gettop(L) + nup));
#endif

  luazmq_register_consts(L, poll_flags);
}
