//
//  TFLuaBridge+Macros.h
//  XXTouch
//
//  Created by Darwin on 10/14/20.

#ifndef TFLuaBridge_Macros_h
#define TFLuaBridge_Macros_h

/**/
#define XPC_MODULE_PREFIX "ch.xxtou."
/**/

/**/
#define IMP_LUA_HANDLER(CMD_NAME) static int CHConcat(CHConcat(LUA_MODULE_NAME, _), CMD_NAME)(lua_State *L)
#define IMP_LUA_HANDLER_MAP static const luaL_Reg CHConcat(CHConcat(LUA_MODULE_NAME, _), AuxLib)
/**/

/**/
#ifdef  __cplusplus
#define LuaConstructor \
extern "C" int CHConcat(luaopen_,LUA_MODULE_NAME)(lua_State *L); \
extern "C" int CHConcat(luaopen_,LUA_MODULE_NAME)(lua_State *L)
#else
#define LuaConstructor \
extern int CHConcat(luaopen_,LUA_MODULE_NAME)(lua_State *L); \
extern int CHConcat(luaopen_,LUA_MODULE_NAME)(lua_State *L)
#endif
/**/

/**/
#define DECLARE_LUA_HANDLER_MAP CHConcat(CHConcat(LUA_MODULE_NAME, _), AuxLib)
#define DECLARE_LUA_HANDLER(CMD_NAME) {CHStringify_(CMD_NAME),CHConcat(CHConcat(LUA_MODULE_NAME, _), CMD_NAME)}
#define DECLARE_NULL {NULL,NULL}
/**/

/**/
#define DECLARE_XPC_HANDLER(CMD_NAME) \
+ (id)CMD_NAME:(NSDictionary *)data error:(NSError *__autoreleasing*)error;
/**/

/**/
#define IMP_XPC_HANDLER(CMD_NAME) \
+ (id)CMD_NAME:(NSDictionary *)data error:(NSError *__autoreleasing*)error { \
    return [[TFLuaBridge sharedInstance] localClientDoAction:@"" #CMD_NAME "" userInfo:data error:error]; \
}
#define IMP_XPC_HANDLER_TIMEOUT(CMD_NAME, CMD_TIMEOUT) \
+ (id)CMD_NAME:(NSDictionary *)data error:(NSError *__autoreleasing*)error { \
    return [[TFLuaBridge sharedInstance] localClientDoAction:@"" #CMD_NAME "" userInfo:data timeout:(CMD_TIMEOUT) error:error]; \
}
/**/

#endif /* TFLuaBridge_Macros_h */
