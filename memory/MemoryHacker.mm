//
//  MemoryHacker.m
//  XXTouch
//
//  Created by Zheng on 25/04/2018.
//  Copyright © 2018 Zheng. All rights reserved.
//

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import "luae.h"
#import "mh_app.h"
#import "mh_commands.h"
#import "AuthPolicy.h"
#import <dlfcn.h>


/* MARK: ----------------------------------------------------------------------- */


_ELIB_DECL(memory);


/* MARK: ----------------------------------------------------------------------- */


#define luaE_optboolean(L, IDX, DEF) \
(BOOL)(lua_isboolean((L), (IDX)) ? lua_toboolean(L, (IDX)) : (DEF))

#define MH_DTYPE(ENT, c1, c2) \
(*ENT->dataType == c1 && *(ENT->dataType + 1) == c2)

#define MH_TYPE(TYP, c1, c2) \
(*TYP == c1 && *(TYP + 1) == c2)

#define MH_DCONVERT(T, SEL) \
T _lv = (T)[dict[@"lv"] SEL]; \
T _hv = (T)[dict[@"hv"] SEL]; \
memcpy(entry->lv, &_lv, sizeof(T)); \
memcpy(entry->hv, &_hv, sizeof(T));


/* MARK: ----------------------------------------------------------------------- */


OBJC_EXTERN pid_t mh_pid_for_running_application_identifier(const char *);

static MHContext *mh_global_context = NULL;
int MHSaveGlobalContext(MHContext *context) {
    mh_global_context = context;
    return 0;
}
MHContext *MHGetGlobalContext() {
    return mh_global_context;
}

static void mh_copy_entry_for_dictionary(struct search_entry **out_entry, NSDictionary *dictionary, const char *defaultType)
{
    if (!out_entry) return;
    NSMutableDictionary *dict = [dictionary mutableCopy];
    struct search_entry *entry = (struct search_entry *)malloc(sizeof(struct search_entry));
    memset(entry, 0x0, sizeof(struct search_entry));
    if ([dict[@"type"] isKindOfClass:[NSString class]]) {
        entry->dataType = [dict[@"type"] UTF8String];
    } else if (defaultType) {
        entry->dataType = defaultType;
    }
    if ([dict[@"offset"] isKindOfClass:[NSNumber class]]) {
        entry->offset = [dict[@"offset"] unsignedLongLongValue];
    } else { entry->offset = 0; }
    assert([dict[@"lv"] isKindOfClass:[NSNumber class]]);
    if (!dict[@"hv"]) { dict[@"hv"] = dict[@"lv"]; }
    /**/ if (MH_DTYPE(entry, 'I', '8')) { MH_DCONVERT(int8_t,   charValue);             }
    else if (MH_DTYPE(entry, 'I', '1')) { MH_DCONVERT(int16_t,  shortValue);            }
    else if (MH_DTYPE(entry, 'I', '3')) { MH_DCONVERT(int32_t,  intValue);              }
    else if (MH_DTYPE(entry, 'I', '6')) { MH_DCONVERT(int64_t,  longLongValue);         }
    else if (MH_DTYPE(entry, 'U', '8')) { MH_DCONVERT(uint8_t,  unsignedCharValue);     }
    else if (MH_DTYPE(entry, 'U', '1')) { MH_DCONVERT(uint16_t, unsignedShortValue);    }
    else if (MH_DTYPE(entry, 'U', '3')) { MH_DCONVERT(uint32_t, intValue);              }
    else if (MH_DTYPE(entry, 'U', '6')) { MH_DCONVERT(uint64_t, unsignedLongLongValue); }
    else if (MH_DTYPE(entry, 'F', '3')) { MH_DCONVERT(float,    floatValue);            }
    else if (MH_DTYPE(entry, 'F', '6')) { MH_DCONVERT(double,   doubleValue);           }
    else { assert(false); }
    *out_entry = entry;
}

