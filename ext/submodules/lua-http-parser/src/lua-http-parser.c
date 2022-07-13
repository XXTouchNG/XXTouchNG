#include <assert.h>
#include <lauxlib.h>
#include <lua.h>
#include "http_parser.h"

#if LUA_VERSION_NUM >= 502
#define lua_setfenv         lua_setuservalue
#define lua_getfenv         lua_getuservalue
#endif

#define PARSER_MT "http.parser{parser}"

#define check_parser(L, narg)                                   \
    ((lhttp_parser*)luaL_checkudata((L), (narg), PARSER_MT))

/* The Lua stack indices */
#define ST_FENV_IDX   3
#define ST_BUFFER_IDX 4
#define ST_LEN        ST_BUFFER_IDX

/* Callback identifiers are indices into the fenv table where the
 * callback is saved.  If you add/remove/change anything about these,
 * be sure to update lhp_callback_names and FLAG_GET_BUF_CB_ID.
 */
#define CB_ON_MESSAGE_BEGIN      1
#define CB_ON_URL                2
#define CB_ON_STATUS             3
#define CB_ON_HEADER             4
#define CB_ON_HEADERS_COMPLETE   5
#define CB_ON_BODY               6
#define CB_ON_MESSAGE_COMPLETE   7
#define CB_ON_CHUNK_HEADER       8
#define CB_ON_CHUNK_COMPLETE     9
#define CB_LEN                   (sizeof(lhp_callback_names)/sizeof(*lhp_callback_names))

static const char *lhp_callback_names[] = {
    /* The MUST be in the same order as the above callbacks */
    "on_message_begin",
    "on_url",
    "on_status",
    "on_header",
    "on_headers_complete",
    "on_body",
    "on_message_complete",
    "on_chunk_header",
    "on_chunk_complete",
};

/* Non-callback FENV indices. */
#define FENV_BUFFER_IDX         CB_LEN + 1
#define FENV_LEN                FENV_BUFFER_IDX

#define FLAGS_BUF_CB_ID_BITS 3
#define FLAGS_BUF_CB_ID_MASK ((1<<(FLAGS_BUF_CB_ID_BITS))-1)
/* Get the cb_id that has information stored in buff */
#define FLAG_GET_BUF_CB_ID(flags) ((flags) & FLAGS_BUF_CB_ID_MASK)

#define FLAGS_CB_ID_FIRST_BIT (1<<(FLAGS_BUF_CB_ID_BITS))
#define CB_ID_TO_CB_BIT(cb_id)  ((FLAGS_CB_ID_FIRST_BIT)<<(cb_id))

/* Test/set/remove a bit from the flags field of lhttp_parser.  The
 * FLAG_*_CB() macros test/set/remove the bit that signifies that a
 * callback with that id has been registered in the FENV.
 *
 * The FLAG_*_BUF() macros test/set/remove the bit that signifies that
 * data is buffered for that callback.
 *
 * The FLAG_*_HFIELD() macros test/set/remove the bit that signifies
 * that the first element of the buffer is the header field key.
 */
#define FLAG_HAS_CB(flags, cb_id)  ( (flags) &   CB_ID_TO_CB_BIT(cb_id) )
#define FLAG_SET_CB(flags, cb_id)  ( (flags) |=  CB_ID_TO_CB_BIT(cb_id) )
#define FLAG_RM_CB(flags, cb_id)   ( (flags) &= ~CB_ID_TO_CB_BIT(cb_id) )

#define FLAG_HAS_BUF(flags, cb_id) ( FLAG_GET_BUF_CB_ID(flags) == cb_id )
#define FLAG_SET_BUF(flags, cb_id) ( (flags) = (((flags) & ~FLAGS_BUF_CB_ID_MASK) \
  | ((cb_id) & FLAGS_BUF_CB_ID_MASK)) )
#define FLAG_RM_BUF(flags)  ( (flags) &= ~FLAGS_BUF_CB_ID_MASK )

#define FLAG_HAS_HFIELD(flags)     ( ((flags) & FLAGS_CB_ID_FIRST_BIT) >> FLAGS_BUF_CB_ID_BITS )
#define FLAG_SET_HFIELD(flags)     ( (flags) |= FLAGS_CB_ID_FIRST_BIT )
#define FLAG_RM_HFIELD(flags)      ( (flags) &= ~FLAGS_CB_ID_FIRST_BIT )

