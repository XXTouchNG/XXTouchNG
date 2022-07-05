#import "luae.h"


static luaL_Reg *luaE_copyllib(const struct luaE_Reg *libs) {
    luaE_Reg *p = (luaE_Reg *) libs;
    int t = 0;
    while ((p++)->name != NULL) t++;
    luaL_Reg *llibs = (luaL_Reg *) malloc(sizeof(luaL_Reg) * (2 * t + 1));

    luaL_Reg *p2 = llibs;
    luaE_Reg *p1 = NULL;
    
    // Common names
    p1 = (luaE_Reg *) libs;
    while (p1->name != NULL) {
        p2->name = p1->name;
        p2->func = p1->func;
        p1++;
        p2++;
    }

    // {NULL, NULL}
    p2->name = NULL;
    p2->func = NULL;
    return llibs;
}

void luaE_newelib(lua_State *L, const struct luaE_Reg *libs) {
    luaL_Reg *llibs = luaE_copyllib(libs);
    luaL_Reg *p = llibs;
    int t = 0;
    while ((p++)->name != NULL) t++;
    luaL_checkversion(L);
    lua_createtable(L, 0, t);
    luaL_setfuncs(L, llibs, 0);
    free(llibs);
}

void luaE_setelib(lua_State *L, const struct luaE_Reg *libs) {
    luaL_Reg *llibs = luaE_copyllib(libs);
    luaL_Reg *p = llibs;
    int t = 0;
    while ((p++)->name != NULL) t++;
    luaL_checkversion(L);
    luaL_setfuncs(L, llibs, 0);
    free(llibs);
}

const char *luaE_func2name(const char *func, const struct luaE_Reg *libs) {
    luaE_Reg *pl = (luaE_Reg *) libs;
    while (pl->name != NULL) {
        if (strcmp(pl->func_name, func) == 0) {
            return pl->name;
        }
        pl++;
    }
    return "";
}

void lua_setPath(lua_State* L, const char *key, const char *path)
{
    @autoreleasepool {
        lua_getglobal(L, "package");
        lua_getfield(L, -1, key); // get field "path" from table at top of stack (-1)
        const char *origPath = lua_tostring(L, -1); // grab path string from top of stack
        NSString *strPath = [[NSString alloc] initWithUTF8String:path];
#if !__has_feature(objc_arc)
        [strPath autorelease];
#endif
        NSString *strOrigPath = [[NSString alloc] initWithUTF8String:origPath];
#if !__has_feature(objc_arc)
        [strOrigPath autorelease];
#endif
        strOrigPath = [strOrigPath stringByAppendingString:@";"];
        strOrigPath = [strOrigPath stringByAppendingString:strPath];
        strOrigPath = [strOrigPath stringByAppendingString:@";"];
        lua_pop(L, 1); // get rid of the string on the stack we just pushed on line 5
        lua_pushstring(L, [strOrigPath UTF8String]); // push the new one
        lua_setfield(L, -2, key); // set the field "path" in table at -2 with value at top of stack
        lua_pop(L, 1); // get rid of package table from top of stack
    }
}


#pragma mark - NSValue

#define LUA_NSVALUE_MAX_DEPTH 50
static void lua_pushNSArrayx(lua_State *L, NSArray *arr, int level);
static void lua_pushNSDictionaryx(lua_State *L, NSDictionary *dict, int level);


static void lua_pushNSArrayx(lua_State *L, NSArray *arr, int level)
{
    if (level > LUA_NSVALUE_MAX_DEPTH) {
        lua_pushnil(L);
        return;
    }
    lua_newtable(L);
    for (NSUInteger idx = 0; idx < arr.count; ++idx) {
        @autoreleasepool {
            id value = [arr objectAtIndex:idx];
            lua_pushNSValuex(L, value, level);  // no need to level up
            lua_rawseti(L, -2, idx + 1);
        }
    }
}


