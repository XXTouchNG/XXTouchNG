// CodeMirror, copyright (c) by Marijn Haverbeke and others
// Distributed under an MIT license: http://codemirror.net/LICENSE

// LUA mode. Ported to CodeMirror 2 from Franciszek Wawrzak's
// CodeMirror 1 mode.
// highlights keywords, strings, comments (no leveling supported! ("[==[")), tokens, basic indenting

(function(mod) {
  if (typeof exports == "object" && typeof module == "object") // CommonJS
    mod(require("../../lib/codemirror"));
  else if (typeof define == "function" && define.amd) // AMD
    define(["../../lib/codemirror"], mod);
  else // Plain browser env
    mod(CodeMirror);
})(function(CodeMirror) {
"use strict";

CodeMirror.defineMode("lua", function(config, parserConfig) {
  var indentUnit = config.indentUnit;

  function prefixRE(words) {
    return new RegExp("^(?:" + words.join("|") + ")", "i");
  }
  function wordRE(words) {
    return new RegExp("^(?:" + words.join("|") + ")$", "i");
  }
  var specials = wordRE(parserConfig.specials || []);

  // long list of standard functions from lua manual
  var builtins = wordRE([
    "_G","_VERSION","assert","collectgarbage","dofile","error","getfenv","getmetatable","ipairs","load",
    "loadfile","loadstring","module","next","pairs","pcall","print","rawequal","rawget","rawset","require",
    "select","setfenv","setmetatable","tonumber","tostring","type","unpack","xpcall",

    "coroutine.create","coroutine.resume","coroutine.running","coroutine.status","coroutine.wrap","coroutine.yield",

    "debug.debug","debug.getfenv","debug.gethook","debug.getinfo","debug.getlocal","debug.getmetatable",
    "debug.getregistry","debug.getupvalue","debug.setfenv","debug.sethook","debug.setlocal","debug.setmetatable",
    "debug.setupvalue","debug.traceback",

    "close","flush","lines","read","seek","setvbuf","write",

    "io.close","io.flush","io.input","io.lines","io.open","io.output","io.popen","io.read","io.stderr","io.stdin",
    "io.stdout","io.tmpfile","io.type","io.write",

    "math.abs","math.acos","math.asin","math.atan","math.atan2","math.ceil","math.cos","math.cosh","math.deg",
    "math.exp","math.floor","math.fmod","math.frexp","math.huge","math.ldexp","math.log","math.log10","math.max",
    "math.min","math.modf","math.pi","math.pow","math.rad","math.random","math.randomseed","math.sin","math.sinh",
    "math.sqrt","math.tan","math.tanh",

    "os.clock","os.date","os.difftime","os.execute","os.exit","os.getenv","os.remove","os.rename","os.setlocale",
    "os.time","os.tmpname",

    "package.cpath","package.loaded","package.loaders","package.loadlib","package.path","package.preload",
    "package.seeall",

    "string.byte","string.char","string.dump","string.find","string.format","string.gmatch","string.gsub",
    "string.len","string.lower","string.match","string.rep","string.reverse","string.sub","string.upper",

    "table.concat","table.insert","table.maxn","table.remove","table.sort",
    
    /* XXTouch */
    
    "os.restart","print.out","nLog",
    
    "screen.init","screen.init_home_on_bottom","screen.init_home_on_right","screen.init_home_on_left","screen.init_home_on_top",
    "screen.rotate_xy","screen.size","screen.keep","screen.unkeep","screen.is_keeped","screen.get_color",
    "screen.get_color_rgb","screen.is_colors","screen.find_color","screen.image","screen.ocr_text","screen.find_image",
    
    "touch.tap","touch.on",":move",":press",":off",":step_len",":step_delay",":msleep","touch.show_pose",
    
    "key.press","key.down","key.up","key.send_text",
    
    "accelerometer.simulate","accelerometer.shake","accelerometer.rotate_home_on_left","accelerometer.rotate_home_on_right",
    "accelerometer.rotate_home_on_top","accelerometer.rotate_home_on_bottom",
    
    "sys.toast","sys.alert","sys.input_box","sys.input_text","sys.msleep","sys.mtime","sys.net_time","sys.rnd","sys.memory_info",
    "sys.available_memory","sys.free_disk_space","sys.log","sys.version","sys.xtversion",
    
    "pasteboard.write","pasteboard.read",
    
    "dialog",":config",":timeout",":title",":add_label",":add_input",":add_image",":add_switch",":add_picker",":add_radio",
    ":add_checkbox",":add_range",":show",":load",
    
    "clear.keychain","clear.all_keychain","clear.pasteboard","clear.cookies","clear.caches","clear.all_photos","clear.app_data",
    "clear.idfav",
    
    "app.bundle_path","app.data_path","app.run","app.close","app.quit","app.is_running","app.input_text","app.localized_name",
    "app.png_data_for_bid","app.pid_for_bid","app.used_memory","app.front_bid","app.front_pid","app.open_url","app.bundles",
    "app.all_procs","app.set_speed_add","app.mem_base_address","app.mem_find","app.mem_read","app.mem_write","app.install",
    "app.uninstall",
    
    "device.reset_idle","device.lock_screen","device.unlock_screen","device.is_screen_locked","device.front_orien","device.lock_orien",
    "device.unlock_orien","device.is_orien_locked","device.vibrator","device.play_sound","device.type","device.name","device.set_name",
    "device.udid","device.serial_number","device.wifi_mac","device.ifaddrs","device.battery_level","device.battery_state",
    "device.turn_on_wifi","device.turn_off_wifi","device.turn_on_data","device.turn_off_data","device.turn_on_bluetooth",
    "device.turn_off_bluetooth","device.turn_on_airplane","device.turn_off_airplane","device.turn_on_vpn","device.turn_off_vpn",
    "device.is_vpn_on","device.flash_on","device.flash_off","device.reduce_motion_on","device.reduce_motion_off",
    "device.assistive_touch_on","device.assistive_touch_off","device.brightness","device.set_brightness","device.set_volume",
    
    "image.is","image.new","image.oper_merge","image.new_text_image","image.load_file","image.load_data",
    ":copy",":crop",":save_to_album",":save_to_png_file",":save_to_jpeg_file",":png_data",":jpeg_data",":turn_left",":turn_right",
    ":turn_upondown",":size",":get_color",":set_color",":replace_color",":draw_image",":binaryzation",":find_color",":is_colors",
    ":qr_decode",":destroy",":cv_find_image",":cv_binaryzation",":cv_resize",":tess_ocr",
    
    "proc_put","proc_get","proc_queue_push","proc_queue_pop","proc_queue_clear","proc_queue_size",
    
    "thread.dispatch","thread.current_id","thread.kill","thread.timer_start","thread.timer_stop","thread.wait","thread.register_event",
    "thread.unregister_event",
    
    "webview.show","webview.hide","webview.eval","webview.frame","webview.destroy",
    
    "table.deep_copy","table.deep_print",
    
    "string.to_hex","string.from_hex","string.from_gbk","string.md5","string.sha1","string.base64_encode","string.base64_decode",
    "string.aes128_encrypt","string.aes128_decrypt","string.split","string.ltrim","string.rtrim","string.trim","string.atrim",
    "string.random",
    
    "http.get","http.post","http.download","http.head","http.delete","http.put",
    
    "ftp.download","ftp.upload",
    
    "json.encode","json.decode",
    
    "plist.read","plist.write",
    
    "utils.add_contacts","utils.remove_all_contacts","utils.open_code_scanner","utils.close_code_scanner","utils.qr_encode",
    "utils.launch_args","utils.is_launch_via_app","utils.video_to_album",
    
    "file.exists","file.list","file.size","file.reads","file.writes","file.appends","file.line_count","file.get_line","file.set_line",
    "file.insert_line","file.remove_line","file.get_lines","file.set_lines","file.insert_lines",
    
    "cloud_ocr.ocr","vocr.ocr_screen","vocr.ocr_image","vocr.ocr_obj","vocr.report_error",
    
    "gps.fake","gps.clear"
    
    /* XXTouch */
  ]);
  var keywords = wordRE(["and","break","elseif","false","nil","not","or","return",
                         "true","function", "end", "if", "then", "else", "do",
                         "while", "repeat", "until", "for", "in", "local" ]);

  var indentTokens = wordRE(["function", "if","repeat","do", "\\(", "{"]);
  var dedentTokens = wordRE(["end", "until", "\\)", "}"]);
  var dedentPartial = prefixRE(["end", "until", "\\)", "}", "else", "elseif"]);

  function readBracket(stream) {
    var level = 0;
    while (stream.eat("=")) ++level;
    stream.eat("[");
    return level;
  }

  function normal(stream, state) {
    var ch = stream.next();
    if (ch == "-" && stream.eat("-")) {
      if (stream.eat("[") && stream.eat("["))
        return (state.cur = bracketed(readBracket(stream), "comment"))(stream, state);
      stream.skipToEnd();
      return "comment";
    }
    if (ch == "\"" || ch == "'")
      return (state.cur = string(ch))(stream, state);
    if (ch == "[" && /[\[=]/.test(stream.peek()))
      return (state.cur = bracketed(readBracket(stream), "string"))(stream, state);
    if (/\d/.test(ch)) {
      stream.eatWhile(/[\w.%]/);
      return "number";
    }
    if (/[\w_]/.test(ch)) {
      stream.eatWhile(/[\w\\\-_.]/);
      return "variable";
    }
    return null;
  }

  function bracketed(level, style) {
    return function(stream, state) {
      var curlev = null, ch;
      while ((ch = stream.next()) != null) {
        if (curlev == null) {if (ch == "]") curlev = 0;}
        else if (ch == "=") ++curlev;
        else if (ch == "]" && curlev == level) { state.cur = normal; break; }
        else curlev = null;
      }
      return style;
    };
  }

  function string(quote) {
    return function(stream, state) {
      var escaped = false, ch;
      while ((ch = stream.next()) != null) {
        if (ch == quote && !escaped) break;
        escaped = !escaped && ch == "\\";
      }
      if (!escaped) state.cur = normal;
      return "string";
    };
  }

  return {
    startState: function(basecol) {
      return {basecol: basecol || 0, indentDepth: 0, cur: normal};
    },

    token: function(stream, state) {
      if (stream.eatSpace()) return null;
      var style = state.cur(stream, state);
      var word = stream.current();
      if (style == "variable") {
        if (keywords.test(word)) style = "keyword";
        else if (builtins.test(word)) style = "builtin";
        else if (specials.test(word)) style = "variable-2";
      }
      if ((style != "comment") && (style != "string")){
        if (indentTokens.test(word)) ++state.indentDepth;
        else if (dedentTokens.test(word)) --state.indentDepth;
      }
      return style;
    },

    indent: function(state, textAfter) {
      var closing = dedentPartial.test(textAfter);
      return state.basecol + indentUnit * (state.indentDepth - (closing ? 1 : 0));
    },

    lineComment: "--",
    blockCommentStart: "--[[",
    blockCommentEnd: "]]"
  };
});

CodeMirror.defineMIME("text/x-lua", "lua");

});
