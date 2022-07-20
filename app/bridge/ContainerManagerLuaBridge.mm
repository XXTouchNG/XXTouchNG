#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import "luae.h"
#import <mach/mach.h>
#import "TFContainerManager.h"


#pragma mark -

_ELIB_DECL(app);


#pragma mark -

#define luaE_optboolean(L, IDX, DEF) \
(BOOL)(lua_isboolean((L), (IDX)) ? lua_toboolean(L, (IDX)) : (DEF))


#pragma mark -

_EFUNC(CMGetBundlePath) {
    _EBEGIN
    _EPOOL {
        const char *cBid = luaL_checkstring(L, 1);
        NSString *bid = [NSString stringWithUTF8String:cBid];
        
        NSError *err = nil;
        TFAppItem *appItem = [[TFContainerManager sharedManager] appItemForIdentifier:bid options:TFContainerManagerFetchWithSystemApplications error:&err];
        
        if (!appItem) {
            lua_pushnil(L);
            return 1;
        }
        
        if (![[appItem bundlePath] length]) {
            lua_pushnil(L);
            return 1;
        }
        
        lua_pushstring(L, [[appItem bundlePath] UTF8String]);
        return 1;
    }
    _EEND(app)
}


_EFUNC(CMGetDataContainerPath) {
    _EBEGIN
    _EPOOL {
        const char *cBid = luaL_checkstring(L, 1);
        NSString *bid = [NSString stringWithUTF8String:cBid];
        
        NSError *err = nil;
        TFAppItem *appItem = [[TFContainerManager sharedManager] appItemForIdentifier:bid options:TFContainerManagerFetchWithSystemApplications error:&err];
        
        if (!appItem) {
            lua_pushnil(L);
            return 1;
        }
        
        if (!appItem.dataContainer.length) {
            lua_pushnil(L);
            return 1;
        }
        
        lua_pushstring(L, [[appItem dataContainer] UTF8String]);
        return 1;
    }
    _EEND(app)
}


_EFUNC(CMGetGroupContainerPaths) {
    _EBEGIN
    _EPOOL {
        const char *cBid = luaL_checkstring(L, 1);
        NSString *bid = [NSString stringWithUTF8String:cBid];
        
        NSError *err = nil;
        TFAppItem *appItem = [[TFContainerManager sharedManager] appItemForIdentifier:bid options:TFContainerManagerFetchWithSystemApplications error:&err];
        
        if (!appItem) {
            lua_pushnil(L);
            return 1;
        }
        
        NSDictionary <NSString *, NSString *> *groupContainerPathDict = appItem.groupContainers;
        NSArray <NSString *> *sortedKeys = [groupContainerPathDict.allKeys sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"self" ascending:YES]]];
        NSArray <NSString *> *sortedPaths = [groupContainerPathDict objectsForKeys:sortedKeys notFoundMarker:@"NOT_FOUND"];
        lua_pushNSArray(L, sortedPaths);
        return 1;
    }
    _EEND(app)
}


_EFUNC(CMGetGroupContainerMappings) {
    _EBEGIN
    _EPOOL {
        const char *cBid = luaL_checkstring(L, 1);
        NSString *bid = [NSString stringWithUTF8String:cBid];
        
        NSError *err = nil;
        TFAppItem *appItem = [[TFContainerManager sharedManager] appItemForIdentifier:bid options:TFContainerManagerFetchWithSystemApplications error:&err];
        
        if (!appItem) {
            lua_pushnil(L);
            return 1;
        }
        
        lua_pushNSDictionary(L, appItem.groupContainers);
        return 1;
    }
    _EEND(app)
}


