#include <archive_entry.h>
#include <ctype.h>
#include <lauxlib.h>
#include <lua.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <sys/stat.h>

#include "ar.h"
#include "ar_entry.h"

#define err(...) (luaL_error(L, __VA_ARGS__))

static int __ref_count = 0;

//////////////////////////////////////////////////////////////////////
// For debugging GC issues.
static int ar_ref_count(lua_State *L) {
    lua_pushnumber(L, __ref_count);
    return 1;
}

//////////////////////////////////////////////////////////////////////
int ar_entry(lua_State *L) {
    struct archive_entry** self_ref = (struct archive_entry**)
        lua_newuserdata(L, sizeof(struct archive_entry*)); // ..., {ud}
    *self_ref = NULL;
    luaL_getmetatable(L, AR_ENTRY); // ..., {ud}, {meta}
    lua_setmetatable(L, -2); // ..., {ud}
    __ref_count++;
    *self_ref = archive_entry_new();

    if ( lua_istable(L, 1) ) {
        // If given a sourcepath, copy stat buffer from there:
        lua_pushliteral(L, "sourcepath"); // ..., {ud}, "sourcepath"
        lua_rawget(L, 1); // ..., {ud}, src
        if ( lua_isstring(L, -1) ) {
            struct stat sb;
#ifdef _MSC_VER
            stat(lua_tostring(L, -1), &sb);
#else
            lstat(lua_tostring(L, -1), &sb);
#endif
            archive_entry_copy_stat(*self_ref, &sb);
        } else {
            // Give a reasonable default mode:
            archive_entry_set_mode(*self_ref, S_IFREG);
        }
        lua_pop(L, 1); // ... {ud}
        assert(0 != lua_getmetatable(L, -1)); // ..., {ud}, {meta}

        // Iterate over the table and call the method with that name
        lua_pushnil(L); // ..., {ud}, {meta}, nil
        while (lua_next(L, 1) != 0) { // ..., {ud}, {meta}, key, value
            lua_pushvalue(L, -2); // ..., {ud}, {meta}, key, value, key
            lua_gettable(L, -4); // ..., {ud}, {meta}, key, value, func
            if ( lua_isnil(L, -1) ) {
                err("InvalidArgument: '%s' is not a valid field", lua_tostring(L, -3));
            }
            lua_pushvalue(L, -5); // ..., {ud}, {meta}, key, value, func, {ud}
            lua_pushvalue(L, -3); // ..., {ud}, {meta}, key, value, func, {ud}, value
            lua_call(L, 2, 0); // ..., {ud}, {meta}, key, value
            lua_pop(L, 1);     // ..., {ud}, {meta}, key
        } // ..., {ud}, {meta}
        lua_pop(L, 1);
    }
    return 1;
}

//////////////////////////////////////////////////////////////////////
static int ar_entry_destroy(lua_State *L) {
    struct archive_entry** self_ref = ar_entry_check(L, 1);
    if ( *self_ref != NULL ) {
        __ref_count--;
        archive_entry_free(*self_ref);
        *self_ref = NULL;
    }
    return 0;
}

//////////////////////////////////////////////////////////////////////
static int ar_entry_fflags(lua_State *L) {
    struct archive_entry* self = *ar_entry_check(L, 1);
    int is_set;
    if ( NULL == self ) return 0;

    is_set = ( lua_gettop(L) == 2 );
    lua_pushstring(L, archive_entry_fflags_text(self));
    if ( is_set ) {
        const char* invalid = archive_entry_copy_fflags_text(self, lua_tostring(L, 2));
        if ( NULL != invalid ) {
            err("InvalidFFlag: '%s' is not a known fflag", invalid);
        }
    }
    return 1;
}

//////////////////////////////////////////////////////////////////////
static int ar_entry_dev(lua_State *L) {
    struct archive_entry* self = *ar_entry_check(L, 1);
    int is_set;
    if ( NULL == self ) return 0;

    is_set = ( lua_gettop(L) == 2 );
    lua_pushnumber(L, archive_entry_dev(self));
    if ( is_set ) {
        archive_entry_set_dev(self, lua_tonumber(L, 2));
    }
    return 1;
}

