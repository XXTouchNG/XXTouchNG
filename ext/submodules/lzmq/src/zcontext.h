/*
  Author: Alexey Melnichuk <mimir@newmail.ru>

  Copyright (C) 2013-2014 Alexey Melnichuk <mimir@newmail.ru>

  Licensed according to the included 'LICENCE' document

  This file is part of lua-lzqm library.
 */

#ifndef _ZCONTEXT_H_
#define _ZCONTEXT_H_

#include "lua.h"

int luazmq_context_create (lua_State *L);

int luazmq_context_init (lua_State *L);

int luazmq_init_ctx (lua_State *L);

void luazmq_context_initlib (lua_State *L, int nup);

#endif
