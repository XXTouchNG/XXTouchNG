#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import "lua.hpp"
#import <pthread.h>

#import "luae.h"
#import "ProcQueue.h"


#pragma mark -

XXTouchF_CAPI int luaopen_proc(lua_State *);
XXTouchF_CAPI int luaopen_exproc(lua_State *);

@interface ProcQueueLuaBridge : NSObject
+ (instancetype)sharedBridge;
@end

@implementation ProcQueueLuaBridge

+ (instancetype)sharedBridge {
    static ProcQueueLuaBridge *_sharedBridge = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedBridge = [[ProcQueueLuaBridge alloc] init];
    });
    return _sharedBridge;
}

@end


#pragma mark -

static int ProcQueue_Proc_Put(lua_State *L)
{
    @autoreleasepool {
        const char *cKey = luaL_checkstring(L, 1);
        const char *cVal = luaL_checkstring(L, 2);
        
        NSString *key = [NSString stringWithUTF8String:cKey];
        if ([key hasPrefix:@"ch.xxtou."]) {
            return luaL_argerror(L, 1, "restricted key");
        }
        
        NSString *val = [NSString stringWithUTF8String:cVal];
        
        NSString *priorVal = [[ProcQueue sharedInstance] procPutObject:val forKey:key];
        lua_pushstring(L, [priorVal UTF8String]);
        return 1;
    }
}

static int ProcQueue_Proc_Get(lua_State *L)
{
    @autoreleasepool {
        const char *cKey = luaL_checkstring(L, 1);
        NSString *key = [NSString stringWithUTF8String:cKey];
        if ([key hasPrefix:@"ch.xxtou."]) {
            return luaL_argerror(L, 1, "restricted key");
        }
        NSString *val = [[ProcQueue sharedInstance] procObjectForKey:key];
        lua_pushstring(L, [val UTF8String]);
        return 1;
    }
}

static int ProcQueue_Queue_PushBack(lua_State *L)
{
    @autoreleasepool {
        const char *cKey = luaL_checkstring(L, 1);
        const char *cVal = luaL_checkstring(L, 2);
        
        NSString *key = [NSString stringWithUTF8String:cKey];
        if ([key hasPrefix:@"ch.xxtou."]) {
            return luaL_argerror(L, 1, "restricted key");
        }
        NSString *val = [NSString stringWithUTF8String:cVal];
        
        NSUInteger queueSize = [[ProcQueue sharedInstance] procQueuePushTailObject:val forKey:key];
        lua_pushinteger(L, (lua_Integer)queueSize);
        return 1;
    }
}

static int ProcQueue_Queue_PushFront(lua_State *L)
{
    @autoreleasepool {
        const char *cKey = luaL_checkstring(L, 1);
        const char *cVal = luaL_checkstring(L, 2);
        
        NSString *key = [NSString stringWithUTF8String:cKey];
        if ([key hasPrefix:@"ch.xxtou."]) {
            return luaL_argerror(L, 1, "restricted key");
        }
        NSString *val = [NSString stringWithUTF8String:cVal];
        
        NSUInteger queueSize = [[ProcQueue sharedInstance] procQueueUnshiftObject:val forKey:key];
        lua_pushinteger(L, (lua_Integer)queueSize);
        return 1;
    }
}

static int ProcQueue_Queue_PopFront(lua_State *L)
{
    @autoreleasepool {
        const char *cKey = luaL_checkstring(L, 1);
        NSString *key = [NSString stringWithUTF8String:cKey];
        if ([key hasPrefix:@"ch.xxtou."]) {
            return luaL_argerror(L, 1, "restricted key");
        }
        NSString *val = [[ProcQueue sharedInstance] procQueueShiftObjectForKey:key];
        lua_pushstring(L, [val UTF8String]);
        return 1;
    }
}

static int ProcQueue_Queue_PopBack(lua_State *L)
{
    @autoreleasepool {
        const char *cKey = luaL_checkstring(L, 1);
        NSString *key = [NSString stringWithUTF8String:cKey];
        if ([key hasPrefix:@"ch.xxtou."]) {
            return luaL_argerror(L, 1, "restricted key");
        }
        NSString *val = [[ProcQueue sharedInstance] procQueuePopTailObjectForKey:key];
        lua_pushstring(L, [val UTF8String]);
        return 1;
    }
}

static int ProcQueue_Queue_Clear(lua_State *L)
{
    @autoreleasepool {
        const char *cKey = luaL_checkstring(L, 1);
        NSString *key = [NSString stringWithUTF8String:cKey];
        if ([key hasPrefix:@"ch.xxtou."]) {
            return luaL_argerror(L, 1, "restricted key");
        }
        NSArray <NSString *> *arr = [[ProcQueue sharedInstance] procQueueClearObjectsForKey:key];
        lua_pushNSArray(L, arr);
        return 1;
    }
}

static int ProcQueue_Queue_Size(lua_State *L)
{
    @autoreleasepool {
        const char *cKey = luaL_checkstring(L, 1);
        NSString *key = [NSString stringWithUTF8String:cKey];
        if ([key hasPrefix:@"ch.xxtou."]) {
            return luaL_argerror(L, 1, "restricted key");
        }
        NSUInteger queueSize = [[ProcQueue sharedInstance] procQueueSizeForKey:key];
        lua_pushinteger(L, (lua_Integer)queueSize);
        return 1;
    }
}


#pragma mark -

static const luaL_Reg ProcQueue_AuxLib[] = {
    
    /* Proc Dictionary */
    {"put", ProcQueue_Proc_Put},
    {"get", ProcQueue_Proc_Get},
    
    /* Proc Queue Dictionary */
    {"queue_push", ProcQueue_Queue_PushBack},
    {"queue_push_back", ProcQueue_Queue_PushBack},
    {"queue_push_front", ProcQueue_Queue_PushFront},
    {"queue_pop", ProcQueue_Queue_PopBack},
    {"queue_pop_back", ProcQueue_Queue_PopBack},
    {"queue_pop_front", ProcQueue_Queue_PopFront},
    {"queue_unshift", ProcQueue_Queue_PushFront},
    {"queue_shift", ProcQueue_Queue_PopFront},
    {"queue_clear", ProcQueue_Queue_Clear},
    {"queue_size", ProcQueue_Queue_Size},
    
    {NULL, NULL},
};

XXTouchF_CAPI int luaopen_proc(lua_State *L)
{
    lua_createtable(L, 0, (sizeof(ProcQueue_AuxLib) / sizeof((ProcQueue_AuxLib)[0]) - 1) + 2);
    lua_pushliteral(L, LUA_MODULE_VERSION);
    lua_setfield(L, -2, "_VERSION");
    luaL_setfuncs(L, ProcQueue_AuxLib, 0);
    
    return 1;
}

XXTouchF_CAPI int luaopen_exproc(lua_State *L)
{
    return luaopen_proc(L);
}