//////////////////////////////////////////////////////////////////////
static int ar_entry_ino(lua_State *L) {
    struct archive_entry* self = *ar_entry_check(L, 1);
    int is_set;
    if ( NULL == self ) return 0;

    is_set = ( lua_gettop(L) == 2 );
    lua_pushnumber(L, archive_entry_ino(self));
    if ( is_set ) {
        archive_entry_set_ino(self, lua_tonumber(L, 2));
    }
    return 1;
}

//////////////////////////////////////////////////////////////////////
static int ar_entry_mode(lua_State *L) {
    struct archive_entry* self = *ar_entry_check(L, 1);
    int is_set;
    if ( NULL == self ) return 0;

    is_set = ( lua_gettop(L) == 2 );
    lua_pushnumber(L, archive_entry_mode(self));
    if ( is_set ) {
        __LA_MODE_T mode = lua_tonumber(L, 2);
        archive_entry_set_mode(self, mode);
    }
    return 1;
}

//////////////////////////////////////////////////////////////////////
static int ar_entry_nlink(lua_State *L) {
    struct archive_entry* self = *ar_entry_check(L, 1);
    int is_set;
    if ( NULL == self ) return 0;

    is_set = ( lua_gettop(L) == 2 );
    lua_pushnumber(L, archive_entry_nlink(self));
    if ( is_set ) {
        archive_entry_set_nlink(self, lua_tonumber(L, 2));
    }
    return 1;
}

//////////////////////////////////////////////////////////////////////
static int ar_entry_uid(lua_State *L) {
    struct archive_entry* self = *ar_entry_check(L, 1);
    int is_set;
    if ( NULL == self ) return 0;

    is_set = ( lua_gettop(L) == 2 );
    lua_pushnumber(L, archive_entry_uid(self));
    if ( is_set ) {
        archive_entry_set_uid(self, lua_tonumber(L, 2));
    }
    return 1;
}

//////////////////////////////////////////////////////////////////////
static int ar_entry_uname(lua_State *L) {
    struct archive_entry* self = *ar_entry_check(L, 1);
    int is_set;
    if ( NULL == self ) return 0;

    is_set = ( lua_gettop(L) == 2 );
    lua_pushstring(L, archive_entry_uname(self));
    if ( is_set ) {
        archive_entry_copy_uname(self, lua_tostring(L, 2));
    }
    return 1;
}

//////////////////////////////////////////////////////////////////////
static int ar_entry_gid(lua_State *L) {
    struct archive_entry* self = *ar_entry_check(L, 1);
    int is_set;
    if ( NULL == self ) return 0;

    is_set = ( lua_gettop(L) == 2 );
    lua_pushnumber(L, archive_entry_gid(self));
    if ( is_set ) {
        archive_entry_set_gid(self, lua_tonumber(L, 2));
    }
    return 1;
}

//////////////////////////////////////////////////////////////////////
static int ar_entry_gname(lua_State *L) {
    struct archive_entry* self = *ar_entry_check(L, 1);
    int is_set;
    if ( NULL == self ) return 0;

    is_set = ( lua_gettop(L) == 2 );
    lua_pushstring(L, archive_entry_gname(self));
    if ( is_set ) {
        archive_entry_copy_gname(self, lua_tostring(L, 2));
    }
    return 1;
}

//////////////////////////////////////////////////////////////////////
static int ar_entry_rdev(lua_State *L) {
    struct archive_entry* self = *ar_entry_check(L, 1);
    int is_set;
    if ( NULL == self ) return 0;

    is_set = ( lua_gettop(L) == 2 );
    lua_pushnumber(L, archive_entry_rdev(self));
    if ( is_set ) {
        archive_entry_set_rdev(self, lua_tonumber(L, 2));
    }
    return 1;
}