static void lhp_pushint64(lua_State *L, int64_t v){
    // compilers usially remove constant condition on compile time
    if(sizeof(lua_Integer) >= sizeof(int64_t)){
        lua_pushinteger(L, (lua_Integer)v);
        return;
    }
    lua_pushnumber(L, (lua_Number)v);
}

typedef struct lhttp_parser {
    http_parser parser;     /* embedded http_parser. */
    int         flags;      /* See above flag test/set/remove macros. */
    int         buf_len;    /* number of buffered chunks for current callback. */
} lhttp_parser;

/* Concatinate and remove elements from the table at idx starting at
 * element begin and going to length len.  The final concatinated string
 * is on the top of the stack.
 */
static int lhp_table_concat_and_clear(lua_State *L, int idx, int begin, int len) {
    luaL_Buffer   buff;
    int           real_len = len-begin+1;

    /* Empty table? */
    if ( !real_len ) {
        lua_pushliteral(L, "");
        return 0;
    }

    /* One element? */
    if ( 1 == real_len ) {
        lua_rawgeti(L, idx, begin);
        /* remove values from buffer. */
        lua_pushnil(L);
        lua_rawseti(L, idx, begin);
        return 0;
    }

    /* do a table concat. */
    luaL_buffinit(L, &buff);
    for(; begin <= len; begin++) {
        lua_rawgeti(L, idx, begin);
        luaL_addvalue(&buff);
        /* remove values from buffer. */
        lua_pushnil(L);
        lua_rawseti(L, idx, begin);
    }
    luaL_pushresult(&buff);
    return 0;
}

/* Clear all elements in the table at idx starting at
 * element begin and going to length len.
 */
static int lhp_table_clear(lua_State *L, int idx, int begin, int len) {
    /* nil all elements. */
    for(; begin <= len; begin++) {
        /* remove element from table. */
        lua_pushnil(L);
        lua_rawseti(L, idx, begin);
    }
    return 0;
}

/* "Flush" the buffer for the callback identified by cb_id.  The
 * CB_ON_HEADER cb_id is flushed by inspecting FLAG_HAS_HFIELD().
 * If that bit is not set, then the buffer is concatinated into
 * a single string element in the buffer and nothing is pushed
 * on the Lua stack.  Otherwise the buffer table is cleared after
 * pushing the following onto the Lua stack:
 *
 *   CB_ON_HEADER function,
 *   first element of the buffer,
 *   second - length element of the buffer concatinated
 *
 * If cb_id is not CB_ON_HEADER then the buffer table is cleared after
 * pushing the following onto the Lua stack:
 *
 *   cb_id function,
 *   first - length elements of the buffer concatinated
 *   
 */
static int lhp_flush(lhttp_parser* lparser, int cb_id) {
    lua_State*    L = (lua_State*)lparser->parser.data;
    int           begin, len, result, top, save;

    assert(cb_id);
    assert(FLAG_HAS_BUF(lparser->flags, cb_id));

    if ( ! lua_checkstack(L, 7) ) return -1;

    len   = lparser->buf_len;
    begin = 1;
    top   = lua_gettop(L);

    FLAG_RM_BUF(lparser->flags);
    if ( CB_ON_HEADER == cb_id ) {
        if ( FLAG_HAS_HFIELD(lparser->flags) ) {
            /* Push <func>, <arg1>[, <arg2>] */
            lua_rawgeti(L, ST_FENV_IDX, cb_id);
            lua_rawgeti(L, ST_BUFFER_IDX, 1);
            lua_pushnil(L);
            lua_rawseti(L, ST_BUFFER_IDX, 1);

            begin    = 2;
            save     = 0;
            lparser->buf_len = 0;
            FLAG_RM_HFIELD(lparser->flags);
        } else {
            /* Save */
            begin    = 1;
            save     = 1;
            lparser->buf_len = 1;
        }
    } else {
        /* Push <func>[, <arg1>] */
        lua_rawgeti(L, ST_FENV_IDX, cb_id);
        if (CB_ON_STATUS == cb_id){
            lua_pushinteger(L, lparser->parser.status_code);
        }
        begin    = 1;
        save     = 0;
        lparser->buf_len = 0;
    }

    result = lhp_table_concat_and_clear(L, ST_BUFFER_IDX, begin, len);
    if ( 0 != result ) {
        lua_settop(L, top);
        return result;
    }

    if ( save ) lua_rawseti(L, ST_BUFFER_IDX, 1);

    return 0;
}