_EFUNC(CMRunApplication) {
    _EBEGIN
    _EPOOL {
        const char *cBid = luaL_checkstring(L, 1);
        NSString *bid = [NSString stringWithUTF8String:cBid];
        
        NSError *err = nil;
        BOOL launched = [[TFContainerManager sharedManager] launchAppWithIdentifier:bid inBackground:NO error:&err];
        
        if (!launched) {
            lua_pushinteger(L, EXIT_FAILURE);
            return 1;
        }
        
        lua_pushinteger(L, EXIT_SUCCESS);
        return 1;
    }
    _EEND(app)
}


_EFUNC(CMTerminateApplication) {
    _EBEGIN
    _EPOOL {
        BOOL terminated;
        if (lua_type(L, 1) == LUA_TSTRING) {
            const char *cBid = luaL_checkstring(L, 1);
            NSString *bid = [NSString stringWithUTF8String:cBid];
            
            if ([bid isEqualToString:@"*"]) {
                terminated = [[TFContainerManager sharedManager] terminateAllApp];
            } else {
                terminated = [[TFContainerManager sharedManager] terminateAppWithIdentifier:bid];
            }
        } else {
            pid_t pid = (pid_t)luaL_checkinteger(L, 1);
            terminated = kill(pid, SIGKILL) == 0;
        }
        
        if (!terminated) {
            lua_pushinteger(L, EXIT_FAILURE);
            return 1;
        }
        
        lua_pushinteger(L, EXIT_SUCCESS);
        return 1;
    }
    _EEND(app)
}


_EFUNC(CMIsRunningApplication) {
    _EBEGIN
    _EPOOL {
        const char *cBid = luaL_checkstring(L, 1);
        NSString *bid = [NSString stringWithUTF8String:cBid];
        
        pid_t processIdentifier = [[TFContainerManager sharedManager] processIdentifierForAppIdentifier:bid];
        lua_pushboolean(L, processIdentifier > 0);
        return 1;
    }
    _EEND(app)
}


_EFUNC(CMGetLocalizedName) {
    _EBEGIN
    _EPOOL {
        const char *cBid = luaL_checkstring(L, 1);
        NSString *bid = [NSString stringWithUTF8String:cBid];
        
        NSError *err = nil;
        TFAppItem *appItem = [[TFContainerManager sharedManager] appItemForIdentifier:bid options:TFContainerManagerFetchWithSystemApplications error:&err];
        
        if (!appItem.name.length) {
            lua_pushnil(L);
            return 1;
        }
        
        lua_pushstring(L, [appItem.name UTF8String]);
        return 1;
    }
    _EEND(app)
}


_EFUNC(CMGetIconData) {
    _EBEGIN
    _EPOOL {
        const char *cBid = luaL_checkstring(L, 1);
        NSString *bid = [NSString stringWithUTF8String:cBid];
        
        NSError *err = nil;
        TFAppItem *appItem = [[TFContainerManager sharedManager] appItemForIdentifier:bid options:(TFContainerManagerFetchWithSystemApplications | TFContainerManagerFetchWithIconData) error:&err];
        
        if (!appItem.iconData) {
            lua_pushnil(L);
            return 1;
        }
        
        NSData *iconData = appItem.iconData;
        lua_pushlstring(L, (const char *)iconData.bytes, iconData.length);
        return 1;
    }
    _EEND(app)
}


_EFUNC(CMGetProcessIdentifier) {
    _EBEGIN
    _EPOOL {
        const char *cBid = luaL_checkstring(L, 1);
        NSString *bid = [NSString stringWithUTF8String:cBid];
        
        pid_t processIdentifier = [[TFContainerManager sharedManager] processIdentifierForAppIdentifier:bid];
        
        lua_pushinteger(L, processIdentifier);
        return 1;
    }
    _EEND(app)
}


_EFUNC(CMGetFrontmostBundleIdentifier) {
    _EBEGIN
    _EPOOL {
        NSError *err = nil;
        NSString *bundleIdentifier = [[TFContainerManager sharedManager] frontmostAppIdentifierWithError:&err];
        
        if (!bundleIdentifier.length) {
            lua_pushnil(L);
            return 1;
        }
        
        lua_pushstring(L, [bundleIdentifier UTF8String]);
        return 1;
    }
    _EEND(app)
}


