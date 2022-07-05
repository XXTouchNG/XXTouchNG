//
//  extends.m
//  XXTExplorer
//
//  Created by Zheng on 03/01/2018.
//  Copyright © 2018 Zheng. All rights reserved.
//

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import <Foundation/Foundation.h>

#import <stdio.h>
#import <stdlib.h>
#import <unistd.h>
#import <sys/types.h>
#import <sys/stat.h>
#import <spawn.h>
#import <sys/utsname.h>
#import <notify.h>

#import "luae.h"


#pragma mark - Transformers

static void lua_pushJSONObject(lua_State *L, NSData *jsonData)
{
    @autoreleasepool {
        NSError *error = nil;
        id value = [NSJSONSerialization JSONObjectWithData:jsonData
                                                   options:NSJSONReadingAllowFragments
                                                     error:&error];
        lua_pushNSValuex(L, value, 0);
    }
}

static NSData *lua_toJSONData(lua_State *L, int index)
{
    @autoreleasepool {
        id value = lua_toNSValuex(L, index, 0);
        if (value != nil) {
            NSError *error = nil;
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:value
                                                               options:NSJSONWritingPrettyPrinted
                                                                 error:&error];
            if (jsonData != nil) {
                return jsonData;
            } else {
                return nil;
            }
        } else {
            return nil;
        }
    }
}


#pragma mark - JSON

static int l_json_decode(lua_State *L)
{
    size_t l;
    const char *json_cstr = luaL_checklstring(L, 1, &l);
    @autoreleasepool {
        NSData *jsonData = [NSData dataWithBytes:json_cstr length:l];
        lua_pushJSONObject(L, jsonData);
    }
    return 1;
}

static int l_json_encode(lua_State *L)
{
    @autoreleasepool {
        NSData *jsonData = lua_toJSONData(L, 1);
        if (jsonData != nil) {
            lua_pushlstring(L, (const char *)[jsonData bytes], [jsonData length]);
        } else {
            lua_pushnil(L);
        }
    }
    return 1;
}

static int luaopen_json(lua_State *L)
{
    lua_createtable(L, 0, 4);
    lua_pushcfunction(L, l_json_decode);
    lua_setfield(L, -2, "decode");
    lua_pushcfunction(L, l_json_encode);
    lua_setfield(L, -2, "encode");
    lua_pushlightuserdata(L, (void *)NULL);
    lua_setfield(L, -2, "null");
    lua_pushliteral(L, "0.5");
    lua_setfield(L, -2, "_VERSION");
    return 1;
}


#pragma mark - Property List

static int l_plist_read(lua_State *L)
{
    const char *filename_cstr = luaL_checkstring(L, 1);
    @autoreleasepool {
        NSString *filename = [NSString stringWithUTF8String:filename_cstr];
        if (filename != nil) {
            id value = [NSDictionary dictionaryWithContentsOfFile:filename];
            if (value != nil) {
                lua_pushNSDictionary(L, value);
            } else {
                value = [NSArray arrayWithContentsOfFile:filename];
                if (value != nil) {
                    lua_pushNSArray(L, value);
                } else {
                    lua_pushnil(L);
                }
            }
        } else {
            lua_pushnil(L);
        }
    }
    return 1;
}

static int l_plist_write(lua_State *L)
{
    const char *filename_cstr = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    @autoreleasepool {
        id value = lua_toNSValuex(L, 2, 0);
        NSString *filename = [NSString stringWithUTF8String:filename_cstr];
        if (filename != nil && ([value isKindOfClass:[NSArray class]] || [value isKindOfClass:[NSDictionary class]])) {
            lua_pushboolean(L, [value writeToFile:filename atomically:YES]);
        } else {
            lua_pushboolean(L, NO);
        }
    }
    return 1;
}

static int l_plist_load(lua_State *L)
{
    const char *filename_cstr = luaL_checkstring(L, 1);
    @autoreleasepool {
        NSString *filename = [NSString stringWithUTF8String:filename_cstr];
        if (filename != nil) {
            NSData *plistData = [NSData dataWithContentsOfFile:filename];
            if (plistData != nil) {
                NSError *err = nil;
                id value = [NSPropertyListSerialization propertyListWithData:plistData options:kNilOptions format:nil error:&err];
                if (value) {
                    lua_pushNSValue(L, value);
                } else {
                    lua_pushnil(L);
                }
            } else {
                lua_pushnil(L);
            }
        } else {
            lua_pushnil(L);
        }
    }
    return 1;
}

static int l_plist_dump(lua_State *L)
{
    luaL_checktype(L, 1, LUA_TTABLE);
    id value = lua_toNSValue(L, 1);
    const char *cFormat = luaL_optstring(L, 2, "XML");
    NSPropertyListFormat format = NSPropertyListXMLFormat_v1_0;
    if (strcmp(cFormat, "XML") == 0) {
        format = NSPropertyListXMLFormat_v1_0;
    }
    else if (strcmp(cFormat, "binary") == 0) {
        format = NSPropertyListBinaryFormat_v1_0;
    }
    else {
        lua_pushnil(L);
        return 1;
    }
    
    @autoreleasepool {
        if ([NSPropertyListSerialization propertyList:value isValidForFormat:format]) {
            NSError *err = nil;
            NSData *data = [NSPropertyListSerialization dataWithPropertyList:value format:format options:kNilOptions error:&err];
            if (data != nil) {
                lua_pushlstring(L, (const char *)data.bytes, data.length);
            } else {
                lua_pushnil(L);
            }
        } else {
            lua_pushnil(L);
        }
    }
    return 1;
}