static void lua_pushNSDictionaryx(lua_State *L, NSDictionary *dict, int level)
{
    if (level > LUA_NSVALUE_MAX_DEPTH) {
        lua_pushnil(L);
        return;
    }
    @autoreleasepool {
        NSArray *keys = [dict allKeys];
        lua_newtable(L);
        for (NSUInteger i = 0; i < keys.count; ++i) {
            @autoreleasepool {
                id key = [keys objectAtIndex:i];
                id value = [key isKindOfClass:[NSString class]] ? [dict valueForKey:key] : [dict objectForKey:key];
                lua_pushNSValuex(L, value, level);  // no need to level up
                if ([key isKindOfClass:[NSString class]]) {
                    lua_setfield(L, -2, [key UTF8String]);
                } else if ([key isKindOfClass:[NSNumber class]]) {
                    lua_rawseti(L, -2, [key longLongValue]);
                } else {
                    assert(FALSE);
                }
            }
        }
    }
}


void lua_pushNSValuex(lua_State *L, id value, int level)
{
    @autoreleasepool {
        if ([value isKindOfClass:[NSString class]]) {
            lua_pushstring(L, [value UTF8String]);
        } else if ([value isKindOfClass:[NSUUID class]]) {
            lua_pushstring(L, [[value UUIDString] UTF8String]);
        } else if ([value isKindOfClass:[NSURL class]]) {
            NSString *s = [value isFileURL] ? [value path] : [value absoluteString];
            if (s) {
                lua_pushstring(L, [s UTF8String]);
            } else {
                lua_pushnil(L);
            }
        } else if ([value isKindOfClass:[NSDate class]]) {
            lua_pushnumber(L, [value timeIntervalSince1970]);
        } else if ([value isKindOfClass:[NSData class]]) {
            lua_pushlstring(L, (const char *)[value bytes], [value length]);
        } else if ([value isKindOfClass:[NSNumber class]]) {
            if (value == (id)kCFBooleanFalse || value == (id)kCFBooleanTrue || [value class] == [@(NO) class]) {
                lua_pushboolean(L, [value boolValue]);
            } else if (strcmp([value objCType], @encode(int)) == 0) {
                lua_pushinteger(L, [value intValue]);
            } else if (strcmp([value objCType], @encode(long)) == 0 || strcmp([value objCType], @encode(unsigned long)) == 0) {
                lua_pushinteger(L, [value longValue]);
            } else if (strcmp([value objCType], @encode(long long)) == 0 || strcmp([value objCType], @encode(unsigned long long)) == 0) {
                lua_pushinteger(L, [value longLongValue]);
            } else {
                lua_pushnumber(L, [value doubleValue]);
            }
        } else if ([value isKindOfClass:[NSDictionary class]]) {
            lua_pushNSDictionaryx(L, value, level + 1);
        } else if ([value isKindOfClass:[NSArray class]]) {
            lua_pushNSArrayx(L, value, level + 1);
        } else if ([value isKindOfClass:[NSNull class]]) {
            lua_pushlightuserdata(L, 0);
        } else {
            lua_pushnil(L);
        }
    }
}


int lua_table_is_array(lua_State *L, int index)
{
    double k = 0;
    int max;
    int items;
    
    max = 0;
    items = 0;
    
    lua_pushvalue(L, index);
    /* -------------------------------------- */
    lua_getfield(L, -1, "isArray");
    int is_array_flag = !lua_isnoneornil(L, -1);
    if (is_array_flag) {
        lua_pop(L, 2);
        return 1;
    } else {
        lua_pop(L, 1);
    }
    /* -------------------------------------- */
    lua_pushnil(L);
    int ret = 1;
    
    /* table, startkey */
    while (lua_next(L, -2) != 0) {
        /* table, key, value */
        if (lua_type(L, -2) == LUA_TNUMBER &&
            (k = lua_tonumber(L, -2))) {
            /* Integer >= 1 ? */
            if (floor(k) == k && k >= 1) {
                if (k > max)
                    max = k;
                items++;
                lua_pop(L, 1);
                continue;
            }
        }
        
        /* Must not be an array (non integer key) */
        lua_pop(L, 3);
        return 0;
    }
    
    lua_pop(L, 1);
    
    if (0 >= items) {
        ret = 0;
    }
    return ret;
}


