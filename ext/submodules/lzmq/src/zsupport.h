/*
  Author: Alexey Melnichuk <mimir@newmail.ru>

  Copyright (C) 2013-2014 Alexey Melnichuk <mimir@newmail.ru>

  Licensed according to the included 'LICENCE' document

  This file is part of lua-lzqm library.
 */

#ifndef _ZSUPPORT_H_
#define _ZSUPPORT_H_
#include "zmq.h"
#if ZMQ_VERSION < ZMQ_MAKE_VERSION(4,2,0)
#include "zmq_utils.h"
#endif

#if ZMQ_VERSION >= ZMQ_MAKE_VERSION(4,0,0)
#  define LUAZMQ_SUPPORT_Z85
#endif

#if ZMQ_VERSION >= ZMQ_MAKE_VERSION(4,0,0)
#  define LUAZMQ_SUPPORT_CTX_SHUTDOWN
#endif

#if ZMQ_VERSION >= ZMQ_MAKE_VERSION(3,2,3)
#  define LUAZMQ_SUPPORT_PROXY
#endif

#if ZMQ_VERSION >= ZMQ_MAKE_VERSION(4,0,1)
#  define LUAZMQ_SUPPORT_CURVE_KEYPAIR
#endif

#if ZMQ_VERSION >= ZMQ_MAKE_VERSION(4,0,5)
#  define LUAZMQ_SUPPORT_PROXY_STEERABLE
#endif

#if ZMQ_VERSION >= ZMQ_MAKE_VERSION(4,1,0)
#  define LUAZMQ_SUPPORT_MSG_GETS
#endif

#if ZMQ_VERSION >= ZMQ_MAKE_VERSION(4,2,2)
#  define LUAZMQ_SUPPORT_CURVE_PUBLIC
#endif

#endif
