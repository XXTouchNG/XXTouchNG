#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import "luae.h"
#import <mach/mach.h>
#import "TFCookiesManager.h"


#pragma mark -

_ELIB_DECL(cookies);


#pragma mark -

#define luaE_optboolean(L, IDX, DEF) \
(BOOL)(lua_isboolean((L), (IDX)) ? lua_toboolean(L, (IDX)) : (DEF))


#pragma mark -




#pragma mark -

_ELIB(cookies) = {
    {NULL, NULL}
};


#pragma mark -

_ELIB_API(cookies);
_ELIB_API(cookies) {
    luaE_newelib(L, LUAE_LIB_FUNCS_cookies);
    return 1;
}