_EFUNC(CMGetFrontmostProcessIdentifier) {
    _EBEGIN
    _EPOOL {
        NSError *err = nil;
        NSString *bundleIdentifier = [[TFContainerManager sharedManager] frontmostAppIdentifierWithError:&err];
        
        if (!bundleIdentifier.length) {
            lua_pushnil(L);
            return 1;
        }
        
        pid_t processIdentifier = [[TFContainerManager sharedManager] processIdentifierForAppIdentifier:bundleIdentifier];
        lua_pushinteger(L, processIdentifier);
        return 1;
    }
    _EEND(app)
}


_EFUNC(CMOpenSensitiveURL) {
    _EBEGIN
    _EPOOL {
        const char *cBid = luaL_checkstring(L, 1);
        NSString *bid = [NSString stringWithUTF8String:cBid];
        
        NSError *err = nil;
        BOOL opened = [[TFContainerManager sharedManager] openSensitiveURLWithString:bid error:&err];
        
        lua_pushboolean(L, opened);
        return 1;
    }
    _EEND(app)
}


_EFUNC(CMGetAllBundleIdentifiers) {
    _EBEGIN
    _EPOOL {
        NSError *err = nil;
        NSArray <TFAppItem *> *appItems = [[TFContainerManager sharedManager] appItemsWithOptions:TFContainerManagerFetchWithSystemApplications error:&err];
        NSMutableArray <NSString *> *bundleIdentifiers = [NSMutableArray arrayWithCapacity:appItems.count];
        
        for (TFAppItem *appItem in appItems) {
            [bundleIdentifiers addObject:appItem.identifier];
        }
        lua_pushNSArray(L, bundleIdentifiers);
        return 1;
    }
    _EEND(app)
}


_EFUNC(CMGetRunningProcs) {
    _EBEGIN
    _EPOOL {
        NSError *err = nil;
        NSArray <TFAppItem *> *appItems = [[TFContainerManager sharedManager] runningAppItemsWithOptions:TFContainerManagerFetchWithSystemApplications error:&err];
        NSMutableArray <NSDictionary *> *retProcs = [NSMutableArray arrayWithCapacity:appItems.count];
        for (TFAppItem *appItem in appItems) {
            NSMutableDictionary *retProc = [NSMutableDictionary dictionaryWithObjectsAndKeys:appItem.identifier, @"bid", @(appItem.processIdentifier), @"pid", nil];
            if (appItem.name) {
                [retProc setObject:appItem.name forKey:@"name"];
            }
            [retProcs addObject:retProc];
        }
        
        lua_pushNSDictionary(L, retProcs);
        return 1;
    }
    _EEND(app)
}


_EFUNC(CMInstall) {
    _EBEGIN
    _EPOOL {
        const char *cPath = luaL_checkstring(L, 1);
        NSString *path = [NSString stringWithUTF8String:cPath];
        
        NSError *err = nil;
        BOOL installed = [[TFContainerManager sharedManager] installIPAArchiveAtPath:path removeAfterInstallation:NO error:&err];
        
        lua_pushboolean(L, installed);
        if (installed) {
            lua_pushnil(L);
        } else {
            lua_pushstring(L, [[NSString stringWithFormat:@"%@", err.localizedDescription] UTF8String]);
        }
        return 2;
    }
    _EEND(app)
}


_EFUNC(CMUninstall) {
    _EBEGIN
    _EPOOL {
        const char *cBid = luaL_checkstring(L, 1);
        NSString *bid = [NSString stringWithUTF8String:cBid];
        
        NSError *err = nil;
        BOOL uninstalled = [[TFContainerManager sharedManager] uninstallApplicationWithIdentifier:bid error:&err];
        
        lua_pushboolean(L, uninstalled);
        if (uninstalled) {
            lua_pushnil(L);
        } else {
            lua_pushstring(L, [[NSString stringWithFormat:@"%@", err.localizedDescription] UTF8String]);
        }
        return 2;
    }
    _EEND(app)
}

