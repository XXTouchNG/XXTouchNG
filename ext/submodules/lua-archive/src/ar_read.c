//////////////////////////////////////////////////////////////////////
// Implement the archive{read} object.
//////////////////////////////////////////////////////////////////////

#include <archive.h>
#include <archive_entry.h>
#include <ctype.h>
#include <lauxlib.h>
#include <lua.h>
#include <stdlib.h>
#include <string.h>

#include "ar.h"
#include "ar_read.h"
#include "ar_entry.h"
#include "ar_registry.h"

#define err(...) (luaL_error(L, __VA_ARGS__))
#define rel_idx(relative, idx) ((idx) < 0 ? (idx) + (relative) : (idx))

static __LA_SSIZE_T ar_read_cb(struct archive * ar,
                               void *opaque,
                               const void **buff);

static int __ref_count = 0;

typedef struct {
    const char *name;
    int (*setter)(struct archive *);
} named_setter; 

//////////////////////////////////////////////////////////////////////
// For debugging GC issues.
static int ar_ref_count(lua_State *L) {
    lua_pushnumber(L, __ref_count);
    return 1;
}

//////////////////////////////////////////////////////////////////////
// 
static int call_setters(lua_State *L,
                        struct archive* self,
                        char* func_prefix,
                        named_setter names[],
                        const char* names_str)
{
    int setters_called = 0;
    const char* name=names_str;
    size_t name_len=0;
    for ( ; '\0' != *name; name += name_len ) {
        int idx = 0;
        while ( '\0' != *name && ! isalnum(*name) ) name++;
        while ( isalnum(*(name+name_len)) ) name_len++;
        if ( ! *name ) continue;
        for ( ;; idx++ ) {
            if ( names[idx].name == NULL ) {
                lua_pushlstring(L, name, name_len);
                err("%s*: No such format '%s'", func_prefix, lua_tostring(L, -1));
            }
            if ( strncmp(name, names[idx].name, name_len) == 0 ) break;
        }
        setters_called++;
        if ( ARCHIVE_OK != (names[idx].setter)(self) ) {
            lua_pushlstring(L, name, name_len);
            err("%s%s: %s", func_prefix, lua_tostring(L, -1), archive_error_string(self));
        }
    }
    return setters_called;
}

