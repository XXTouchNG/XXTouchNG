#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import <UIKit/UIKit.h>
#import "luae.h"

static int l_pasteboard_write(lua_State *L)
{
    @autoreleasepool {
        size_t cLen;
        const char *cData = luaL_checklstring(L, 1, &cLen);
        const char *cUTI = luaL_optstring(L, 2, "public.utf8-plain-text");
        
        NSData *data = [NSData dataWithBytesNoCopy:(void *)cData length:cLen freeWhenDone:NO];
        [[UIPasteboard generalPasteboard] setData:data forPasteboardType:[NSString stringWithUTF8String:cUTI]];
        return 0;
    }
}

static int l_pasteboard_read(lua_State *L)
{
    @autoreleasepool {
        const char *cUTI = luaL_optstring(L, 1, "public.utf8-plain-text");
        NSData *data = [[UIPasteboard generalPasteboard] dataForPasteboardType:[NSString stringWithUTF8String:cUTI]];
        lua_pushlstring(L, (const char *)data.bytes, data.length);
        return 1;
    }
}

OBJC_EXTERN int luaopen_pasteboard(lua_State *);
OBJC_EXTERN int luaopen_pasteboard(lua_State *L)
{
    lua_createtable(L, 0, 3);
    lua_pushcfunction(L, l_pasteboard_read);
    lua_setfield(L, -2, "read");
    lua_pushcfunction(L, l_pasteboard_write);
    lua_setfield(L, -2, "write");
    lua_pushliteral(L, "0.3");
    lua_setfield(L, -2, "_VERSION");
    return 1;
}