_EFUNC(CMUsedMemory) {
    _EBEGIN
    _EPOOL {
        pid_t pid;
        if (lua_type(L, 1) == LUA_TSTRING) {
            const char *cBundleID = luaL_checkstring(L, 1);
            NSString *bundleID = [NSString stringWithUTF8String:cBundleID];
            pid = [[TFContainerManager sharedManager] processIdentifierForAppIdentifier:bundleID];
        } else {
            pid = (pid_t)luaL_checkinteger(L, 1);
        }
        
        if (pid <= 0) {
            lua_pushnil(L);
            return 1;
        }
        
        task_basic_info_data_t taskInfo;
        mach_msg_type_number_t infoCount = TASK_BASIC_INFO_COUNT;
        
        mach_port_t task;
        kern_return_t kernReturn;
        
        kernReturn = task_for_pid(mach_task_self(), pid, &task);
        if (kernReturn != KERN_SUCCESS) {
            lua_pushnil(L);
            return 1;
        }
        
        kernReturn = task_info(task,
                               TASK_BASIC_INFO,
                               (task_info_t)&taskInfo,
                               &infoCount);
        
        mach_port_deallocate(mach_task_self(), task);
        
        if (kernReturn != KERN_SUCCESS) {
            lua_pushnil(L);
            return 1;
        }
        
        lua_pushnumber(L, taskInfo.resident_size / 1024.0 / 1024.0);
        return 1;
    }
    _EEND(app)
}


#pragma mark -

_ELIB(app) = {
    _EREG(LuaE_CMGetBundlePath,                  "bundle_path"       ),  // bundle_path
    _EREG(LuaE_CMGetDataContainerPath,           "data_path"         ),  // data_path
    _EREG(LuaE_CMGetGroupContainerPaths,         "group_paths"       ),
    _EREG(LuaE_CMGetGroupContainerMappings,      "group_info"        ),  // group_info
    _EREG(LuaE_CMRunApplication,                 "run"               ),  // run
    _EREG(LuaE_CMTerminateApplication,           "quit"              ),  // quit/close
    _EREG(LuaE_CMTerminateApplication,           "close"             ),  // quit/close
    _EREG(LuaE_CMIsRunningApplication,           "is_running"        ),  // is_running
    _EREG(LuaE_CMGetLocalizedName,               "localized_name"    ),  // localized_name
    _EREG(LuaE_CMGetIconData,                    "png_data_for_bid"  ),  // png_data_for_bid
    _EREG(LuaE_CMGetProcessIdentifier,           "pid_for_bid"       ),  // pid_for_bid
    _EREG(LuaE_CMGetFrontmostProcessIdentifier,  "front_pid"         ),  // front_pid
    _EREG(LuaE_CMGetFrontmostBundleIdentifier,   "front_bid"         ),  // front_bid
    _EREG(LuaE_CMOpenSensitiveURL,               "open_url"          ),  // open_url
    _EREG(LuaE_CMGetAllBundleIdentifiers,        "bundles"           ),  // bundles
    _EREG(LuaE_CMGetRunningProcs,                "all_procs"         ),  // all_procs
    _EREG(LuaE_CMInstall,                        "install"           ),  // install
    _EREG(LuaE_CMUninstall,                      "uninstall"         ),  // uninstall
    _EREG(LuaE_CMUsedMemory,                     "used_memory"       ),  // used_memory
    {NULL, NULL}
};


#pragma mark -

_ELIB_API(app);
_ELIB_API(app) {
    luaE_newelib(L, LUAE_LIB_FUNCS_app);
    return 1;
}

_ELIB_API(exapp);
_ELIB_API(exapp) {
    luaE_newelib(L, LUAE_LIB_FUNCS_app);
    return 1;
}
