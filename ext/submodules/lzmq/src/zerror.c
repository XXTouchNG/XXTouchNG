/*
  Author: Alexey Melnichuk <mimir@newmail.ru>

  Copyright (C) 2013-2014 Alexey Melnichuk <mimir@newmail.ru>

  Licensed according to the included 'LICENCE' document

  This file is part of lua-lzqm library.
 */

#include "zerror.h"
#include "lzutils.h"
#include "lzmq.h"
#include <assert.h>

static const char* luazmq_err_getmnemo(int err);

#define LZMQ_ERROR_CATEGORY "ZMQ"

int luazmq_error_create(lua_State *L, int err){
  zerror *zerr = luazmq_newudata(L, zerror, LUAZMQ_ERROR);
  zerr->no = err;
  return 1;
}

void luazmq_error_pushstring(lua_State *L, int err){
  lua_pushfstring(L, "[" LZMQ_ERROR_CATEGORY "]""[%s] %s (%d)",
    luazmq_err_getmnemo(err),
    zmq_strerror(err),
    err
  );
}

int luazmq_assert (lua_State *L) {
  if (!lua_toboolean(L, 1)){
    if(lua_type(L,2) == LUA_TNUMBER){
      luazmq_error_pushstring(L, lua_tointeger(L, 2));
      return lua_error(L);
    }
    if(luazmq_isudatap(L, 2, LUAZMQ_ERROR)){
      zerror *zerr = (zerror *)lua_touserdata(L, 2);
      luazmq_error_pushstring(L, zerr->no);
      return lua_error(L);
    }
    return luaL_error(L, "%s", luaL_optstring(L, 2, "assertion failed!"));
  }
  return lua_gettop(L);
}

static int luazmq_err_cat(lua_State *L){
  luazmq_geterror(L);
  lua_pushliteral(L, LZMQ_ERROR_CATEGORY);
  return 1;
}

static int luazmq_err_no(lua_State *L){
  zerror *zerr = luazmq_geterror(L);
  lua_pushinteger(L, zerr->no);
  return 1;
}

static int luazmq_err_msg(lua_State *L){
  zerror *zerr = luazmq_geterror(L);
  lua_pushstring(L, zmq_strerror(zerr->no));
  return 1;
}

static int luazmq_err_mnemo(lua_State *L){
  zerror *zerr = luazmq_geterror(L);
  lua_pushstring(L, luazmq_err_getmnemo(zerr->no));
  return 1;
}

static int luazmq_err_tostring(lua_State *L){
  zerror *zerr = luazmq_geterror(L);
  luazmq_error_pushstring(L, zerr->no);
  return 1;
}

static int luazmq_err_equal(lua_State *L){
  zerror *lhs = luazmq_geterror_at(L, 1);
  zerror *rhs = luazmq_geterror_at(L, 2);
  lua_pushboolean(L, (lhs->no == rhs->no)?1:0);
  return 1;
}

static const char* luazmq_err_getmnemo(int err){
#define RETURN_IF(E) case E: return #E;

  switch (err){
    RETURN_IF ( EFSM            );
    RETURN_IF ( ENOCOMPATPROTO  );
    RETURN_IF ( ETERM           );
    RETURN_IF ( EMTHREAD        );

    RETURN_IF ( ENOTSUP         );
    RETURN_IF ( EPROTONOSUPPORT );
    RETURN_IF ( ENOBUFS         );
    RETURN_IF ( ENETDOWN        );
    RETURN_IF ( EADDRINUSE      );
    RETURN_IF ( EADDRNOTAVAIL   );
    RETURN_IF ( ECONNREFUSED    );
    RETURN_IF ( EINPROGRESS     );
    RETURN_IF ( ENOTSOCK        );
    RETURN_IF ( EMSGSIZE        );
    RETURN_IF ( EAFNOSUPPORT    );
    RETURN_IF ( ENETUNREACH     );
    RETURN_IF ( ECONNABORTED    );
    RETURN_IF ( ECONNRESET      );
    RETURN_IF ( ENOTCONN        );
    RETURN_IF ( ETIMEDOUT       );
    RETURN_IF ( EHOSTUNREACH    );
    RETURN_IF ( ENETRESET       );

    RETURN_IF ( ENOENT          );
    RETURN_IF ( ESRCH           );
    RETURN_IF ( EINTR           );
    RETURN_IF ( EIO             );
    RETURN_IF ( ENXIO           );
    RETURN_IF ( E2BIG           );
    RETURN_IF ( ENOEXEC         );
    RETURN_IF ( EBADF           );
    RETURN_IF ( ECHILD          );
    RETURN_IF ( EAGAIN          );
    RETURN_IF ( ENOMEM          );
    RETURN_IF ( EACCES          );
    RETURN_IF ( EFAULT          );
    RETURN_IF ( EBUSY           );
    RETURN_IF ( EEXIST          );
    RETURN_IF ( EXDEV           );
    RETURN_IF ( ENODEV          );
    RETURN_IF ( ENOTDIR         );
    RETURN_IF ( EISDIR          );
    RETURN_IF ( ENFILE          );
    RETURN_IF ( EMFILE          );
    RETURN_IF ( ENOTTY          );
    RETURN_IF ( EFBIG           );
    RETURN_IF ( ENOSPC          );
    RETURN_IF ( ESPIPE          );
    RETURN_IF ( EROFS           );
    RETURN_IF ( EMLINK          );
    RETURN_IF ( EPIPE           );
    RETURN_IF ( EDOM            );
    RETURN_IF ( EDEADLK         );
    RETURN_IF ( ENAMETOOLONG    );
    RETURN_IF ( ENOLCK          );
    RETURN_IF ( ENOSYS          );
    RETURN_IF ( ENOTEMPTY       );
    RETURN_IF ( EINVAL          );
    RETURN_IF ( ERANGE          );
    RETURN_IF ( EILSEQ          );
  }
  return "UNKNOWN";

#undef RETURN_IF
}

