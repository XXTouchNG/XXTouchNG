/*
  Author: Alexey Melnichuk <mimir@newmail.ru>

  Copyright (C) 2013-2014 Alexey Melnichuk <mimir@newmail.ru>

  Licensed according to the included 'LICENCE' document

  This file is part of lua-lzqm library.
 */

#ifndef _ZERROR_H_
#define _ZERROR_H_
#include "lua.h"

int luazmq_error_create(lua_State *L, int err);

void luazmq_error_pushstring(lua_State *L, int err);

int luazmq_assert (lua_State *L);

void luazmq_error_initlib(lua_State *L, int nup);

#endif
