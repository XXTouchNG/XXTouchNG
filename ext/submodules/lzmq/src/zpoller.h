/*
  Author: Alexey Melnichuk <mimir@newmail.ru>

  Copyright (C) 2013-2014 Alexey Melnichuk <mimir@newmail.ru>

  Licensed according to the included 'LICENCE' document

  This file is part of lua-lzqm library.
 */

#ifndef _ZPOLLER_H_
#define _ZPOLLER_H_

#include "lua.h"

int luazmq_poller_create(lua_State *L);

void luazmq_poller_initlib (lua_State *L, int nup);

#endif
