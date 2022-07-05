#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import <UIKit/UIKit.h>
#import "luae.h"
#import "FileHash.h"


static NSFileManager *_sharedFileManager = nil;
static dispatch_queue_t _sharedQueue;

static int l_file_exists(lua_State *L)
{
    @autoreleasepool {
        const char *cPath = luaL_checkstring(L, 1);
        NSString *path = [NSString stringWithUTF8String:cPath];
        
        __block BOOL pathExists = NO;
        __block BOOL isDirectory = NO;
        dispatch_sync(_sharedQueue, ^{
            pathExists = [_sharedFileManager fileExistsAtPath:path isDirectory:&isDirectory];
        });
        
        if (!pathExists) {
            lua_pushboolean(L, false);
            return 1;
        }
        
        if (isDirectory) {
            lua_pushstring(L, "directory");
        } else {
            lua_pushstring(L, "file");
        }
        
        return 1;
    }
}

static int l_file_list(lua_State *L)
{
    @autoreleasepool {
        const char *cPath = luaL_checkstring(L, 1);
        NSString *path = [NSString stringWithUTF8String:cPath];
        
        __block NSArray <NSString *> *dirContents = nil;
        dispatch_sync(_sharedQueue, ^{
            dirContents = [_sharedFileManager contentsOfDirectoryAtPath:path error:nil];
        });
        
        if (!dirContents) {
            lua_pushnil(L);
        } else {
            lua_pushNSArray(L, dirContents);
        }
        
        return 1;
    }
}

static int l_file_size(lua_State *L)
{
    @autoreleasepool {
        const char *cPath = luaL_checkstring(L, 1);
        NSString *path = [NSString stringWithUTF8String:cPath];
        
        __block NSDictionary <NSFileAttributeKey, id> *attrs = nil;
        dispatch_sync(_sharedQueue, ^{
            attrs = [_sharedFileManager attributesOfItemAtPath:path error:nil];
        });
        
        if (!attrs[NSFileSize]) {
            lua_pushnil(L);
        } else {
            lua_pushinteger(L, (lua_Integer)[attrs[NSFileSize] unsignedLongLongValue]);
        }
        
        return 1;
    }
}

static int l_file_reads(lua_State *L)
{
    @autoreleasepool {
        const char *cPath = luaL_checkstring(L, 1);
        NSString *path = [NSString stringWithUTF8String:cPath];
        
        __block NSData *contents = nil;
        dispatch_sync(_sharedQueue, ^{
            contents = [_sharedFileManager contentsAtPath:path];
        });
        
        if (!contents) {
            lua_pushnil(L);
        } else {
            lua_pushlstring(L, (const char *)contents.bytes, contents.length);
        }
        
        return 1;
    }
}

static int l_file_writes(lua_State *L)
{
    @autoreleasepool {
        const char *cPath = luaL_checkstring(L, 1);
        
        size_t cLen;
        const char *cContents = luaL_checklstring(L, 2, &cLen);
        
        NSString *path = [NSString stringWithUTF8String:cPath];
        NSData *contents = [NSData dataWithBytesNoCopy:(void *)cContents length:cLen freeWhenDone:NO];
        
        __block BOOL created = NO;
        dispatch_sync(_sharedQueue, ^{
            @autoreleasepool {
                BOOL targetIsDirectory = NO;
                BOOL targetExists = [_sharedFileManager fileExistsAtPath:path isDirectory:&targetIsDirectory];
                if (targetExists && !targetIsDirectory) {
                    BOOL removed = [_sharedFileManager removeItemAtPath:path error:nil];
                    if (!removed)
                        return;
                }
                
                created = [_sharedFileManager createFileAtPath:path contents:contents attributes:nil];
            }
        });
        
        lua_pushboolean(L, created);
        return 1;
    }
}

