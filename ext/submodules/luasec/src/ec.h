/*--------------------------------------------------------------------------
 * LuaSec 1.1.0
 *
 * Copyright (C) 2006-2022 Bruno Silvestre
 *
 *--------------------------------------------------------------------------*/

#ifndef LSEC_EC_H
#define LSEC_EC_H

#include <lua.h>

#ifndef OPENSSL_NO_EC
#include <openssl/ec.h>

EC_KEY *lsec_find_ec_key(lua_State *L, const char *str);
#endif

void lsec_get_curves(lua_State *L);
void lsec_load_curves(lua_State *L);

#endif
