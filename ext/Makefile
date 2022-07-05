TARGET := iphone:clang:latest:13.0
ARCHS = arm64  # these modules will be loaded to lua core only, arm64 is enough
# DEBUG = 0
# GO_EASY_ON_ME = 1


include $(THEOS)/makefiles/common.mk
TARGET_LIB_EXT = .so

LUA_MOD_MAKEFILE := $(shell git rev-parse --show-toplevel)/liblua/liblua.mk
include $(LUA_MOD_MAKEFILE)

LIBRARY_NAME = libzmq
LIBRARY_NAME += libev

LIBRARY_NAME += cjson
LIBRARY_NAME += lcurl
LIBRARY_NAME += lsqlite3
LIBRARY_NAME += lpeg
LIBRARY_NAME += unix
LIBRARY_NAME += posix
LIBRARY_NAME += spawn
LIBRARY_NAME += lfs
LIBRARY_NAME += iconv
LIBRARY_NAME += llthreads2
LIBRARY_NAME += luasec
LIBRARY_NAME += luasocket
LIBRARY_NAME += zlib
LIBRARY_NAME += xml
LIBRARY_NAME += zip
LIBRARY_NAME += archive
LIBRARY_NAME += minirsa
LIBRARY_NAME += openssl
LIBRARY_NAME += lzmq
LIBRARY_NAME += vararg
LIBRARY_NAME += pb
LIBRARY_NAME += lalien
LIBRARY_NAME += ev
LIBRARY_NAME += lterm
LIBRARY_NAME += sirocco
LIBRARY_NAME += libpdebug