/* Puts the str of length len into the buffer table and
 * updates buf_len.  It also sets the buf flag for cb_id.
 */
static int lhp_buffer(lhttp_parser* lparser, int cb_id, const char* str, size_t len, int hfield) {
    lua_State* L = (lua_State*)lparser->parser.data;

    assert(cb_id);
    assert(FLAG_HAS_CB(lparser->flags, cb_id));

    /* insert event chunk into buffer. */
    FLAG_SET_BUF(lparser->flags, cb_id);
    if ( hfield ) {
        FLAG_SET_HFIELD(lparser->flags);
    }

    lua_pushlstring(L, str, len);
    lua_rawseti(L, ST_BUFFER_IDX, ++(lparser->buf_len));

    return 0;
}

/* Push the zero argument event for cb_id.  Post condition:
 *  Lua stack contains <func>, nil
 */
static int lhp_push_nil_event(lhttp_parser* lparser, int cb_id) {
    lua_State* L = (lua_State*)lparser->parser.data;

    assert(FLAG_HAS_CB(lparser->flags, cb_id));

    if ( ! lua_checkstack(L, 5) ) return -1;

    lua_rawgeti(L, ST_FENV_IDX, cb_id);
    if(CB_ON_CHUNK_HEADER == cb_id){
      lhp_pushint64(L, lparser->parser.content_length);
    }
    else{
      lua_pushnil(L);
    }

    return 0;
}

/* Flush the buffer as long as it is not the except_cb_id being buffered.
 */
static int lhp_flush_except(lhttp_parser* lparser, int except_cb_id, int hfield) {
    int flush = 0;
    int cb_id = FLAG_GET_BUF_CB_ID(lparser->flags);

    /* flush previous event and/or url */
    if ( cb_id ) {
        if ( cb_id == CB_ON_HEADER ) {
            flush = hfield ^ FLAG_HAS_HFIELD(lparser->flags);
        } else if ( cb_id != except_cb_id ) {
            flush = 1;
        }
    }

    if ( flush ) {
        int result = lhp_flush(lparser, cb_id);
        if ( 0 != result ) return result;
    }
    return 0;
}

/* The event for cb_id where cb_id takes a string argument.
 */
static int lhp_http_data_cb(http_parser* parser, int cb_id, const char* str, size_t len, int hfield) {
    lhttp_parser* lparser = (lhttp_parser*)parser;

    int result = lhp_flush_except(lparser, cb_id, hfield);
    if ( 0 != result ) return result;

    if ( ! FLAG_HAS_CB(lparser->flags, cb_id) ) return 0;

    return lhp_buffer(lparser, cb_id, str, len, hfield);
}

static int lhp_http_cb(http_parser* parser, int cb_id) {
    lhttp_parser* lparser = (lhttp_parser*)parser;

    int result = lhp_flush_except(lparser, cb_id, 0);
    if ( 0 != result ) return result;

    if ( ! FLAG_HAS_CB(lparser->flags, cb_id) ) return 0;

    return lhp_push_nil_event(lparser, cb_id);
}

static int lhp_message_begin_cb(http_parser* parser) {
    return lhp_http_cb(parser, CB_ON_MESSAGE_BEGIN);
}

static int lhp_url_cb(http_parser* parser, const char* str, size_t len) {
    return lhp_http_data_cb(parser, CB_ON_URL, str, len, 0);
}

static int lhp_status_cb(http_parser* parser, const char* str, size_t len) {
    return lhp_http_data_cb(parser, CB_ON_STATUS, str, len, 0);
}

static int lhp_header_field_cb(http_parser* parser, const char* str, size_t len) {
    return lhp_http_data_cb(parser, CB_ON_HEADER, str, len, 0);
}

static int lhp_header_value_cb(http_parser* parser, const char* str, size_t len) {
    return lhp_http_data_cb(parser, CB_ON_HEADER, str, len, 1);
}

static int lhp_headers_complete_cb(http_parser* parser) {
    return lhp_http_cb(parser, CB_ON_HEADERS_COMPLETE);
}

static int lhp_body_cb(http_parser* parser, const char* str, size_t len) {
    /* on_headers_complete did any flushing, so just push the cb */
    lhttp_parser* lparser = (lhttp_parser*)parser;
    lua_State*    L = (lua_State*)lparser->parser.data;

    if ( ! FLAG_HAS_CB(lparser->flags, CB_ON_BODY) ) return 0;

    if ( ! lua_checkstack(L, 5) ) return -1;

    lua_rawgeti(L, ST_FENV_IDX, CB_ON_BODY);
    lua_pushlstring(L, str, len);

    return 0;
}