static void mh_copy_entries_for_array(struct search_entry **out_entries, int *out_size, NSArray <NSDictionary *> *array, const char *defaultType)
{
    int siz = (int)array.count;
    struct search_entry *entries = (struct search_entry *)malloc(siz * sizeof(struct search_entry));
    int i = 0;
    for (NSDictionary *entryDict in array) {
        struct search_entry *entry0 = NULL;
        mh_copy_entry_for_dictionary(&entry0, entryDict, defaultType);
        if (!entry0) continue;
        memcpy(&entries[i], entry0, sizeof(struct search_entry));
        free(entry0);
        i++;
    }
    *out_entries = entries;
    *out_size = i;
}

#define MH_DPUSH_INT(T) \
T v; \
memcpy(&v, data, sizeof(T)); \
lua_Integer val = (lua_Integer)v; \
lua_pushinteger(L, val);

#define MH_DPUSH_NUM(T) \
T v; \
memcpy(&v, data, sizeof(T)); \
lua_Number val = (lua_Number)v; \
lua_pushnumber(L, val);

static void mh_push_data_with_type(lua_State *L, void *data, const char *dataType)
{
    /**/ if (MH_TYPE(dataType, 'I', '8')) { MH_DPUSH_INT(int8_t);   }
    else if (MH_TYPE(dataType, 'I', '1')) { MH_DPUSH_INT(int16_t);  }
    else if (MH_TYPE(dataType, 'I', '3')) { MH_DPUSH_INT(int32_t);  }
    else if (MH_TYPE(dataType, 'I', '6')) { MH_DPUSH_INT(int64_t);  }
    else if (MH_TYPE(dataType, 'U', '8')) { MH_DPUSH_INT(uint8_t);  }
    else if (MH_TYPE(dataType, 'U', '1')) { MH_DPUSH_INT(uint16_t); }
    else if (MH_TYPE(dataType, 'U', '3')) { MH_DPUSH_INT(uint32_t); }
    else if (MH_TYPE(dataType, 'U', '6')) { MH_DPUSH_INT(uint64_t); }
    else if (MH_TYPE(dataType, 'F', '3')) { MH_DPUSH_NUM(float);   }
    else if (MH_TYPE(dataType, 'F', '6')) { MH_DPUSH_NUM(double);  }
    else { assert(false); }
}

#define MH_DFETCH_NUM(T) \
T val = (T) value; \
void *tmp = (void *)malloc(sizeof(T)); \
memcpy(tmp, &val, sizeof(T)); \
return tmp;

static void *mh_fetch_data_with_type(lua_Number value, const char *dataType)
{
    /**/ if (MH_TYPE(dataType, 'I', '8')) { MH_DFETCH_NUM(int8_t);   }
    else if (MH_TYPE(dataType, 'I', '1')) { MH_DFETCH_NUM(int16_t);  }
    else if (MH_TYPE(dataType, 'I', '3')) { MH_DFETCH_NUM(int32_t);  }
    else if (MH_TYPE(dataType, 'I', '6')) { MH_DFETCH_NUM(int64_t);  }
    else if (MH_TYPE(dataType, 'U', '8')) { MH_DFETCH_NUM(uint8_t);  }
    else if (MH_TYPE(dataType, 'U', '1')) { MH_DFETCH_NUM(uint16_t); }
    else if (MH_TYPE(dataType, 'U', '3')) { MH_DFETCH_NUM(uint32_t); }
    else if (MH_TYPE(dataType, 'U', '6')) { MH_DFETCH_NUM(uint64_t); }
    else if (MH_TYPE(dataType, 'F', '3')) { MH_DFETCH_NUM(float);   }
    else if (MH_TYPE(dataType, 'F', '6')) { MH_DFETCH_NUM(double);  }
    else { assert(false); }
}

static int mh_cmd_auth_open(MHContext *context, pid_t pid)
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dlopen("/usr/lib/libauthpolicy.dylib", RTLD_NOW);
    });
    
    BOOL isEligible = [[objc_getClass(CHStringify(AuthPolicy)) sharedInstance] eligibilityOfCodeInjectionWithProcessIdentifier:pid];
    if (!isEligible) {
        return -1;
    }
    
    return mh_cmd_open(context, pid);
}