libzmq_CFLAGS = -DTARGET_OS_IPHONE=1 -DNDEBUG -DLUA_COMPAT_5_1 -DLUA_COMPAT_5_2
libzmq_CFLAGS += -Wno-uninitialized -Wno-deprecated-declarations -Wno-tautological-overlap-compare
libzmq_CFLAGS += -D_DARWIN_C_SOURCE -D_REENTRANT -D_THREAD_SAFE -DZMQ_FORCE_KQUEUE -DHAVE_CONFIG_H
libzmq_CFLAGS += -Isubmodules/zeromq4/include/ -Isubmodules/zeromq4/src/
libzmq_LIBRARIES = pthread
libzmq_FILES = $(wildcard submodules/zeromq4/src/*.cpp)
libzmq_INSTALL_PATH = /usr/local/lib
libzmq_LIBRARY_EXTENSION = .dylib


libev_CFLAGS = -DTARGET_OS_IPHONE=1 -DNDEBUG -DLUA_COMPAT_5_1 -DLUA_COMPAT_5_2
libev_CFLAGS += -Wno-comment -Wno-extern-initializer -Wno-bitwise-op-parentheses -Wno-unused-function
libev_CFLAGS += -DHAVE_CONFIG_H
libev_CFLAGS += -Isubmodules/libev/src/ -Isubmodules/libev/
libev_FILES = submodules/libev/src/ev.c submodules/libev/src/event.c
libev_INSTALL_PATH = /usr/local/lib
libev_LIBRARY_EXTENSION = .dylib


lalien_CFLAGS = -DTARGET_OS_IPHONE=1 -DNDEBUG
lalien_CFLAGS += -fno-stack-protector -Wno-deprecated-declarations
lalien_CFLAGS += -I../liblua/
lalien_CFLAGS += -Isubmodules/alien/
lalien_CFLAGS += -Isubmodules/alien/include/
lalien_CFLAGS += -Isubmodules/alien/include/ffi/
lalien_CFLAGS += -Isubmodules/alien/src/
lalien_LDFLAGS = -Lsubmodules/alien/lib/
lalien_LDFLAGS += $(LUA_MOD_LDFLAGS)
lalien_LIBRARIES = ffi
lalien_FILES = submodules/alien/src/alien.c
lalien_INSTALL_PATH = /usr/local/xxtouch/lib
lalien_LIBRARY_EXTENSION = .dylib


cjson_CFLAGS = -DTARGET_OS_IPHONE=1 -DNDEBUG -DLUA_COMPAT_5_1 -DLUA_COMPAT_5_2
cjson_CFLAGS += -I../liblua/
cjson_CFLAGS += -Isubmodules/cjson/src/
cjson_LDFLAGS = $(LUA_MOD_LDFLAGS)
cjson_FILES = submodules/cjson/src/fpconv.c submodules/cjson/src/lua_cjson.c submodules/cjson/src/strbuf.c
cjson_INSTALL_PATH = /usr/local/xxtouch/lib


lcurl_CFLAGS = -Wno-unused-variable -Wno-unused-function -Wno-dangling-else -Wno-parentheses -Wno-void-pointer-to-int-cast
lcurl_CFLAGS += -DTARGET_OS_IPHONE=1 -DNDEBUG -DLUA_COMPAT_5_1 -DLUA_COMPAT_5_2
lcurl_CFLAGS += -I../liblua/
lcurl_CFLAGS += -Isubmodules/lcurl/src/
lcurl_CFLAGS += -Isubmodules/lcurl/include/
lcurl_LDFLAGS = -Lsubmodules/lcurl/lib/
lcurl_LDFLAGS += $(LUA_MOD_LDFLAGS)
lcurl_LIBRARIES = curl z nghttp2
lcurl_FRAMEWORKS = Security
lcurl_FILES = $(wildcard submodules/lcurl/src/*.c)
lcurl_INSTALL_PATH = /usr/local/xxtouch/lib


lsqlite3_CFLAGS = -Wno-unused-variable -Wno-ambiguous-macro -Wno-\#warnings
lsqlite3_CFLAGS += -DTARGET_OS_IPHONE=1 -DNDEBUG
lsqlite3_CFLAGS += -I../liblua/
lsqlite3_CFLAGS += -Isubmodules/lsqlite3/src/
lsqlite3_CFLAGS += -DLSQLITE_VERSION="\"0.9.5\""
lsqlite3_LDFLAGS = $(LUA_MOD_LDFLAGS)
lsqlite3_FILES = submodules/lsqlite3/src/lsqlite3.c submodules/lsqlite3/src/sqlite3.c
lsqlite3_INSTALL_PATH = /usr/local/xxtouch/lib


lpeg_CFLAGS = -DTARGET_OS_IPHONE=1 -DNDEBUG -DLUA_COMPAT_5_1 -DLUA_COMPAT_5_2
lpeg_CFLAGS += -I../liblua/
lpeg_CFLAGS += -Isubmodules/lpeg/src/
lpeg_LDFLAGS = $(LUA_MOD_LDFLAGS)
lpeg_FILES = $(wildcard submodules/lpeg/src/*.c)
lpeg_INSTALL_PATH = /usr/local/xxtouch/lib


unix_CFLAGS = -Wno-unused-variable -Wno-unused-function -Wno-unused-label -Wno-deprecated-declarations
unix_CFLAGS += -DTARGET_OS_IPHONE=1 -DNDEBUG -D__APPLE_USE_RFC_3542 -DLUA_COMPAT_5_1 -DLUA_COMPAT_5_2
unix_CFLAGS += -I../liblua/
unix_CFLAGS += -Isubmodules/lunix/src/
unix_LDFLAGS = $(LUA_MOD_LDFLAGS)
unix_FILES = $(wildcard submodules/lunix/src/*.c)
unix_INSTALL_PATH = /usr/local/xxtouch/lib


posix_CFLAGS = -Wno-unused-variable -Wno-unused-function -Wno-string-plus-int
posix_CFLAGS += -DTARGET_OS_IPHONE=1
posix_CFLAGS += -DPACKAGE="\"luaposix\"" -DVERSION="\"aa9b3ca204ce0602a1501a0a3e50809a2a590585\""
posix_CFLAGS += -D_DARWIN_C_SOURCE=1 -DNDEBUG=1 -D_FORTIFY_SOURCE=2
posix_CFLAGS += -DHAVE_SYS_MSG_H -DHAVE_MSGRCV -DHAVE_MSGSND -DHAVE_NET_IF_H -DHAVE_STATVFS -DHAVE_GETHOSTID
posix_CFLAGS += -I../liblua/
posix_CFLAGS += -Isubmodules/luaposix/ext/include/
posix_LDFLAGS = $(LUA_MOD_LDFLAGS)
posix_FILES = submodules/luaposix/ext/posix/posix.c
posix_INSTALL_PATH = /usr/local/xxtouch/lib/posix


spawn_CFLAGS = -DTARGET_OS_IPHONE=1 -DNDEBUG -DLUA_COMPAT_5_1 -DLUA_COMPAT_5_2
spawn_CFLAGS += -I../liblua/
spawn_CFLAGS += -Isubmodules/lua-spawn/spawn/
spawn_CFLAGS += -Isubmodules/lua-spawn/vendor/compat-5.3/c-api/
spawn_LDFLAGS = $(LUA_MOD_LDFLAGS)
spawn_FILES = $(wildcard submodules/lua-spawn/spawn/*.c) $(wildcard submodules/lua-spawn/vendor/compat-5.3/c-api/*.c)
spawn_INSTALL_PATH = /usr/local/xxtouch/lib/spawn


lfs_CFLAGS = -DTARGET_OS_IPHONE=1 -DNDEBUG -DLUA_COMPAT_5_1 -DLUA_COMPAT_5_2
lfs_CFLAGS += -I../liblua/
lfs_CFLAGS += -Isubmodules/luafilesystem/src/
lfs_LDFLAGS = $(LUA_MOD_LDFLAGS)
lfs_FILES = $(wildcard submodules/luafilesystem/src/*.c)
lfs_INSTALL_PATH = /usr/local/xxtouch/lib


iconv_CFLAGS = -DTARGET_OS_IPHONE=1 -DNDEBUG -DLUA_COMPAT_5_1 -DLUA_COMPAT_5_2
iconv_CFLAGS += -I../liblua/
iconv_CFLAGS += -Isubmodules/lua-iconv/src/
iconv_LDFLAGS = $(LUA_MOD_LDFLAGS)
iconv_LIBRARIES = iconv
iconv_FILES = submodules/lua-iconv/src/luaiconv.c
iconv_INSTALL_PATH = /usr/local/xxtouch/lib


llthreads2_CFLAGS = -DTARGET_OS_IPHONE=1 -DNDEBUG -DLUA_COMPAT_5_1 -DLUA_COMPAT_5_2
llthreads2_CFLAGS += -fno-common -Wno-unused-variable
llthreads2_CFLAGS += -I../liblua/
llthreads2_CFLAGS += -Isubmodules/lua-llthreads2/src/
llthreads2_LDFLAGS = $(LUA_MOD_LDFLAGS)
llthreads2_FILES = $(wildcard submodules/lua-llthreads2/src/*.c)
llthreads2_INSTALL_PATH = /usr/local/xxtouch/lib
llthreads2_LIBRARY_EXTENSION = .dylib


luasec_CFLAGS = -DTARGET_OS_IPHONE=1 -DNDEBUG -DLUA_COMPAT_5_1 -DLUA_COMPAT_5_2
luasec_CFLAGS += -fno-common
luasec_CFLAGS += -Wno-unused-variable -Wno-deprecated-declarations
luasec_CFLAGS += -Wno-int-conversion -Wno-incompatible-pointer-types-discards-qualifiers
luasec_CFLAGS += -I../liblua/
luasec_CFLAGS += -Isubmodules/luasec/src/
luasec_CFLAGS += -Isubmodules/minirsa/include/
luasec_LDFLAGS = -Lsubmodules/minirsa/lib/
luasec_LDFLAGS += $(LUA_MOD_LDFLAGS)
luasec_LIBRARIES = crypto ssl
luasec_FILES = $(filter-out submodules/luasec/src/luasocket/wsocket.c, $(wildcard submodules/luasec/src/luasocket/*.c))
luasec_FILES += $(wildcard submodules/luasec/src/*.c)
luasec_INSTALL_PATH = /usr/local/xxtouch/lib
luasec_LIBRARY_EXTENSION = .dylib


luasocket_CFLAGS = -DTARGET_OS_IPHONE=1 -DNDEBUG -DLUASOCKET_$(DEBUG) -DUNIX_HAS_SUN_LEN
luasocket_CFLAGS += -fno-common
luasocket_CFLAGS += -I../liblua/
luasocket_CFLAGS += -Isubmodules/luasocket/src/
luasocket_LDFLAGS = $(LUA_MOD_LDFLAGS)
luasocket_FILES = $(filter-out submodules/luasocket/src/wsocket.c, $(wildcard submodules/luasocket/src/*.c))
luasocket_INSTALL_PATH = /usr/local/xxtouch/lib
luasocket_LIBRARY_EXTENSION = .dylib


zlib_CFLAGS = -DTARGET_OS_IPHONE=1 -DNDEBUG -DLUA_COMPAT_5_1 -DLUA_COMPAT_5_2
zlib_CFLAGS += -fno-common
zlib_CFLAGS += -I../liblua/
zlib_LDFLAGS = $(LUA_MOD_LDFLAGS)
zlib_LIBRARIES = z
zlib_FILES = submodules/lua-zlib/src/lua_zlib.c
zlib_INSTALL_PATH = /usr/local/xxtouch/lib


xml_CFLAGS = -DTARGET_OS_IPHONE=1 -DNDEBUG -DLUA_COMPAT_5_1 -DLUA_COMPAT_5_2
xml_CFLAGS += -fno-common
xml_CFLAGS += -I../liblua/
xml_LDFLAGS = $(LUA_MOD_LDFLAGS)
xml_FILES = submodules/luaxml/src/LuaXML_lib.c
xml_INSTALL_PATH = /usr/local/xxtouch/lib
xml_LIBRARY_EXTENSION = .dylib


zip_CFLAGS = -Wno-unused-variable -Wno-unused-function
zip_CFLAGS += -DTARGET_OS_IPHONE=1 -DNDEBUG -DLUA_COMPAT_5_1 -DLUA_COMPAT_5_2
zip_CFLAGS += -fno-common
zip_CFLAGS += -Isubmodules/lua-zip/include/
zip_CFLAGS += -I../liblua/
zip_LDFLAGS = $(LUA_MOD_LDFLAGS)
zip_LDFLAGS += -Lsubmodules/lua-zip/lib
zip_LIBRARIES = zip
zip_FILES = submodules/lua-zip/src/lua_zip.c
zip_INSTALL_PATH = /usr/local/xxtouch/lib
zip_LIBRARY_EXTENSION = .dylib


archive_CFLAGS = -Wno-unused-variable -Wno-unused-function
archive_CFLAGS += -DTARGET_OS_IPHONE=1 -DNDEBUG -DLUA_COMPAT_5_1 -DLUA_COMPAT_5_2
archive_CFLAGS += -fno-common
archive_CFLAGS += -Isubmodules/lua-archive/include/
archive_CFLAGS += -I../liblua/
archive_CFLAGS += -Isubmodules/lua-archive/src/
archive_LDFLAGS = $(LUA_MOD_LDFLAGS)
archive_LDFLAGS += -Isubmodules/lua-archive/lib
archive_LIBRARIES = archive
archive_FILES = $(wildcard submodules/lua-archive/src/*.c)
archive_INSTALL_PATH = /usr/local/xxtouch/lib


minirsa_CFLAGS = -fobjc-arc -fobjc-arc-exceptions
minirsa_CFLAGS += -fno-common
minirsa_CFLAGS += -DTARGET_OS_IPHONE=1 -DNDEBUG -DLUA_COMPAT_5_1 -DLUA_COMPAT_5_2
minirsa_CFLAGS += -I../liblua/
minirsa_CFLAGS += -Isubmodules/minirsa/include/
minirsa_LDFLAGS = -Lsubmodules/minirsa/lib/
minirsa_LDFLAGS += $(LUA_MOD_LDFLAGS)
minirsa_LIBRARIES = crypto ssl
minirsa_FILES = submodules/minirsa/minirsa.c
minirsa_INSTALL_PATH = /usr/local/xxtouch/lib


openssl_CFLAGS = -DTARGET_OS_IPHONE=1 -DNDEBUG -DLUA_COMPAT_5_1 -DLUA_COMPAT_5_2
openssl_CFLAGS += -Wno-unused-variable -Wno-unused-function -Wno-incompatible-function-pointer-types -Wno-incompatible-pointer-types
openssl_CFLAGS += -I../liblua/
openssl_CFLAGS += -Isubmodules/lua-openssl/src/
openssl_CFLAGS += -Isubmodules/lua-openssl/deps/
openssl_CFLAGS += -Isubmodules/lua-openssl/deps/lua-compat/c-api/
openssl_CFLAGS += -Isubmodules/lua-openssl/deps/auxiliar/
openssl_CFLAGS += -Isubmodules/minirsa/include/
openssl_LDFLAGS = -Lsubmodules/minirsa/lib/
openssl_LDFLAGS += $(LUA_MOD_LDFLAGS)
openssl_LIBRARIES = crypto ssl
openssl_FILES = $(wildcard submodules/lua-openssl/src/*.c) $(wildcard submodules/lua-openssl/deps/auxiliar/*.c)
openssl_INSTALL_PATH = /usr/local/xxtouch/lib


lzmq_CFLAGS = -DTARGET_OS_IPHONE=1 -DNDEBUG -DLUA_COMPAT_5_1 -DLUA_COMPAT_5_2
lzmq_CFLAGS += -fno-common
lzmq_CFLAGS += -Wno-unused-variable -Wno-unused-function -Wno-void-pointer-to-int-cast
lzmq_CFLAGS += -I../liblua/
lzmq_CFLAGS += -Isubmodules/lzmq/src/
lzmq_CFLAGS += -Isubmodules/zeromq4/include/
lzmq_LDFLAGS = -L$(THEOS_OBJ_DIR)
lzmq_LDFLAGS += $(LUA_MOD_LDFLAGS)
lzmq_LIBRARIES = zmq
lzmq_FILES = $(wildcard submodules/lzmq/src/*.c)
lzmq_INSTALL_PATH = /usr/local/xxtouch/lib


vararg_CFLAGS = -DTARGET_OS_IPHONE=1 -DNDEBUG -DLUA_COMPAT_5_1 -DLUA_COMPAT_5_2
vararg_CFLAGS += -fno-common
vararg_CFLAGS += -I../liblua/
vararg_LDFLAGS = $(LUA_MOD_LDFLAGS)
vararg_FILES = submodules/lua-vararg/vararg.c
vararg_INSTALL_PATH = /usr/local/xxtouch/lib


pb_CFLAGS = -DTARGET_OS_IPHONE=1 -DNDEBUG -DLUA_COMPAT_5_1 -DLUA_COMPAT_5_2
pb_CFLAGS += -fno-common
pb_CFLAGS += -I../liblua/
pb_CFLAGS += -Isubmodules/lua-protobuf/src/
pb_LDFLAGS = $(LUA_MOD_LDFLAGS)
pb_FILES = submodules/lua-protobuf/src/pb.c
pb_INSTALL_PATH = /usr/local/xxtouch/lib


ev_CFLAGS = -DTARGET_OS_IPHONE=1 -DNDEBUG -DLUA_COMPAT_5_1 -DLUA_COMPAT_5_2
ev_CFLAGS += -fno-common
ev_CFLAGS += -I../liblua/
ev_CFLAGS += -Isubmodules/libev/src/
ev_CFLAGS += -Isubmodules/lua-ev/src/
ev_LDFLAGS = -L$(THEOS_OBJ_DIR)
ev_LDFLAGS += $(LUA_MOD_LDFLAGS)
ev_LIBRARIES = ev
ev_FILES = submodules/lua-ev/src/lua_ev.c
ev_INSTALL_PATH = /usr/local/xxtouch/lib


lterm_CFLAGS = -Wno-unused-variable -Wno-unused-function
lterm_CFLAGS += -DTARGET_OS_IPHONE=1 -DNDEBUG -DLUA_COMPAT_5_1 -DLUA_COMPAT_5_2
lterm_CFLAGS += -fno-common
lterm_CFLAGS += -I../liblua/
lterm_LDFLAGS = $(LUA_MOD_LDFLAGS)
lterm_FILES = submodules/lua-term/src/core.c
lterm_INSTALL_PATH = /usr/local/xxtouch/lib
lterm_LIBRARY_EXTENSION = .dylib


sirocco_CFLAGS = -Wno-unused-variable -Wno-unused-function
sirocco_CFLAGS += -DTARGET_OS_IPHONE=1 -DNDEBUG -DLUA_COMPAT_5_1 -DLUA_COMPAT_5_2
sirocco_CFLAGS += -fno-common
sirocco_CFLAGS += -I../liblua/
sirocco_LDFLAGS = $(LUA_MOD_LDFLAGS)
sirocco_FILES = submodules/sirocco/src/winsize.c
sirocco_INSTALL_PATH = /usr/local/xxtouch/lib
sirocco_LIBRARY_EXTENSION = .dylib


libpdebug_CFLAGS = -DTARGET_OS_IPHONE=1 -DNDEBUG -DLUA_COMPAT_5_1 -DLUA_COMPAT_5_2 -DUSE_SOURCE_CODE
libpdebug_CFLAGS += -fno-common
libpdebug_CFLAGS += -Isubmodules/luapanda/src/
libpdebug_CFLAGS += -I../liblua/
libpdebug_CFLAGS += -std=c++11
libpdebug_LDFLAGS = $(LUA_MOD_LDFLAGS)
libpdebug_FILES = submodules/luapanda/src/libpdebug.cpp
libpdebug_INSTALL_PATH = /usr/local/xxtouch/lib


include $(THEOS_MAKE_PATH)/library.mk


after-all::
	cp -r submodules/cjson/lua/* layout/usr/local/xxtouch/lib/
	cp -r submodules/lcurl/lua/* layout/usr/local/xxtouch/lib/
	cp -r submodules/lpeg/lua/* layout/usr/local/xxtouch/lib/
	cp submodules/lua-iconv/lua/uniopen.lua layout/usr/local/xxtouch/lib/
	cp submodules/lua-spawn/spawn/*.lua layout/usr/local/xxtouch/lib/spawn/
	cp -r submodules/luaposix/lib/posix/* layout/usr/local/xxtouch/lib/posix/
	cp -r submodules/luasocket/lua/* layout/usr/local/xxtouch/lib/
	cp -r submodules/luaxml/lua/* layout/usr/local/xxtouch/lib/
	cp -r submodules/luasec/lua/* layout/usr/local/xxtouch/lib/
	cp -r submodules/lua-path/lua/* layout/usr/local/xxtouch/lib/
	cp -r submodules/lua-sendmail/lua/* layout/usr/local/xxtouch/lib/
	cp -r submodules/lua-log/lua/* layout/usr/local/xxtouch/lib/
	cp -r submodules/lua-date/lua/* layout/usr/local/xxtouch/lib/
	cp -r submodules/ansicolors/lua/* layout/usr/local/xxtouch/lib/
	cp -r submodules/lua-llthreads2/lua/* layout/usr/local/xxtouch/lib/
	cp -r submodules/lzmq/lua/* layout/usr/local/xxtouch/lib/
	cp -r submodules/copas/lua/* layout/usr/local/xxtouch/lib/
	cp -r submodules/alien/lua/* layout/usr/local/xxtouch/lib/
	cp -r submodules/lua-websockets/lua/* layout/usr/local/xxtouch/lib/
	cp -r submodules/lua-protobuf/lua/* layout/usr/local/xxtouch/lib/
	cp -r submodules/lbase64/lua/* layout/usr/local/xxtouch/lib/
	cp -r submodules/binaryheap/lua/* layout/usr/local/xxtouch/lib/
	cp -r submodules/coxpcall/lua/* layout/usr/local/xxtouch/lib/
	cp -r submodules/timerwheel/lua/* layout/usr/local/xxtouch/lib/
	cp -r submodules/lua-tui/tui layout/usr/local/xxtouch/lib/
	cp -r submodules/lua-utf8-simple/lua/* layout/usr/local/xxtouch/lib/
	cp -r submodules/sirocco/sirocco layout/usr/local/xxtouch/lib/
	cp -r submodules/hump/hump layout/usr/local/xxtouch/lib/
	cp -r submodules/argparse/lua/* layout/usr/local/xxtouch/lib/
	cp -r submodules/lua-wcwidth/wcwidth* layout/usr/local/xxtouch/lib/
	cp -r submodules/lua-term/term layout/usr/local/xxtouch/lib/
	cp -r submodules/croissant/croissant layout/usr/local/xxtouch/lib/
	cp -r submodules/croissant/bin/* layout/usr/local/xxtouch/bin/
	cp -r submodules/neturl/lua/* layout/usr/local/xxtouch/lib/
	cp -r submodules/luapanda/lua/* layout/usr/local/xxtouch/lib/