static int lhp_message_complete_cb(http_parser* parser) {
    /* Send on_body(nil) message to comply with LTN12 */
    lhttp_parser* lparser = (lhttp_parser*)parser;
    if( FLAG_HAS_CB(lparser->flags, CB_ON_BODY) ) {
      int result = lhp_push_nil_event((lhttp_parser*)parser, CB_ON_BODY);
      if ( 0 != result ) return result;
    }

    return lhp_http_cb(parser, CB_ON_MESSAGE_COMPLETE);
}

static int lhp_chunk_header_cb(http_parser* parser) {
    return lhp_http_cb(parser, CB_ON_CHUNK_HEADER);
}

static int lhp_chunk_complete_cb(http_parser* parser) {
    return lhp_http_cb(parser, CB_ON_CHUNK_COMPLETE);
}

static int lhp_init(lua_State* L, enum http_parser_type type) {
    int cb_id;
    /* Stack: callbacks */

    lhttp_parser* lparser;
    http_parser* parser;
    luaL_checktype(L, 1, LUA_TTABLE);
    lparser = (lhttp_parser*)lua_newuserdata(L, sizeof(lhttp_parser));
    parser = &(lparser->parser);
    assert(NULL != parser);
    /* Stack: callbacks, userdata */

    lparser->flags   = 0;
    lparser->buf_len = 0;

    /* Get the metatable: */
    luaL_getmetatable(L, PARSER_MT);
    assert(!lua_isnil(L, -1)/* PARSER_MT found? */);
    /* Stack: callbacks, userdata, metatable */

    /* Copy functions to new fenv table */
    lua_createtable(L, FENV_LEN, 0);
    /* Stack: callbacks, userdata, metatable, fenv */
    for (cb_id = 1; cb_id <= CB_LEN; cb_id++ ) {
        lua_getfield(L, 1, lhp_callback_names[cb_id-1]);
        if ( lua_isfunction(L, -1) ) {
            lua_rawseti(L, -2, cb_id); /* fenv[cb_id] = callback */
            FLAG_SET_CB(lparser->flags, cb_id);
        } else {
            lua_pop(L, 1); /* pop non-function value. */
        }
    }
    /* Create buffer table and add it to the fenv table. */
    lua_createtable(L, 1, 0);
    lua_rawseti(L, -2, FENV_BUFFER_IDX);
    /* Stack: callbacks, userdata, metatable, fenv */
    lua_setfenv(L, -3);
    /* Stack: callbacks, userdata, metatable */

    http_parser_init(parser, type);
    parser->data = NULL;

    lua_setmetatable(L, -2);

    return 1;
}

static int lhp_request(lua_State* L) {
    return lhp_init(L, HTTP_REQUEST);
}

static int lhp_response(lua_State* L) {
    return lhp_init(L, HTTP_RESPONSE);
}

static int lhp_execute(lua_State* L) {
    lhttp_parser* lparser = check_parser(L, 1);
    http_parser*  parser = &(lparser->parser);
    size_t        len;
    size_t        result;
    const char*   str = luaL_checklstring(L, 2, &len);

    static const http_parser_settings settings = {
        lhp_message_begin_cb,
        lhp_url_cb,
        lhp_status_cb,
        lhp_header_field_cb,
        lhp_header_value_cb,
        lhp_headers_complete_cb,
        lhp_body_cb,
        lhp_message_complete_cb,
        lhp_chunk_header_cb,
        lhp_chunk_complete_cb
    };

    /* truncate stack to (userdata, string) */
    lua_settop(L, 2);

    lua_getfenv(L, 1);
    assert(lua_istable(L, -1));
    assert(lua_gettop(L) == ST_FENV_IDX);

    lua_rawgeti(L, ST_FENV_IDX, FENV_BUFFER_IDX);
    assert(lua_istable(L, -1));
    assert(lua_gettop(L) == ST_BUFFER_IDX);

    assert(lua_gettop(L) == ST_LEN);
    lua_pushnil(L);

    /* Stack: (userdata, string, fenv, buffer, url, nil) */
    parser->data = L;

    result = http_parser_execute(parser, &settings, str, len);

    parser->data = NULL;

    /* replace nil place-holder with 'result' code. */
    lhp_pushint64(L, result);
    lua_replace(L, ST_LEN+1);
    /* Transform the stack into a table: */
    len = lua_gettop(L) - ST_LEN;

    return len;
}

