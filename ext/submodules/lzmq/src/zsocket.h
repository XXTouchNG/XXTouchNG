/*
  Author: Alexey Melnichuk <mimir@newmail.ru>

  Copyright (C) 2013-2014 Alexey Melnichuk <mimir@newmail.ru>

  Licensed according to the included 'LICENCE' document

  This file is part of lua-lzqm library.
 */

#ifndef _ZSOCKET_H_
#define _ZSOCKET_H_

#include "lua.h"
#include "lzmq.h"

void luazmq_socket_initlib (lua_State *L, int nup);

int luazmq_skt_before_close (lua_State *L, zsocket *skt);

#endif
