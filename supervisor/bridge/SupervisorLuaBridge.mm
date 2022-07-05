#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import "lua.hpp"
#import "Supervisor.h"


#pragma mark -

XXTouchF_CAPI int luaopen_xxtouch_scheduler(lua_State *);


#pragma mark -

static int l_os_restart(lua_State *L)
{
    @autoreleasepool {
        const char *cRestartName = luaL_optstring(L, 1, getenv("XXT_ENTRYPOINT") ?: "");
        NSString *restartName = [NSString stringWithUTF8String:cRestartName];
        
        lua_Number cTimeout = luaL_optnumber(L, 2, 2000);
        cTimeout /= 1e3;
        
        if ([restartName hasPrefix:@"/private/var/"])
            restartName = [restartName substringFromIndex:8];
        
        NSURL *restartURL = nil;
        if ([restartName hasPrefix:@"/var/tmp/NSIRD_"] && [restartName hasSuffix:@"/data"]) {
            restartURL = [NSURL fileURLWithPath:restartName];
        } else {
            if ([restartName hasPrefix:@MEDIA_LUA_SCRIPTS_DIR "/"])
                restartName = [restartName substringFromIndex:sizeof(MEDIA_LUA_SCRIPTS_DIR)];
            
            if ([restartName hasPrefix:@"/"])
                restartName = [restartName substringFromIndex:1];
            
            NSMutableArray <NSString *> *scriptNameComponents = [[restartName componentsSeparatedByString:@"/"] mutableCopy];
            [scriptNameComponents removeObject:@"."];
            [scriptNameComponents removeObject:@".."];
            restartName = [scriptNameComponents componentsJoinedByString:@"/"];
            
            if (!restartName.length)
            {
                lua_pushboolean(L, false);
                lua_pushstring(L, "Invalid file path");
                return 2;
            }
            
            NSString *scriptExtension = [[restartName pathExtension] lowercaseString] ?: @"";
            if (scriptExtension.length > 0 &&  /* empty extension is allowed due to dynamic spawn */
                ![scriptExtension isEqualToString:@"lua"] &&
                ![scriptExtension isEqualToString:@"luac"] &&
                ![scriptExtension isEqualToString:@"xxt"])
            {
                lua_pushboolean(L, false);
                lua_pushstring(L, [[NSString stringWithFormat:@"Unsupported file extension: %@", scriptExtension] UTF8String]);
                return 2;
            }
            
            NSURL *rootURL = [NSURL fileURLWithPath:@MEDIA_LUA_SCRIPTS_DIR];
            restartURL = [NSURL fileURLWithPath:restartName relativeToURL:rootURL];
        }
        
        if (!restartURL.path.length)
        {
            lua_pushboolean(L, false);
            lua_pushstring(L, "Invalid file path");
            return 2;
        }
        
        NSError *err = nil;
        BOOL reachable = [restartURL checkResourceIsReachableAndReturnError:&err];
        if (!reachable)
        {
            lua_pushboolean(L, false);
            lua_pushstring(L, [[err localizedDescription] UTF8String]);
            return 2;
        }
        
        BOOL scheduled = [[Supervisor sharedInstance] scheduleLaunchOfScriptAtPath:restartURL.path
                                                                           timeout:MIN(MAX(cTimeout, 1.0), 5.0)
                                                                             error:&err];
        if (!scheduled)
        {
            lua_pushboolean(L, false);
            lua_pushstring(L, [[err localizedDescription] UTF8String]);
            return 2;
        }
        
        exit(EXIT_SUCCESS);
    }
}


#pragma mark -

XXTouchF_CAPI int luaopen_xxtouch_scheduler(lua_State *L)
{
    {  // os.restart
        lua_getglobal(L, "os");
        lua_pushcfunction(L, l_os_restart);
        lua_setfield(L, -2, "restart");
        lua_pop(L, 1);
    }
    
    return 0;
}
