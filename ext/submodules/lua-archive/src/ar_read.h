// This is a private header subject to change.

#define AR_READ "archive{read}"

#define ar_read_check(L, narg) \
    ((struct archive**)luaL_checkudata((L), (narg), AR_READ))

int ar_read_init(lua_State *L);