static int lhp_should_keep_alive(lua_State* L) {
    lhttp_parser* lparser = check_parser(L, 1);
    lua_pushboolean(L, http_should_keep_alive(&lparser->parser));
    return 1;
}

static int lhp_is_upgrade(lua_State* L) {
    lhttp_parser* lparser = check_parser(L, 1);
    lua_pushboolean(L, lparser->parser.upgrade);
    return 1;
}

static int lhp__tostring(lua_State* L) {
    lhttp_parser* lparser = check_parser(L, 1);
    lua_pushfstring(L, PARSER_MT" %p", lparser);
    return 1;
}

static int lhp_method(lua_State* L) {
    lhttp_parser* lparser = check_parser(L, 1);
    switch(lparser->parser.method) {
    case HTTP_DELETE:    lua_pushliteral(L, "DELETE"); break;
    case HTTP_GET:       lua_pushliteral(L, "GET"); break;
    case HTTP_HEAD:      lua_pushliteral(L, "HEAD"); break;
    case HTTP_POST:      lua_pushliteral(L, "POST"); break;
    case HTTP_PUT:       lua_pushliteral(L, "PUT"); break;
    case HTTP_CONNECT:   lua_pushliteral(L, "CONNECT"); break;
    case HTTP_OPTIONS:   lua_pushliteral(L, "OPTIONS"); break;
    case HTTP_TRACE:     lua_pushliteral(L, "TRACE"); break;
    case HTTP_COPY:      lua_pushliteral(L, "COPY"); break;
    case HTTP_LOCK:      lua_pushliteral(L, "LOCK"); break;
    case HTTP_MKCOL:     lua_pushliteral(L, "MKCOL"); break;
    case HTTP_MOVE:      lua_pushliteral(L, "MOVE"); break;
    case HTTP_PROPFIND:  lua_pushliteral(L, "PROPFIND"); break;
    case HTTP_PROPPATCH: lua_pushliteral(L, "PROPPATCH"); break;
    case HTTP_UNLOCK:    lua_pushliteral(L, "UNLOCK"); break;
    default:
        lua_pushnumber(L, lparser->parser.method);
    }
    return 1;
}

static int lhp_version(lua_State* L) {
    lhttp_parser* lparser = check_parser(L, 1);
    lua_pushnumber(L, lparser->parser.http_major);
    lua_pushnumber(L, lparser->parser.http_minor);
    return 2;
}

static int lhp_status_code(lua_State* L) {
    lhttp_parser* lparser = check_parser(L, 1);
    lua_pushnumber(L, lparser->parser.status_code);
    return 1;
}

static int lhp_error(lua_State* L) {
    lhttp_parser* lparser = check_parser(L, 1);
    enum http_errno http_errno = lparser->parser.http_errno;
    lua_pushinteger(L, http_errno);
    lua_pushstring(L, http_errno_name(http_errno));
    lua_pushstring(L, http_errno_description(http_errno));
    return 3;
}

static int lhp_parse_url(lua_State* L){

#define SET_UF_FIELD(id, name) \
    if(url.field_set & (1 << id)){ \
      lua_pushlstring(L, u + url.field_data[id].off, url.field_data[id].len); \
      lua_setfield(L, -2, name); \
    }

    size_t len; const char *u = luaL_checklstring(L, 1, &len);
    int is_connect = lua_toboolean(L, 2);
    struct http_parser_url url;
    int result = http_parser_parse_url(u, len, is_connect, &url);
    if (result != 0) {
      lua_pushnil(L);
      lua_pushinteger(L, result);
    }

    lua_newtable(L);

    if(url.field_set & (1 << UF_PORT)){
      lua_pushinteger(L, url.port);
      lua_setfield(L, -2, "port");
    }

    SET_UF_FIELD(UF_SCHEMA,   "schema"  );
    SET_UF_FIELD(UF_HOST,     "host"    );
    SET_UF_FIELD(UF_PATH,     "path"    );
    SET_UF_FIELD(UF_QUERY,    "query"   );
    SET_UF_FIELD(UF_FRAGMENT, "fragment");
    SET_UF_FIELD(UF_USERINFO, "userinfo");

    return 1;
#undef SET_UF_FIELD
}