_EFUNC(MHRead) {
    _EBEGIN
    _EPOOL {
        lua_Integer pid = luaL_checkinteger(L, 1);
        lua_Integer addr = luaL_checkinteger(L, 2);
        const char *type = luaL_checkstring(L, 3);
        size_t lsize = 0;
        _ECHK {
            if ((lsize = mh_size_for_type(type)) == 0) {
                _EARG(3, ([NSString stringWithFormat:@"invalid data type %s, available choices are: I8/I16/I32/I64/U8/U16/U32/U64/F32/F64", type]));
            }
        }
        _ECHK {
            MHContext *context = MH_new();
            int flag = mh_cmd_auth_open(context, (pid_t)pid);
            if (flag != 0)
            {   // failed to open process
                lua_pushboolean(L, false);
                lua_pushstring(L, ([[NSString stringWithFormat:@"cannot open process %d", (pid_t) pid] UTF8String]));
                MH_free(context);
                return 2;
            }
            mach_vm_address_t address = (mach_vm_address_t) addr;
            mach_vm_size_t size = (mach_vm_size_t) lsize;
            void *tmp = mh_read_memory(&context->process, address, &size);
            if (!tmp)
            { // failed to read
                lua_pushboolean(L, false);
                lua_pushstring(L, ([[NSString stringWithFormat:@"mach_vm_read failed"] UTF8String]));
                mh_cmd_close(context);
                MH_free(context);
                return 2;
            }
            lua_pushboolean(L, true);
            mh_push_data_with_type(L, tmp, type);
            mach_vm_deallocate(mach_task_self(), (vm_offset_t) tmp, size);
            mh_cmd_close(context);
            MH_free(context);
            return 2;
        };
    };
    _EEND(memory)
}


_EFUNC(MHWrite) {
    _EBEGIN
    _EPOOL {
        lua_Integer pid = luaL_checkinteger(L, 1);
        lua_Integer addr = luaL_checkinteger(L, 2);
        lua_Number value = luaL_checknumber(L, 3);
        const char *type = luaL_checkstring(L, 4);
        size_t lsize = 0;
        _ECHK {
            if ((lsize = mh_size_for_type(type)) == 0) {
                _EARG(3, ([NSString stringWithFormat:@"invalid data type %s, available choices are: I8/I16/I32/I64/U8/U16/U32/U64/F32/F64", type]));
            }
        }
        _ECHK {
            MHContext *context = MH_new();
            int flag = mh_cmd_auth_open(context, (pid_t)pid);
            if (flag != 0)
            {   // failed to open process
                lua_pushboolean(L, false);
                lua_pushstring(L, ([[NSString stringWithFormat:@"cannot open process %d", (pid_t) pid] UTF8String]));
                MH_free(context);
                return 2;
            }
            mach_vm_address_t address = (mach_vm_address_t) addr;
            mach_vm_size_t size = (mach_vm_size_t) lsize;
            void *data = mh_fetch_data_with_type(value, type);
            int result = mh_write_memory(&context->process, address, data, size);
            free(data);
            if (result != KERN_SUCCESS)
            {   // failed to write
                lua_pushboolean(L, false);
                lua_pushstring(L, ([[NSString stringWithFormat:@"mach_vm_write failed"] UTF8String]));
                mh_cmd_close(context);
                MH_free(context);
                return 2;
            }
            lua_pushboolean(L, true);
            lua_pushnil(L);
            mh_cmd_close(context);
            MH_free(context);
            return 2;
        };
    };
    _EEND(memory)
}


_EFUNC(MHGetBaseAddress) {
    _EBEGIN
    _EPOOL {
        lua_Integer pid = luaL_checkinteger(L, 1);
        _ECHK {
            MHContext *context = MH_new();
            int flag = mh_cmd_auth_open(context, (pid_t)pid);
            if (flag != 0)
            {   // failed to open process
                lua_pushboolean(L, false);
                lua_pushstring(L, ([[NSString stringWithFormat:@"cannot open process %d", (pid_t) pid] UTF8String]));
                MH_free(context);
                return 2;
            }
            mach_vm_address_t address = 0x0;
            int result = mh_cmd_process_base_address(context, &address);
            if (result != KERN_SUCCESS)
            { // failed to fetch
                lua_pushboolean(L, false);
                lua_pushstring(L, ([[NSString stringWithFormat:@"mach_vm_region failed"] UTF8String]));
                mh_cmd_close(context);
                MH_free(context);
                return 2;
            }
            lua_pushboolean(L, true);
            lua_pushinteger(L, (lua_Integer) address);
            mh_cmd_close(context);
            MH_free(context);
            return 2;
        };
    };
    _EEND(memory)
}


