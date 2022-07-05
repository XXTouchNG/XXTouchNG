#define AR_REGISTRY  "archive{registry}"

void ar_registry_init(lua_State *L);
void ar_registry_set(lua_State *L, void *ptr);
int ar_registry_get(lua_State *L, void *ptr);