static int l_file_appends(lua_State *L)
{
    @autoreleasepool {
        const char *cPath = luaL_checkstring(L, 1);
        
        size_t cLen;
        const char *cContents = luaL_checklstring(L, 2, &cLen);
        
        NSString *path = [NSString stringWithUTF8String:cPath];
        NSData *contents = [NSData dataWithBytesNoCopy:(void *)cContents length:cLen freeWhenDone:NO];
        
        __block BOOL created = NO;
        dispatch_sync(_sharedQueue, ^{
            @autoreleasepool {
                NSMutableData *data = [[_sharedFileManager contentsAtPath:path] mutableCopy];
                if (!data)
                    return;
                [data appendData:contents];
                created = [_sharedFileManager createFileAtPath:path contents:data attributes:nil];
            }
        });
        
        lua_pushboolean(L, created);
        return 1;
    }
}

static int l_file_line_count(lua_State *L)
{
    @autoreleasepool {
        const char *cPath = luaL_checkstring(L, 1);
        NSString *path = [NSString stringWithUTF8String:cPath];
        
        __block BOOL succeed = NO;
        __block size_t num = 0;
        dispatch_sync(_sharedQueue, ^{
            @autoreleasepool {
                NSData *contents = [_sharedFileManager contentsAtPath:path];
                if (!contents)
                    return;
                
                NSString *strContents = [[NSString alloc] initWithData:contents encoding:NSUTF8StringEncoding];
                if (!strContents)
                    return;
                
                succeed = YES;
                
                NSArray <NSString *> *strLines = [strContents componentsSeparatedByString:@"\n"];
                num = strLines.count;
            }
        });
        
        if (!succeed) {
            lua_pushnil(L);
        } else {
            lua_pushinteger(L, num);
        }
        return 1;
    }
}

static int l_file_get_line(lua_State *L)
{
    @autoreleasepool {
        const char *cPath = luaL_checkstring(L, 1);
        NSString *path = [NSString stringWithUTF8String:cPath];
        
        lua_Integer cLineIndex = luaL_checkinteger(L, 2);
        if (cLineIndex == 0) {
            lua_pushnil(L);
            return 1;
        }
        
        BOOL reversed = cLineIndex <= 0;
        if (reversed) {
            cLineIndex = -cLineIndex;
        }
        
        __block NSString *output = nil;
        dispatch_sync(_sharedQueue, ^{
            
            @autoreleasepool {
                NSData *contents = [_sharedFileManager contentsAtPath:path];
                if (!contents)
                    return;
                
                NSString *strContents = [[NSString alloc] initWithData:contents encoding:NSUTF8StringEncoding];
                if (!strContents)
                    return;
                
                NSArray <NSString *> *strLines = [strContents componentsSeparatedByString:@"\n"];
                if (cLineIndex > strLines.count)
                    return;
                
                output = [strLines objectAtIndex:reversed ? strLines.count - cLineIndex : cLineIndex - 1];
            }
        });
        
        if (!output) {
            lua_pushnil(L);
        } else {
            lua_pushstring(L, output.UTF8String);
        }
        return 1;
    }
}

static int l_file_set_line(lua_State *L)
{
    @autoreleasepool {
        const char *cPath = luaL_checkstring(L, 1);
        NSString *path = [NSString stringWithUTF8String:cPath];
        
        lua_Integer cLineIndex = luaL_checkinteger(L, 2);
        if (cLineIndex == 0) {
            lua_pushnil(L);
            return 1;
        }
        
        const char *cRepl = luaL_checkstring(L, 3);
        NSString *repl = [NSString stringWithUTF8String:cRepl];
        
        BOOL reversed = cLineIndex <= 0;
        if (reversed) {
            cLineIndex = -cLineIndex;
        }
        
        __block BOOL succeed = NO;
        dispatch_sync(_sharedQueue, ^{
            
            @autoreleasepool {
                NSData *contents = [_sharedFileManager contentsAtPath:path];
                if (!contents)
                    return;
                
                NSString *strContents = [[NSString alloc] initWithData:contents encoding:NSUTF8StringEncoding];
                if (!strContents)
                    return;
                
                NSArray <NSString *> *strLines = [strContents componentsSeparatedByString:@"\n"];
                if (cLineIndex > strLines.count)
                    return;
                
                NSMutableArray <NSString *> *mLines = [strLines mutableCopy];
                [mLines setObject:repl atIndexedSubscript:reversed ? mLines.count - cLineIndex : cLineIndex - 1];
                strContents = [mLines componentsJoinedByString:@"\n"];
                
                NSData *outputData = [strContents dataUsingEncoding:NSUTF8StringEncoding];
                
                BOOL targetIsDirectory = NO;
                BOOL targetExists = [_sharedFileManager fileExistsAtPath:path isDirectory:&targetIsDirectory];
                if (targetExists && !targetIsDirectory) {
                    BOOL removed = [_sharedFileManager removeItemAtPath:path error:nil];
                    if (!removed)
                        return;
                }
                
                succeed = [_sharedFileManager createFileAtPath:path contents:outputData attributes:nil];
            }
        });
        
        lua_pushboolean(L, succeed);
        return 1;
    }
}

