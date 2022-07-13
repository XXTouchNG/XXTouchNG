/******************************************************************************
* Author: Alexey Melnichuk <alexeymelnichuck@gmail.com>
*
* Copyright (C) 2014-2016 Alexey Melnichuk <alexeymelnichuck@gmail.com>
*
* Licensed according to the included 'LICENSE' document
*
* This file is part of lua-lluv library.
******************************************************************************/

#ifndef _LLUV_SIGNAL_H_
#define _LLUV_SIGNAL_H_

LLUV_INTERNAL void lluv_signal_initlib(lua_State *L, int nup, int safe);

LLUV_INTERNAL int lluv_signal_index(lua_State *L);

#endif