static int luaopen_plist(lua_State *L)
{
    lua_createtable(L, 0, 5);
    lua_pushcfunction(L, l_plist_read);
    lua_setfield(L, -2, "read");
    lua_pushcfunction(L, l_plist_write);
    lua_setfield(L, -2, "write");
    lua_pushcfunction(L, l_plist_load);
    lua_setfield(L, -2, "load");
    lua_pushcfunction(L, l_plist_dump);
    lua_setfield(L, -2, "dump");
    lua_pushliteral(L, "0.5");
    lua_setfield(L, -2, "_VERSION");
    return 1;
}


#pragma mark - OS

extern "C" char **environ;

static int lua_xxtSystem(const char *ctx)
{
    const char *binsh_path = NULL;
    
    struct stat bStat;
    if (0 == lstat("/bootstrap/bin/sh", &bStat)) {
        binsh_path = "/bootstrap/bin/sh";
    } else {
        binsh_path = "/bin/sh";
    }
    
    const char *args[] = {
        binsh_path,
        "-c",
        ctx,
        NULL
    };
    
    pid_t pid;
    if (posix_spawn(&pid, binsh_path, NULL, NULL, (char **)args, environ) != 0) {
        return -1;
    } else {
        int status = 0;
        waitpid(pid, &status, 0);
        return status;
    }
}

static int l_os_execute(lua_State *L)
{
    const char *cmd = luaL_optstring(L, 1, NULL);
    int stat = lua_xxtSystem(cmd);
    if (cmd != NULL)
        return luaL_execresult(L, stat);
    else {
        lua_pushboolean(L, stat);  /* true if there is a shell */
        return 1;
    }
}

static int l_os_tmpname(lua_State *L)
{
    @autoreleasepool {
        NSString *identifier    = [[NSProcessInfo processInfo] globallyUniqueString];
        NSString *tmpNameString = [NSString stringWithFormat:@"lua_%@", identifier];
        NSString *tmpPathString = [NSTemporaryDirectory() stringByAppendingPathComponent:tmpNameString];
        lua_pushstring(L, [tmpPathString UTF8String]);
        return 1;
    }
}


#pragma mark - Notify Post

static int l_notify_post(lua_State *L)
{
    const char *notify_name = luaL_checkstring(L, 1);
    lua_pushinteger(L, notify_post(notify_name));
    return 1;
}


#pragma mark - Handle Signals

static boolean_t _l_signal_pause = false;

static void l_pause_hook(lua_State *L, lua_Debug *ar)
{
    while (_l_signal_pause) {
        // use usleep to delay 0.001 second
        usleep(1000);
    }
}

static void l_signal_stop(int signal)
{
    _l_signal_pause = true;
}

static void l_signal_cont(int signal)
{
    _l_signal_pause = false;
}


#pragma mark - Library Import

#ifndef XXT_VERSION
#define XXT_VERSION "3.0.1"
#endif

OBJC_EXTERN
int xxtouch_extends(lua_State *L);

int xxtouch_extends(lua_State *L)
{
    {  // _VERSION
        lua_pushliteral(L, XXT_VERSION);
        lua_setglobal(L, "_XTVERSION");
    }
    
    {  // json
        luaL_requiref(L, "json", luaopen_json, YES);
        lua_pop(L, 1);
    }

    {  // plist
        luaL_requiref(L, "plist", luaopen_plist, YES);
        lua_pop(L, 1);
    }

    {  // replace os.execute
        lua_getglobal(L, "os");
        lua_pushcfunction(L, l_os_execute);
        lua_setfield(L, -2, "execute");
        lua_pop(L, 1);
    }

    {  // replace os.tmpname
        lua_getglobal(L, "os");
        lua_pushcfunction(L, l_os_tmpname);
        lua_setfield(L, -2, "tmpname");
        lua_pop(L, 1);
    }
    
    {  // add notify_post
        lua_pushcfunction(L, l_notify_post);
        lua_setglobal(L, "notify_post");
    }
    
    {
        // setup pause hook
        lua_sethook(L, l_pause_hook, LUA_MASKLINE, 0);
    }
    
    {
        // handle SIGSTOP signal
        struct sigaction act, oldact;
        act.sa_handler = &l_signal_stop;
        sigaction(SIGSTOP, &act, &oldact);
    }

    {
        // handle SIGCONT signal
        struct sigaction act, oldact;
        act.sa_handler = &l_signal_cont;
        sigaction(SIGCONT, &act, &oldact);
    }
    
    return 0;
}