static int l_file_insert_line(lua_State *L)
{
    @autoreleasepool {
        const char *cPath = luaL_checkstring(L, 1);
        NSString *path = [NSString stringWithUTF8String:cPath];
        
        lua_Integer cLineIndex = luaL_checkinteger(L, 2);
        
        const char *cRepl = luaL_checkstring(L, 3);
        NSString *repl = [NSString stringWithUTF8String:cRepl];
        
        BOOL reversed = cLineIndex <= 0;
        if (reversed) {
            cLineIndex = -cLineIndex;
        }
        
        __block BOOL succeed = NO;
        dispatch_sync(_sharedQueue, ^{
            
            @autoreleasepool {
                NSData *contents = [_sharedFileManager contentsAtPath:path];
                if (!contents)
                    return;
                
                NSString *strContents = [[NSString alloc] initWithData:contents encoding:NSUTF8StringEncoding];
                if (!strContents)
                    return;
                
                NSArray <NSString *> *strLines = [strContents componentsSeparatedByString:@"\n"];
                if (cLineIndex > strLines.count)
                    return;
                
                NSMutableArray <NSString *> *mLines = [strLines mutableCopy];
                [mLines insertObject:repl atIndex:reversed ? mLines.count - cLineIndex : cLineIndex - 1];
                strContents = [mLines componentsJoinedByString:@"\n"];
                
                NSData *outputData = [strContents dataUsingEncoding:NSUTF8StringEncoding];
                
                BOOL targetIsDirectory = NO;
                BOOL targetExists = [_sharedFileManager fileExistsAtPath:path isDirectory:&targetIsDirectory];
                if (targetExists && !targetIsDirectory) {
                    BOOL removed = [_sharedFileManager removeItemAtPath:path error:nil];
                    if (!removed)
                        return;
                }
                
                succeed = [_sharedFileManager createFileAtPath:path contents:outputData attributes:nil];
            }
        });
        
        lua_pushboolean(L, succeed);
        return 1;
    }
}

static int l_file_remove_line(lua_State *L)
{
    @autoreleasepool {
        const char *cPath = luaL_checkstring(L, 1);
        NSString *path = [NSString stringWithUTF8String:cPath];
        
        lua_Integer cLineIndex = luaL_checkinteger(L, 2);
        if (cLineIndex == 0) {
            lua_pushboolean(L, false);
            lua_pushnil(L);
            return 2;
        }
        
        BOOL reversed = cLineIndex <= 0;
        if (reversed) {
            cLineIndex = -cLineIndex;
        }
        
        __block BOOL succeed = NO;
        __block NSString *removedLine = nil;
        dispatch_sync(_sharedQueue, ^{
            
            @autoreleasepool {
                NSData *contents = [_sharedFileManager contentsAtPath:path];
                if (!contents)
                    return;
                
                NSString *strContents = [[NSString alloc] initWithData:contents encoding:NSUTF8StringEncoding];
                if (!strContents)
                    return;
                
                NSArray <NSString *> *strLines = [strContents componentsSeparatedByString:@"\n"];
                if (cLineIndex > strLines.count)
                    return;
                
                NSMutableArray <NSString *> *mLines = [strLines mutableCopy];
                NSUInteger indexToRemove = reversed ? mLines.count - cLineIndex : cLineIndex - 1;
                removedLine = [mLines objectAtIndex:indexToRemove];
                [mLines removeObjectAtIndex:indexToRemove];
                strContents = [mLines componentsJoinedByString:@"\n"];
                
                NSData *outputData = [strContents dataUsingEncoding:NSUTF8StringEncoding];
                
                BOOL targetIsDirectory = NO;
                BOOL targetExists = [_sharedFileManager fileExistsAtPath:path isDirectory:&targetIsDirectory];
                if (targetExists && !targetIsDirectory) {
                    BOOL removed = [_sharedFileManager removeItemAtPath:path error:nil];
                    if (!removed)
                        return;
                }
                
                succeed = [_sharedFileManager createFileAtPath:path contents:outputData attributes:nil];
            }
        });
        
        lua_pushboolean(L, succeed);
        if (succeed) {
            lua_pushstring(L, removedLine.UTF8String);
        } else {
            lua_pushnil(L);
        }
        return 2;
    }
}

