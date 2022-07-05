#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#include <sys/ioctl.h>

int lua_winsize(lua_State *L) {
    struct winsize sz;

    ioctl(0, TIOCGWINSZ, &sz);

    lua_pushinteger(L, sz.ws_col);
    lua_pushinteger(L, sz.ws_row);

    return 2;
}


int luaopen_sirocco_winsize(lua_State *L) {
    lua_pushcfunction(L, lua_winsize);

    return 1;
}