//////////////////////////////////////////////////////////////////////
// Constructor:
static int ar_read(lua_State *L) {
    struct archive** self_ref;
    static named_setter format_names[] = {
        /* Copied from archive.h */
        { "all",       archive_read_support_format_all },
        { "ar",        archive_read_support_format_ar },
        { "cpio",      archive_read_support_format_cpio },
        { "empty",     archive_read_support_format_empty },
        { "gnutar",    archive_read_support_format_gnutar },
        { "iso9660",   archive_read_support_format_iso9660 },
        { "mtree",     archive_read_support_format_mtree },
        { "tar",       archive_read_support_format_tar },
        { "zip",       archive_read_support_format_zip },
        { NULL,        NULL }
    };
    static named_setter compression_names[] = {
        { "all",      archive_read_support_filter_all },
        { "bzip2",    archive_read_support_filter_bzip2 },
        { "compress", archive_read_support_filter_compress },
        { "gzip",     archive_read_support_filter_gzip },
        { "lzma",     archive_read_support_filter_lzma },
        { "none",     archive_read_support_filter_none },
        { "xz",       archive_read_support_filter_xz },
        { NULL,       NULL }
    };

    luaL_checktype(L, 1, LUA_TTABLE);

    self_ref = (struct archive**)
        lua_newuserdata(L, sizeof(struct archive*)); // {ud}
    *self_ref = NULL;
    luaL_getmetatable(L, AR_READ); // {ud}, [read]
    lua_setmetatable(L, -2); // {ud}
    __ref_count++;
    *self_ref = archive_read_new();

    // Register it in the weak metatable:
    ar_registry_set(L, *self_ref);

    // Create an environment to store a reference to the callbacks:
    lua_createtable(L, 1, 0); // {ud}, {fenv}
    lua_getfield(L, 1, "reader"); // {ud}, {fenv}, fn
    if ( ! lua_isfunction(L, -1) ) err("MissingArgument: required parameter 'reader' must be a function");
    lua_setfield(L, -2, "reader"); // {ud}, {fenv}
    lua_setuservalue(L, -2); // {ud}

    // Do it the easy way for now... perhaps in the future we will
    // have a parameter to support toggling which algorithms are
    // supported:
    if ( ARCHIVE_OK != archive_read_support_filter_all(*self_ref) ) {
        err("archive_read_support_compression_all: %s", archive_error_string(*self_ref));
    }
    if ( ARCHIVE_OK != archive_read_support_format_all(*self_ref) ) {
        err("archive_read_support_format_all: %s", archive_error_string(*self_ref));
    }


    // Extract various fields and prepare the archive:
    lua_getfield(L, 1, "format");
    if ( NULL == lua_tostring(L, -1) ) {
        lua_pop(L, 1);
        lua_pushliteral(L, "all");
    }
    if ( 0 == call_setters(L,
                           *self_ref,
                           "archive_read_support_format_",
                           format_names,
                           lua_tostring(L, -1)) )
    {
        // We will be strict for now... perhaps in the future we will
        // default to "all"?
        err("empty format='%s' is not allowed, you must specify at least one format",
            lua_tostring(L, -1));
    }
    lua_pop(L, 1);

    lua_getfield(L, 1, "compression");
    if ( NULL == lua_tostring(L, -1) ) {
        lua_pop(L, 1);
        lua_pushliteral(L, "none");
    }
    call_setters(L, 
                 *self_ref,
                 "archive_read_support_compression_",
                 compression_names,
                 lua_tostring(L, -1));
    lua_pop(L, 1);

    lua_getfield(L, 1, "options");
    if ( ! lua_isnil(L, -1) &&
         ARCHIVE_OK != archive_read_set_options(*self_ref, lua_tostring(L, -1)) )
    {
        err("archive_read_set_options: %s",  archive_error_string(*self_ref));
    }
    lua_pop(L, 1);


    if ( ARCHIVE_OK != archive_read_open(*self_ref, L, NULL, &ar_read_cb, NULL) ) {
        err("archive_read_open: %s", archive_error_string(*self_ref));
    }

    return 1;
}

//////////////////////////////////////////////////////////////////////
// Precondition: archive{read} is at the top of the stack, and idx is
// the index to the argument for which to pass to reader exists.  If
// idx is zero, nil is passed into reader.
static void ar_read_get_reader(lua_State *L, int self_idx) {
    lua_getuservalue(L, self_idx);        // {env}
    lua_pushliteral(L, "reader");    // {env}, "reader"
    lua_rawget(L, -2);               // {env}, reader
    lua_insert(L, -2);              // reader, {env}
    lua_pop(L, 1);                  // reader
}

//////////////////////////////////////////////////////////////////////
static int ar_read_destroy(lua_State *L) {
    struct archive** self_ref = ar_read_check(L, 1);
    if ( NULL == *self_ref ) return 0;

    // If called in destructor, we were already removed from the weak
    // table, so we need to re-register so that the read callback
    // will work.
    ar_registry_set(L, *self_ref);

    if ( ARCHIVE_OK != archive_read_close(*self_ref) ) {
        lua_pushfstring(L, "archive_read_close: %s", archive_error_string(*self_ref));
        archive_read_free(*self_ref);
        __ref_count--;
        *self_ref = NULL;
        lua_error(L);
    }

    ar_read_get_reader(L, 1); // {self}, reader
    if ( ! lua_isnil(L, -1) ) {
        lua_pushvalue(L, 1); // {self}, reader, {self}
        lua_pushnil(L); // {self}, reader, {self}, nil
        lua_call(L, 2, 1); // {self}, result
    }

    if ( ARCHIVE_OK != archive_read_free(*self_ref) ) {
        luaL_error(L, "archive_read_free: %s", archive_error_string(*self_ref));
    }
    __ref_count--;
    *self_ref = NULL;

    return 0;
}