static NSArray *lua_toNSArrayx(lua_State *L, int index, NSMutableArray *resultarray, int level)
{
    if (level > LUA_NSVALUE_MAX_DEPTH) {
        return nil;
    }
    if (lua_type(L, index) != LUA_TTABLE) {
        return nil;
    }
    @autoreleasepool {
        if (resultarray == nil) {
            resultarray = [[NSMutableArray alloc] init];
#if !__has_feature(objc_arc)
            [resultarray autorelease];
#endif
        }
        lua_pushvalue(L, index);
        long long n = luaL_len(L, -1);
        for (int i = 1; i <= n; ++i) {
            @autoreleasepool {
                lua_rawgeti(L, -1, i);
                id value = lua_toNSValuex(L, -1, level);
                if (value != nil) {
                    [resultarray addObject:value];
                }
                lua_pop(L, 1);
            }
        }
        lua_pop(L, 1);
        return resultarray;
    }
}

static NSDictionary *lua_toNSDictionaryx(lua_State *L, int index, NSMutableDictionary *resultdict, int level)
{
    if (level > LUA_NSVALUE_MAX_DEPTH) {
        return nil;
    }
    if (lua_type(L, index) != LUA_TTABLE) {
        return nil;
    }
    @autoreleasepool {
        if (resultdict == nil) {
            resultdict = [[NSMutableDictionary alloc] init];
#if !__has_feature(objc_arc)
            [resultdict autorelease];
#endif
        }
        lua_pushvalue(L, index);
        lua_pushnil(L);  /* first key */
        while (lua_next(L, -2) != 0) {
            @autoreleasepool {
                id key = lua_toNSValuex(L, -2, level);
                if (key != nil) {
                    id value = lua_toNSValuex(L, -1, level);
                    if (value != nil) {
                        resultdict[key] = value;
                    }
                }
                lua_pop(L, 1);
            }
        }
        lua_pop(L, 1);
        return resultdict;
    }
}


id lua_toNSValuex(lua_State *L, int index, int level)
{
    @autoreleasepool {
        int value_type = lua_type(L, index);
        if (value_type == LUA_TSTRING) {
            size_t l = 0;
            const unsigned char *value = (const unsigned char *)luaL_checklstring(L, index, &l);
            NSData *value_data = [NSData dataWithBytes:value length:l];
            NSString *value_string = [NSString alloc];
#if !__has_feature(objc_arc)
            [value_string autorelease];
#endif
            value_string = [value_string initWithData:value_data encoding:NSUTF8StringEncoding];
            if (!value_string) {
                return value_data;
            } else {
                return value_string;
            }
        } else if (value_type == LUA_TNUMBER) {
#if defined(LUA_VERSION_NUM) && LUA_VERSION_NUM >= 503
            if (lua_isinteger(L, index)) {
                return @(luaL_checkinteger(L, index));
            } else {
#endif
                int isnum;
                lua_Integer ivalue = lua_tointegerx(L, index, &isnum);
                if (isnum) {
                    return @(ivalue);
                } else {
                    return @(luaL_checknumber(L, index));
                }
#if defined(LUA_VERSION_NUM) && LUA_VERSION_NUM >= 503
            }
#endif
        } else if (value_type == LUA_TBOOLEAN) {
            return @((BOOL)lua_toboolean(L, index));
        } else if (value_type == LUA_TTABLE) {
            if (lua_table_is_array(L, index)) {
                return lua_toNSArrayx(L, index, nil, level + 1);
            } else {
                return lua_toNSDictionaryx(L, index, nil, level + 1);
            }
        } else if (value_type == LUA_TLIGHTUSERDATA && lua_touserdata(L, index) == NULL) {
            return [NSNull null];
        }
        return nil;
    }
}


void luaE_checkarray(lua_State *L, int index)
{
    luaL_checktype(L, index, LUA_TTABLE);
    if (!lua_table_is_array(L, index))
        luaL_argerror(L, index, "array expected, got dictionary");
}

void luaE_checkdictionary(lua_State *L, int index)
{
    luaL_checktype(L, index, LUA_TTABLE);
    if (lua_table_is_array(L, index))
        luaL_argerror(L, index, "dictionary expected, got array");
}