//////////////////////////////////////////////////////////////////////
static int ar_entry_atime(lua_State *L) {
    struct archive_entry* self = *ar_entry_check(L, 1);
    int is_set;
    int num_results;
    if ( NULL == self ) return 0;

    is_set = ( lua_gettop(L) >= 2 );
    num_results = 0;
    if ( archive_entry_atime_is_set(self) ) {
        num_results = 2;
        lua_pushnumber(L, archive_entry_atime(self));
        lua_pushnumber(L, archive_entry_atime_nsec(self));
    }
    if ( is_set ) {
        if ( lua_isnil(L, 2) ) {
            archive_entry_unset_atime(self);
        } else if ( lua_istable(L, 2) ) {
            lua_rawgeti(L, 2, 1);
            lua_rawgeti(L, 2, 2);
            archive_entry_set_atime(self,
                                    lua_tonumber(L, -2),
                                    lua_tonumber(L, -1));
        } else {
            archive_entry_set_atime(self,
                                    lua_tonumber(L, 2),
                                    lua_tonumber(L, 3));
        }
    }
    return num_results;
}

//////////////////////////////////////////////////////////////////////
static int ar_entry_mtime(lua_State *L) {
    struct archive_entry* self = *ar_entry_check(L, 1);
    int is_set;
    int num_results;
    if ( NULL == self ) return 0;

    is_set = ( lua_gettop(L) >= 2 );
    num_results = 0;
    if ( archive_entry_mtime_is_set(self) ) {
        num_results = 2;
        lua_pushnumber(L, archive_entry_mtime(self));
        lua_pushnumber(L, archive_entry_mtime_nsec(self));
    }
    if ( is_set ) {
        if ( lua_isnil(L, 2) ) {
            archive_entry_unset_mtime(self);
        } else if ( lua_istable(L, 2) ) {
            lua_rawgeti(L, 2, 1);
            lua_rawgeti(L, 2, 2);
            archive_entry_set_mtime(self,
                                    lua_tonumber(L, -2),
                                    lua_tonumber(L, -1));
        } else {
            archive_entry_set_mtime(self,
                                    lua_tonumber(L, 2),
                                    lua_tonumber(L, 3));
        }
    }
    return num_results;
}

//////////////////////////////////////////////////////////////////////
static int ar_entry_ctime(lua_State *L) {
    struct archive_entry* self = *ar_entry_check(L, 1);
    int is_set;
    int num_results;
    if ( NULL == self ) return 0;

    is_set = ( lua_gettop(L) >= 2 );
    num_results = 0;
    if ( archive_entry_ctime_is_set(self) ) {
        num_results = 2;
        lua_pushnumber(L, archive_entry_ctime(self));
        lua_pushnumber(L, archive_entry_ctime_nsec(self));
    }
    if ( is_set ) {
        if ( lua_isnil(L, 2) ) {
            archive_entry_unset_ctime(self);
        } else if ( lua_istable(L, 2) ) {
            lua_rawgeti(L, 2, 1);
            lua_rawgeti(L, 2, 2);
            archive_entry_set_ctime(self,
                                    lua_tonumber(L, -2),
                                    lua_tonumber(L, -1));
        } else {
            archive_entry_set_ctime(self,
                                    lua_tonumber(L, 2),
                                    lua_tonumber(L, 3));
        }
    }
    return num_results;
}

//////////////////////////////////////////////////////////////////////
static int ar_entry_birthtime(lua_State *L) {
    struct archive_entry* self = *ar_entry_check(L, 1);
    int is_set;
    int num_results;
    if ( NULL == self ) return 0;

    is_set = ( lua_gettop(L) >= 2 );
    num_results = 0;
    if ( archive_entry_birthtime_is_set(self) ) {
        num_results = 2;
        lua_pushnumber(L, archive_entry_birthtime(self));
        lua_pushnumber(L, archive_entry_birthtime_nsec(self));
    }
    if ( is_set ) {
        if ( lua_isnil(L, 2) ) {
            archive_entry_unset_birthtime(self);
        } else if ( lua_istable(L, 2) ) {
            lua_rawgeti(L, 2, 1);
            lua_rawgeti(L, 2, 2);
            archive_entry_set_birthtime(self,
                                    lua_tonumber(L, -2),
                                    lua_tonumber(L, -1));
        } else {
            archive_entry_set_birthtime(self,
                                    lua_tonumber(L, 2),
                                    lua_tonumber(L, 3));
        }
    }
    return num_results;
}