_EFUNC(MHSearchSetMode) {
    _EBEGIN
    _EPOOL {
        lua_Integer choice = luaL_checkinteger(L, 1);
        _ECHK {
            if (choice != MH_FAST && choice != MH_NORMAL /* && choice != 2 */)
            {
                _EARG(1, ([NSString stringWithFormat:@"invalid search mode %lld, available choices are: 0 (FAST), 1 (NORMAL) and 2 (ALL)", choice]));
            }
        }
        _ECHK {
            mh_set_search_map_mode((MHSearchMapMode)choice);
            return 0;
        }
    };
    _EEND(memory)
}


_EFUNC(MHSearchReset) {
    _EBEGIN
    _EPOOL {
        MHContext *sharedContext = MHGetGlobalContext();
        // do some clean
        if (sharedContext != NULL)
        {
            mh_cmd_close(sharedContext);
            MH_free(sharedContext);
            MHSaveGlobalContext(NULL);
            sharedContext = NULL;
        }
        return 0;
    }
    _EEND(memory)
}


_EFUNC(MHSearch) {
    _EBEGIN
    _EPOOL {
        lua_Integer pid = luaL_checkinteger(L, 1);
        BOOL isNewSearch = luaE_optboolean(L, 2, YES);
        lua_Integer addr = luaL_checkinteger(L, 3);
        NSArray <NSDictionary *> *tb = lua_toNSValuex(L, 4, 0);
        const char *type = luaL_checkstring(L, 5);
        lua_Integer searchValueMax = luaL_optinteger(L, 6, 9999);
        _ECHK {
            if (![tb isKindOfClass:[NSArray class]]) {
                _EARG(4, @"not an array");
            }
        }
        _ECHK {
            size_t idx = 0;
            for (NSDictionary *dict in tb) {
                if (![dict isKindOfClass:[NSDictionary class]]) {
                    _EARG(4, ([NSString stringWithFormat:@"invalid search table #%zu in array: not a dictionary", idx]));
                    break;
                }
                if (![dict[@"lv"] isKindOfClass:[NSNumber class]]) {
                    _EARG(4, ([NSString stringWithFormat:@"invalid search table #%zu in array: lv is not a number", idx]));
                    break;
                }
                if ((dict[@"hv"]) && ![dict[@"hv"] isKindOfClass:[NSNumber class]]) {
                    _EARG(4, ([NSString stringWithFormat:@"invalid search table #%zu in array: hv is not a number", idx]));
                    break;
                }
                if ((dict[@"offset"]) && ![dict[@"offset"] isKindOfClass:[NSNumber class]]) {
                    _EARG(4, ([NSString stringWithFormat:@"invalid search table #%zu in array: offset is not a number", idx]));
                    break;
                }
                if ((dict[@"type"]) && ![dict[@"type"] isKindOfClass:[NSString class]]) {
                    _EARG(4, ([NSString stringWithFormat:@"invalid search table #%zu in array: type is not a string", idx]));
                    break;
                }
                if (dict[@"type"]) {
                    const char *dtype = [dict[@"type"] UTF8String];
                    if (mh_size_for_type(dtype) == 0) {
                        _EARG(4, ([NSString stringWithFormat:@"invalid search table #%zu in array: invalid type %s", idx, dtype]));
                        break;
                    }
                }
                idx++;
            }
        }
        size_t lsize = 0;
        _ECHK {
            if ((lsize = mh_size_for_type(type)) == 0) {
                _EARG(5, ([NSString stringWithFormat:@"invalid data type %s, available choices are: I8/I16/I32/I64/U8/U16/U32/U64/F32/F64", type]));
            }
        }
        _ECHK {
            if (searchValueMax < 0) {
                _EARG(6, @"maximum limit of search result must be greater than 0");
            } else if (searchValueMax == 0 || searchValueMax > INT_MAX) {
                searchValueMax = INT_MAX;
            }
        }
        _ECHK {
            // fetch context
            pid_t npid = (pid_t)pid;
            MHContext *sharedContext = MHGetGlobalContext();
            if (isNewSearch ||
                sharedContext == NULL ||
                (sharedContext != NULL && sharedContext->process_id != npid))
            {
                // do some clean
                if (sharedContext != NULL)
                {
                    mh_cmd_close(sharedContext);
                    MH_free(sharedContext);
                    MHSaveGlobalContext(NULL);
                    sharedContext = NULL;
                }
                
                // create new context
                MHContext *context = MH_new();
                int flag = mh_cmd_auth_open(context, (pid_t)pid);
                if (flag != 0)
                {
                    lua_pushboolean(L, false);
                    lua_pushstring(L, ([[NSString stringWithFormat:@"cannot open process %d", (pid_t) pid] UTF8String]));
                    MH_free(context);
                    return 2;
                }
                
                // update shared context
                MHSaveGlobalContext(context);
                sharedContext = context;
                
                // fetch entries
                int entry_siz = 0;
                struct search_entry *entries = NULL;
                mh_copy_entries_for_array(&entries, &entry_siz, tb, type);
                
                // do initial search
                mach_vm_address_t address = (mach_vm_address_t) addr;
                int result = mh_cmd_search_entries(sharedContext, entries, entry_siz, address, (int) searchValueMax);
                if (result != 0)
                { // error occured
                    
                }
            }
            else
            {
                // fetch entries
                int entry_siz = 0;
                struct search_entry *entries = NULL;
                mh_copy_entries_for_array(&entries, &entry_siz, tb, type);
                
                // update search in context
                int result = mh_cmd_update_search_entries(sharedContext, entries, entry_siz);
                if (result != 0)
                { // error occured
                    if (result == -1)
                    { // no such case
                        
                    }
                    else if (result == -2)
                    { // empty result collection
                        // lua_pushboolean(L, false);
                        // lua_pushstring(L, "no result left");
                        // return 2;
                    }
                }
            }
            
            // generate result
            size_t capacity = sharedContext->result_count;
            NSMutableArray *addrs = [[NSMutableArray alloc] initWithCapacity:(NSUInteger)capacity];
            struct result_entry *np = NULL;
            STAILQ_FOREACH(np, &sharedContext->results, next)
            {
                [addrs addObject:@(np->address)];
            }
            lua_pushboolean(L, true);
            lua_pushNSValuex(L, addrs, 0);
            return 2;
        }
    };
    _EEND(memory)
}