static int l_file_get_lines(lua_State *L)
{
    @autoreleasepool {
        const char *cPath = luaL_checkstring(L, 1);
        NSString *path = [NSString stringWithUTF8String:cPath];
        
        __block NSArray <NSString *> *strLines = nil;
        dispatch_sync(_sharedQueue, ^{
            
            @autoreleasepool {
                NSData *contents = [_sharedFileManager contentsAtPath:path];
                if (!contents)
                    return;
                
                NSString *strContents = [[NSString alloc] initWithData:contents encoding:NSUTF8StringEncoding];
                if (!strContents)
                    return;
                
                strLines = [strContents componentsSeparatedByString:@"\n"];
            }
        });
        
        if (!strLines) {
            lua_pushnil(L);
        } else {
            lua_pushNSArray(L, strLines);
        }
        return 1;
    }
}

static int l_file_insert_lines(lua_State *L)
{
    @autoreleasepool {
        const char *cPath = luaL_checkstring(L, 1);
        NSString *path = [NSString stringWithUTF8String:cPath];
        
        lua_Integer cLineIndex = luaL_checkinteger(L, 2);
        
        BOOL reversed = cLineIndex <= 0;
        if (reversed) {
            cLineIndex = -cLineIndex;
        }
        
        NSArray <NSString *> *linesToInsert = lua_toNSArray(L, 3);
        
        __block BOOL succeed = NO;
        dispatch_sync(_sharedQueue, ^{
            
            @autoreleasepool {
                NSData *contents = [_sharedFileManager contentsAtPath:path];
                if (!contents)
                    return;
                
                NSString *strContents = [[NSString alloc] initWithData:contents encoding:NSUTF8StringEncoding];
                if (!strContents)
                    return;
                
                NSArray <NSString *> *strLines = [strContents componentsSeparatedByString:@"\n"];
                if (cLineIndex > strLines.count)
                    return;
                
                NSMutableArray <NSString *> *mLines = [strLines mutableCopy];
                NSUInteger indexToInsert = reversed ? mLines.count - cLineIndex : cLineIndex - 1;
                NSIndexSet *indexesToInsert = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(indexToInsert, linesToInsert.count)];
                [mLines insertObjects:linesToInsert atIndexes:indexesToInsert];
                strContents = [mLines componentsJoinedByString:@"\n"];
                
                NSData *outputData = [strContents dataUsingEncoding:NSUTF8StringEncoding];
                
                BOOL targetIsDirectory = NO;
                BOOL targetExists = [_sharedFileManager fileExistsAtPath:path isDirectory:&targetIsDirectory];
                if (targetExists && !targetIsDirectory) {
                    BOOL removed = [_sharedFileManager removeItemAtPath:path error:nil];
                    if (!removed)
                        return;
                }
                
                succeed = [_sharedFileManager createFileAtPath:path contents:outputData attributes:nil];
            }
        });
        
        lua_pushboolean(L, succeed);
        return 1;
    }
}

static int l_file_set_lines(lua_State *L)
{
    @autoreleasepool {
        const char *cPath = luaL_checkstring(L, 1);
        NSString *path = [NSString stringWithUTF8String:cPath];
        
        NSArray <NSString *> *linesToInsert = lua_toNSArray(L, 2);
        
        __block BOOL succeed = NO;
        dispatch_sync(_sharedQueue, ^{
            
            @autoreleasepool {
                NSString *strContents = [linesToInsert componentsJoinedByString:@"\n"];
                
                NSData *outputData = [strContents dataUsingEncoding:NSUTF8StringEncoding];
                
                BOOL targetIsDirectory = NO;
                BOOL targetExists = [_sharedFileManager fileExistsAtPath:path isDirectory:&targetIsDirectory];
                if (targetExists && !targetIsDirectory) {
                    BOOL removed = [_sharedFileManager removeItemAtPath:path error:nil];
                    if (!removed)
                        return;
                }
                
                succeed = [_sharedFileManager createFileAtPath:path contents:outputData attributes:nil];
            }
        });
        
        lua_pushboolean(L, succeed);
        return 1;
    }
}