//////////////////////////////////////////////////////////////////////
static int ar_entry_size(lua_State *L) {
    struct archive_entry* self = *ar_entry_check(L, 1);
    int is_set;
    if ( NULL == self ) return 0;

    is_set = ( lua_gettop(L) == 2 );
    if ( archive_entry_size_is_set(self) ) {
        lua_pushnumber(L, archive_entry_size(self));
    } else {
        lua_pushnil(L);
    }
    if ( is_set ) {
        if ( lua_isnil(L, 2) ) {
            archive_entry_unset_size(self);
        } else {
            archive_entry_set_size(self, lua_tonumber(L, 2));
        }
    }
    return 1;
}

//////////////////////////////////////////////////////////////////////
static int ar_entry_sourcepath(lua_State *L) {
    struct archive_entry* self = *ar_entry_check(L, 1);
    int is_set;
    if ( NULL == self ) return 0;

    is_set = ( lua_gettop(L) == 2 );
    lua_pushstring(L, archive_entry_sourcepath(self));
    if ( is_set ) {
        archive_entry_copy_sourcepath(self, lua_tostring(L, 2));
    }
    return 1;
}

//////////////////////////////////////////////////////////////////////
static int ar_entry_symlink(lua_State *L) {
    struct archive_entry* self = *ar_entry_check(L, 1);
    int is_set;
    if ( NULL == self ) return 0;

    is_set = ( lua_gettop(L) == 2 );
    lua_pushstring(L, archive_entry_symlink(self));
    if ( is_set ) {
        archive_entry_copy_symlink(self, lua_tostring(L, 2));
    }
    return 1;
}

//////////////////////////////////////////////////////////////////////
static int ar_entry_hardlink(lua_State *L) {
    struct archive_entry* self = *ar_entry_check(L, 1);
    int is_set;
    if ( NULL == self ) return 0;

    is_set = ( lua_gettop(L) == 2 );
    lua_pushstring(L, archive_entry_hardlink(self));
    if ( is_set ) {
        archive_entry_copy_hardlink(self, lua_tostring(L, 2));
    }
    return 1;
}

//////////////////////////////////////////////////////////////////////
static int ar_entry_pathname(lua_State *L) {
    struct archive_entry* self = *ar_entry_check(L, 1);
    int is_set;
    if ( NULL == self ) return 0;

    is_set = ( lua_gettop(L) == 2 );
    lua_pushstring(L, archive_entry_pathname(self));
    if ( is_set ) {
        archive_entry_copy_pathname(self, lua_tostring(L, 2));
    }
    return 1;
}

//////////////////////////////////////////////////////////////////////
int ar_entry_init(lua_State *L) {
    static luaL_Reg fns[] = {
        { "entry",  ar_entry },
        { "_entry_ref_count", ar_ref_count },
        { NULL, NULL }
    };
    // So far there are no methods on the entry objects.
    static luaL_Reg m_fns[] = {
        { "fflags", ar_entry_fflags },
        { "dev", ar_entry_dev },
        { "ino", ar_entry_ino },
        { "mode", ar_entry_mode },
        { "nlink", ar_entry_nlink },
        { "uid", ar_entry_uid },
        { "uname", ar_entry_uname },
        { "gid", ar_entry_gid },
        { "gname", ar_entry_gname },
        { "rdev", ar_entry_rdev },
        { "atime", ar_entry_atime },
        { "mtime", ar_entry_mtime },
        { "ctime", ar_entry_ctime },
        { "birthtime", ar_entry_birthtime },
        { "size", ar_entry_size },
        { "sourcepath", ar_entry_sourcepath },
        { "symlink", ar_entry_symlink },
        { "hardlink", ar_entry_hardlink },
        { "pathname", ar_entry_pathname },
        { "__gc",    ar_entry_destroy },
        { NULL, NULL }
    };

    luaL_checktype(L, LUA_TTABLE, -1); // {class}

    luaL_register(L, NULL, fns); // {class}

    luaL_newmetatable(L, AR_ENTRY); // {class}, {meta}

    lua_pushvalue(L, -1); // {class}, {meta}, {meta}
    lua_setfield(L, -2, "__index"); // {class}, {meta}

    luaL_register(L, NULL, m_fns); // {1}

    lua_pop(L, 1);
    return 0;
}