//////////////////////////////////////////////////////////////////////
static __LA_SSIZE_T ar_read_cb(struct archive * self,
                               void *opaque,
                               const void **result)
{
    lua_State* L = (lua_State*)opaque;
    size_t result_len;
    *result = NULL;

    // We are missing!?
    if ( ! ar_registry_get(L, self) ) {
        archive_set_error(self, 0,
                          "InternalError: read callback called on archive that should already have been garbage collected!");
        return -1;
    }

    ar_read_get_reader(L, -1); // {ud}, reader
    lua_pushvalue(L, -2); // {ud}, reader, {ud}

    if ( 0 != lua_pcall(L, 1, 1, 0) ) { // {ud}, "err"
        archive_set_error(self, 0, "%s", lua_tostring(L, -1));
        lua_pop(L, 2); // <nothing>
        return -1;
    }

    *result = lua_tolstring(L, -1, &result_len); // {ud}, result

    // We directly return the raw internal buffer, so we need to keep
    // a reference around:
    lua_getuservalue(L, -2); // {ud}, result, {fenv}
    lua_insert(L, -2); // {ud}, {fenv}, result
    lua_pushliteral(L, "read_buffer"); // {ud}, {fenv}, result, "read_buffer"
    lua_insert(L, -2); // {ud}, {fenv}, "read_buffer", result
    lua_rawset(L, -3); // {ud}, {fenv}
    lua_pop(L, 2); // <nothing>

    return result_len;
}

//////////////////////////////////////////////////////////////////////
static int ar_read_next_header(lua_State *L) {
    struct archive_entry* entry;
    struct archive* self = *ar_read_check(L, 1); // {ud}
    int result;
    if ( NULL == self ) err("NULL archive{read}!");

    lua_pushcfunction(L, ar_entry); // {ud}, ar_entry
    lua_call(L, 0, 1); // {ud}, header

    entry = *ar_entry_check(L, -1);
    result = archive_read_next_header2(self, entry);
    if ( ARCHIVE_EOF == result ) {
        lua_pop(L, 1); // {ud}
        lua_pushnil(L); // {ud}, nil
    } else if ( ARCHIVE_OK != result ) {
        err("archive_read_next_header2: %s", archive_error_string(self));
    }
    return 1;
}

//////////////////////////////////////////////////////////////////////
static int ar_read_headers(lua_State *L) {
    ar_read_check(L, 1); // {ud}
    lua_pushcfunction(L, ar_read_next_header);
    lua_pushvalue(L, 1);
    lua_pushnil(L);
    return 3;
}

//////////////////////////////////////////////////////////////////////
static int ar_read_data(lua_State *L) {
    struct archive* self = *ar_read_check(L, 1);
    const void* buff;
    size_t buff_len;
    off_t offset;
    int result;

    if ( NULL == self ) err("NULL archive{read}!");

    result = archive_read_data_block(self, &buff, &buff_len, &offset);
    if ( ARCHIVE_EOF == result ) {
        return 0;
    } else if ( ARCHIVE_OK != result ) {
        err("archive_read_data_block: %s", archive_error_string(self));
    }
    lua_pushlstring(L, buff, buff_len);
    lua_pushnumber(L, offset);
    return 2;
}

//////////////////////////////////////////////////////////////////////
// Precondition: top of the stack contains a table for which we will
// append our "static" methods.
//
// Postcondition: 'read' method is registered in the table at the top
// of the stack, and the archive{read} metatable is registered.
//////////////////////////////////////////////////////////////////////
int ar_read_init(lua_State *L) {
    static luaL_Reg fns[] = {
        { "read",  ar_read },
        { "_read_ref_count", ar_ref_count },
        { NULL, NULL }
    };
    static luaL_Reg m_fns[] = {
        { "next_header",  ar_read_next_header },
        { "headers",      ar_read_headers },
        { "data",         ar_read_data },
        { "close",        ar_read_destroy },
        { "__gc",         ar_read_destroy },
        { NULL, NULL }
    };

    luaL_checktype(L, LUA_TTABLE, -1); // {class}

    luaL_register(L, NULL, fns); // {class}

    luaL_newmetatable(L, AR_READ); // {class}, {meta}

    lua_pushvalue(L, -1); // {class}, {meta}, {meta}
    lua_setfield(L, -2, "__index"); // {class}, {meta}

    luaL_register(L, NULL, m_fns); // {class}, {meta}

    lua_pop(L, 1); // {class}

    return 0;
}
