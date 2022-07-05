/*
  Author: Alexey Melnichuk <mimir@newmail.ru>

  Copyright (C) 2013-2014 Alexey Melnichuk <mimir@newmail.ru>

  Licensed according to the included 'LICENCE' document

  This file is part of lua-lzqm library.
 */

#ifndef _ZMSG_H_
#define _ZMSG_H_

#include "lua.h"

int luazmq_msg_init(lua_State *L);

int luazmq_msg_init_size(lua_State *L);

int luazmq_msg_init_data(lua_State *L);

int luazmq_msg_init_data_multi(lua_State *L);

int luazmq_msg_init_data_array(lua_State *L);

int luazmq_msg_close(lua_State *L);


void luazmq_message_initlib(lua_State *L, int nup);
#endif