static int l_file_md5(lua_State *L)
{
    @autoreleasepool {
        const char *cPath = luaL_checkstring(L, 1);
        NSString *path = [NSString stringWithUTF8String:cPath];
        
        NSString *md5Hex = [LUAE_FileHash md5HashOfFileAtPath:path];
        if (!md5Hex) {
            lua_pushnil(L);
            return 1;
        }
        
        lua_pushstring(L, [md5Hex UTF8String]);
        return 1;
    }
}

static int l_file_sha1(lua_State *L)
{
    @autoreleasepool {
        const char *cPath = luaL_checkstring(L, 1);
        NSString *path = [NSString stringWithUTF8String:cPath];
        
        NSString *sha1Hex = [LUAE_FileHash sha1HashOfFileAtPath:path];
        if (!sha1Hex) {
            lua_pushnil(L);
            return 1;
        }
        
        lua_pushstring(L, [sha1Hex UTF8String]);
        return 1;
    }
}

static int l_file_sha256(lua_State *L)
{
    @autoreleasepool {
        const char *cPath = luaL_checkstring(L, 1);
        NSString *path = [NSString stringWithUTF8String:cPath];
        
        NSString *sha1Hex = [LUAE_FileHash sha256HashOfFileAtPath:path];
        if (!sha1Hex) {
            lua_pushnil(L);
            return 1;
        }
        
        lua_pushstring(L, [sha1Hex UTF8String]);
        return 1;
    }
}

static int l_file_sha512(lua_State *L)
{
    @autoreleasepool {
        const char *cPath = luaL_checkstring(L, 1);
        NSString *path = [NSString stringWithUTF8String:cPath];
        
        NSString *sha1Hex = [LUAE_FileHash sha512HashOfFileAtPath:path];
        if (!sha1Hex) {
            lua_pushnil(L);
            return 1;
        }
        
        lua_pushstring(L, [sha1Hex UTF8String]);
        return 1;
    }
}

static const luaL_Reg reg_file_auxlib[] = {
    
    /* Basic */
    {"exists", l_file_exists},
    {"list", l_file_list},
    {"size", l_file_size},
    {"reads", l_file_reads},
    {"writes", l_file_writes},
    {"appends", l_file_appends},
    
    /* Line Operations */
    {"line_count", l_file_line_count},
    {"get_line", l_file_get_line},
    {"set_line", l_file_set_line},
    {"insert_line", l_file_insert_line},
    {"remove_line", l_file_remove_line},
    
    /* Lines Operations */
    {"get_lines", l_file_get_lines},
    {"insert_lines", l_file_insert_lines},
    {"set_lines", l_file_set_lines},
    
    /* Crypto */
    {"md5", l_file_md5},
    {"sha1", l_file_sha1},
    {"sha256", l_file_sha256},
    {"sha512", l_file_sha512},
    
    {NULL, NULL},
};

OBJC_EXTERN int luaopen_file(lua_State *);
OBJC_EXTERN int luaopen_file(lua_State *L)
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedFileManager = [[NSFileManager alloc] init];
        _sharedQueue = dispatch_queue_create("ch.xxtou.queue.file.lua", DISPATCH_QUEUE_SERIAL);
    });
    
    int nrec = (sizeof(reg_file_auxlib) / sizeof((reg_file_auxlib)[0]) - 1);
    lua_createtable(L, 0, nrec + 1);
    lua_pushliteral(L, "0.3");
    lua_setfield(L, -2, "_VERSION");
    luaL_setfuncs(L, reg_file_auxlib, 0);
    return 1;
}

OBJC_EXTERN int luaopen_exfile(lua_State *);
OBJC_EXTERN int luaopen_exfile(lua_State *L)
{
    return luaopen_file(L);
}