_EFUNC(MHGetProcessID) {
    _EBEGIN
    _EPOOL {
        const char *bid = luaL_checkstring(L, 1);
        pid_t pid = mh_pid_for_running_application_identifier(bid);
        if (pid == 0) {
            lua_pushboolean(L, false);
            lua_pushnil(L);
            return 2;
        }
        lua_pushboolean(L, true);
        lua_pushinteger(L, pid);
        return 2;
    };
    _EEND(memory)
}


_EFUNC(MHGetVersion) {
    _EBEGIN
    _EPOOL {
        lua_pushstring(L, "0.3");
        return 1;
    };
    _EEND(memory)
}


_ELIB(memory) = {
    // --------
    _EREG(LuaE_MHRead, "read"),
    // --------
    _EREG(LuaE_MHWrite, "write"),
    // --------
    _EREG(LuaE_MHSearch, "search"),
    // --------
    _EREG(LuaE_MHSearchReset, "reset_search"),
    // --------
    _EREG(LuaE_MHSearchSetMode, "set_search_mode"),
    // --------
    _EREG(LuaE_MHGetBaseAddress, "get_base_address"),
    // --------
    _EREG(LuaE_MHGetProcessID, "get_process_id"),
    // --------
    _EREG(LuaE_MHGetVersion, "get_version"),
    // --------
    {NULL, NULL}
    // --------
};

_ELIB_API(memory);
_ELIB_API(memory) {
    luaE_newelib(L, LUAE_LIB_FUNCS_memory);
    return 1;
}