static int lhp_reset(lua_State* L) {
    lhttp_parser* lparser = check_parser(L, 1);
    http_parser*  parser = &(lparser->parser);

    /* truncate stack to (userdata) and calbacks */
    lua_settop(L, 2);

    /* re-initialize http-parser. */
    http_parser_init(parser, parser->type);

    /* truncate stack to (userdata) calbacks fenv */
    lua_getfenv(L, 1);

    /* reset callbacks */
    if(lua_istable(L, 2)){
        int cb_id;
        for (cb_id = 1; cb_id <= CB_LEN; cb_id++ ) {
            lua_getfield(L, 2, lhp_callback_names[cb_id-1]);
            if ( lua_isfunction(L, -1) ) {
                FLAG_SET_CB(lparser->flags, cb_id);
            } else {
                FLAG_RM_CB(lparser->flags, cb_id);
                lua_pop(L, 1); /* pop non-function value. */
                lua_pushnil(L); /* set callback as nil */
            }
            lua_rawseti(L, -2, cb_id); /* fenv[cb_id] = callback */
        }
    }

    /* clear buffer */
    lua_rawgeti(L, 2, FENV_BUFFER_IDX);
    lhp_table_clear(L, 3, 1, lparser->buf_len);

    /* reset buffer length and flags. */
    lparser->buf_len = 0;
    FLAG_RM_BUF(lparser->flags);
    FLAG_RM_HFIELD(lparser->flags);
    return 0;
}

static int lhp_is_function(lua_State* L) {
    lua_pushboolean(L, lua_isfunction(L, 1));
    return 1;
}

/* The execute method has a "lua based stub" so that callbacks
 * can yield without having to apply the CoCo patch to Lua. */
static const char* lhp_execute_lua =
    "local c_execute, is_function = ...\n"
    "local function execute(result, cb, arg1, arg2, ...)\n"
    "    if ( not cb ) then\n"
    "        return result\n"
    "    end\n"
    "    if ( is_function(arg2) ) then\n"
    "        cb(arg1)\n"
    "        return execute(result, arg2, ...)"
    "    end\n"
    "    cb(arg1, arg2)\n"
    "    return execute(result, ...)\n"
    "end\n"
    "return function(...)\n"
    "    return execute(c_execute(...))\n"
    "end";
static void lhp_push_execute_fn(lua_State* L) {
#ifndef NDEBUG
    int top = lua_gettop(L);
#endif
    int err  = luaL_loadstring(L, lhp_execute_lua);

    if ( err ) lua_error(L);

    lua_pushcfunction(L, lhp_execute);
    lua_pushcfunction(L, lhp_is_function);
    lua_call(L, 2, 1);

    /* Compiled lua function should be at the top of the stack now. */
    assert(lua_gettop(L) == top + 1);
    assert(lua_isfunction(L, -1));
}

LUALIB_API int luaopen_http_parser(lua_State* L) {
    /* parser metatable init */
    luaL_newmetatable(L, PARSER_MT);

    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");

    lua_pushcfunction(L, lhp_is_upgrade);
    lua_setfield(L, -2, "is_upgrade");

    lua_pushcfunction(L, lhp__tostring);
    lua_setfield(L, -2, "__tostring");

    lua_pushcfunction(L, lhp_method);
    lua_setfield(L, -2, "method");

    lua_pushcfunction(L, lhp_version);
    lua_setfield(L, -2, "version");

    lua_pushcfunction(L, lhp_status_code);
    lua_setfield(L, -2, "status_code");

    lua_pushcfunction(L, lhp_error);
    lua_setfield(L, -2, "error");

    lua_pushcfunction(L, lhp_should_keep_alive);
    lua_setfield(L, -2, "should_keep_alive");

    lhp_push_execute_fn(L);
    lua_setfield(L, -2, "execute");

    lua_pushcfunction(L, lhp_reset);
    lua_setfield(L, -2, "reset");

    lua_pop(L, 1);

    /* export http.parser */
    lua_newtable(L); /* Stack: table */

    lua_pushcfunction(L, lhp_request);
    lua_setfield(L, -2, "request");

    lua_pushcfunction(L, lhp_response);
    lua_setfield(L, -2, "response");

    lua_pushcfunction(L, lhp_parse_url);
    lua_setfield(L, -2, "parse_url");
    
    return 1;
}