static const struct luaL_Reg luazmq_err_methods[] = {
  {"no",              luazmq_err_no               },
  {"msg",             luazmq_err_msg              },
  {"mnemo",           luazmq_err_mnemo            },
  {"name",            luazmq_err_mnemo            },
  {"cat",             luazmq_err_cat              },
  {"category",        luazmq_err_cat              },
  {"__tostring",      luazmq_err_tostring         },
  {"__eq",            luazmq_err_equal            },

  {NULL,NULL}
};

static const luazmq_int_const zmq_err_codes[] ={
  DEFINE_INT_CONST ( EPERM        ),
  DEFINE_INT_CONST ( ENOENT       ),
  DEFINE_INT_CONST ( ESRCH        ),
  DEFINE_INT_CONST ( EINTR        ),
  DEFINE_INT_CONST ( EIO          ),
  DEFINE_INT_CONST ( ENXIO        ),
  DEFINE_INT_CONST ( E2BIG        ),
  DEFINE_INT_CONST ( ENOEXEC      ),
  DEFINE_INT_CONST ( EBADF        ),
  DEFINE_INT_CONST ( ECHILD       ),
  DEFINE_INT_CONST ( EAGAIN       ),
  DEFINE_INT_CONST ( ENOMEM       ),
  DEFINE_INT_CONST ( EACCES       ),
  DEFINE_INT_CONST ( EFAULT       ),
  DEFINE_INT_CONST ( EBUSY        ),
  DEFINE_INT_CONST ( EEXIST       ),
  DEFINE_INT_CONST ( EXDEV        ),
  DEFINE_INT_CONST ( ENODEV       ),
  DEFINE_INT_CONST ( ENOTDIR      ),
  DEFINE_INT_CONST ( EISDIR       ),
  DEFINE_INT_CONST ( ENFILE       ),
  DEFINE_INT_CONST ( EMFILE       ),
  DEFINE_INT_CONST ( ENOTTY       ),
  DEFINE_INT_CONST ( EFBIG        ),
  DEFINE_INT_CONST ( ENOSPC       ),
  DEFINE_INT_CONST ( ESPIPE       ),
  DEFINE_INT_CONST ( EROFS        ),
  DEFINE_INT_CONST ( EMLINK       ),
  DEFINE_INT_CONST ( EPIPE        ),
  DEFINE_INT_CONST ( EDOM         ),
  DEFINE_INT_CONST ( EDEADLK      ),
  DEFINE_INT_CONST ( ENAMETOOLONG ),
  DEFINE_INT_CONST ( ENOLCK       ),
  DEFINE_INT_CONST ( ENOSYS       ),
  DEFINE_INT_CONST ( ENOTEMPTY    ),
  DEFINE_INT_CONST ( EINVAL       ),
  DEFINE_INT_CONST ( ERANGE       ),
  DEFINE_INT_CONST ( EILSEQ       ),

  DEFINE_INT_CONST ( ENOTSUP              ),
  DEFINE_INT_CONST ( EPROTONOSUPPORT      ),
  DEFINE_INT_CONST ( ENOBUFS              ),
  DEFINE_INT_CONST ( ENETDOWN             ),
  DEFINE_INT_CONST ( EADDRINUSE           ),
  DEFINE_INT_CONST ( EADDRNOTAVAIL        ),
  DEFINE_INT_CONST ( ECONNREFUSED         ),
  DEFINE_INT_CONST ( EINPROGRESS          ),
  DEFINE_INT_CONST ( ENOTSOCK             ),
  DEFINE_INT_CONST ( EMSGSIZE             ),
  DEFINE_INT_CONST ( EAFNOSUPPORT         ),
  DEFINE_INT_CONST ( ENETUNREACH          ),
  DEFINE_INT_CONST ( ECONNABORTED         ),
  DEFINE_INT_CONST ( ECONNRESET           ),
  DEFINE_INT_CONST ( ENOTCONN             ),
  DEFINE_INT_CONST ( ETIMEDOUT            ),
  DEFINE_INT_CONST ( EHOSTUNREACH         ),
  DEFINE_INT_CONST ( ENETRESET            ),

  /*  Native 0MQ error codes.                 */
  DEFINE_INT_CONST ( EFSM                 ),
  DEFINE_INT_CONST ( ENOCOMPATPROTO       ),
  DEFINE_INT_CONST ( ETERM                ),
  DEFINE_INT_CONST ( EMTHREAD             ),

  {NULL, 0}
};

void luazmq_error_initlib(lua_State *L, int nup){
#ifdef LUAZMQ_DEBUG
  int top = lua_gettop(L);
#endif

  luazmq_createmeta(L, LUAZMQ_ERROR, luazmq_err_methods, nup);
  lua_pop(L, 1);

#ifdef LUAZMQ_DEBUG
  assert(top == (lua_gettop(L) + nup));
#endif

  luazmq_register_consts(L, zmq_err_codes);

  lua_newtable(L);
  luazmq_register_consts(L, zmq_err_codes);
  luazmq_register_consts_invers(L,zmq_err_codes);
  lua_setfield(L,-2, "errors");
}

