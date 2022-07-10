#ifndef MY_CHHOOK_H
#define MY_CHHOOK_H

#import <malloc/malloc.h>
#import <mach/mach_time.h>
#import <libkern/OSAtomic.h>
#import <dlfcn.h>
#import "substrate.h"

#define OCGetIvar(obj, name) object_getIvar((obj), class_getInstanceVariable(object_getClass(obj), #name))
#define OCSetIvar(obj, name, value) object_setIvar((obj), class_getInstanceVariable(object_getClass(obj), #name), (value))

#define OCall(obj, sel, args...) \
	(id)objc_msgSend(obj, @selector(sel), args)
#define OCal0(obj, sel) \
	(id)objc_msgSend(obj, @selector(sel))


#ifdef __cplusplus
extern "C" id objc_msgSendSuper2(struct objc_super *, SEL, ...);
#define XXTouchF_CAPI extern "C" 
#else
extern id objc_msgSendSuper2(struct objc_super *, SEL, ...);
#define XXTouchF_CAPI extern 
#endif

//OBJC_EXTERN void _AddFuncToFakedList(void *orig_func, void *repl_func);

#define OCSuperDealloc(obj) \
{\
	struct objc_super the_super;\
	the_super.receiver = obj;\
	the_super.super_class = class_getSuperclass(object_getClass(obj));\
	objc_msgSendSuper2(&the_super, @selector(dealloc));\
}

#define _cc(cls) objc_getClass(CHStringify(cls))
#define _mcc(cls) objc_getMetaClass(CHStringify(cls))

#define IS_OBJECT_VALID(P) (malloc_zone_from_ptr(P) != NULL)

#ifdef CHDebug
	#define MyLog CHDebugLog
#else
	#define MyLog(...)
#endif

__attribute__((unused)) CHInline
static BOOL MyHookMessage(Class cls, SEL sel, IMP repl_imp, IMP *orig_imp_export)
{
	if (cls != nil) {
		Method orig_method = class_getInstanceMethod(cls, sel);
		if (orig_method != nil) {
			IMP orig_imp = method_getImplementation(orig_method);
			if (orig_imp_export != nil) {
				*orig_imp_export = orig_imp;
			}
//			_AddFuncToFakedList((void *)orig_imp, (void *)repl_imp);
			method_setImplementation(orig_method, (IMP)repl_imp);
			return YES;
		}
	}
	return NO;
}

__attribute__((unused)) CHInline
static BOOL MyHookClassMessage(Class cls, SEL sel, IMP repl_imp, IMP *orig_imp_export)
{
	if (cls != nil) {
		Method orig_method = class_getClassMethod(cls, sel);
		if (orig_method != nil) {
			IMP orig_imp = method_getImplementation(orig_method);
			if (orig_imp_export != nil) {
				*orig_imp_export = orig_imp;
			}
//			_AddFuncToFakedList((void *)orig_imp, (void *)repl_imp);
			method_setImplementation(orig_method, (IMP)repl_imp);
			return YES;
		}
	}
	return NO;
}


#pragma mark - Locations

#define MEDIA_ROOT              "/var/mobile/Media/1ferver"              // (owned by mobile)
#define MEDIA_LUA_DIR           "/var/mobile/Media/1ferver/lua"
#define MEDIA_LUA_SCRIPTS_DIR   "/var/mobile/Media/1ferver/lua/scripts"
#define MEDIA_BIN_DIR           "/var/mobile/Media/1ferver/bin"          // -> /usr/local/xxtouch/bin
#define MEDIA_LIB_DIR           "/var/mobile/Media/1ferver/lib"          // -> /usr/local/xxtouch/lib
#define MEDIA_LOG_DIR           "/var/mobile/Media/1ferver/log"          // -> /usr/local/xxtouch/log
#define MEDIA_CONF_DIR          "/var/mobile/Media/1ferver/conf"         // -> /usr/local/xxtouch/etc
#define MEDIA_WEB_DIR           "/var/mobile/Media/1ferver/web"          // -> /usr/local/xxtouch/web
#define MEDIA_RES_DIR           "/var/mobile/Media/1ferver/res"
#define MEDIA_CACHES_DIR        "/var/mobile/Media/1ferver/caches"
#define MEDIA_SNIPPETS_DIR      "/var/mobile/Media/1ferver/snippets"
#define MEDIA_UICFG_DIR         "/var/mobile/Media/1ferver/uicfg"
#define MEDIA_TESSDATA_DIR      "/var/mobile/Media/1ferver/tessdata"

#define BIN_LAUNCHER            "/usr/local/xxtouch/bin/lua"
#define BIN_COMPILER            "/usr/local/xxtouch/bin/luac"
#define BIN_RECORDER            "/usr/local/xxtouch/bin/hidrecorder"

#define CONF_LEGACY             "/var/mobile/Media/1ferver/1ferver.conf"
#define CONF_EXPLORER           "/var/mobile/Library/Preferences/ch.xxtou.XXTExplorer.plist"
#define CONF_DEBUG_WINDOW       "/var/mobile/Library/Preferences/ch.xxtou.DebugWindow.plist"
#define CONF_ALERT_HELPER       "/var/mobile/Library/Preferences/ch.xxtou.AlertHelper.plist"
#define CONF_TAMPER_MONKEY      "/var/mobile/Library/Preferences/ch.xxtou.TamperMonkey.plist"

#define LOG_SYS                 "/usr/local/xxtouch/log/sys.log"
#define LOG_LAUNCHER_OUTPUT     "/usr/local/xxtouch/log/script_output.log"
#define LOG_LAUNCHER_ERROR      "/usr/local/xxtouch/log/script_error.log"

#define LOG_ALERT_HELPER_DIR    "/var/mobile/Library/Caches/ch.xxtou.AlertHelper"
#define LOG_TAMPER_MONKEY_DIR   "/var/mobile/Library/Caches/ch.xxtou.TamperMonkey"


#pragma mark - Services

#define SERVICE_APP             "ch.xxtou.tfcontainermanagerd"
#define SERVICE_TOUCH           "ch.xxtou.simulatetouchd"
#define SERVICE_PROC            "ch.xxtou.procqueued"
#define SERVICE_SUPERVISOR      "ch.xxtou.supervisord"
#define SERVICE_WEBSERV         "ch.xxtou.webserv"
#define SERVICE_SPRINGBOARD     "com.apple.SpringBoard"                  // SpringBoard is an important XXTouch service ;-)


#pragma mark - Notifications (Dismissal)

#define NOTIFY_DISMISSAL_SYS_ALERT      "ch.xxtou.notification.dismissal.sys.alert"
#define NOTIFY_DISMISSAL_SYS_TOAST      "ch.xxtou.notification.dismissal.sys.toast"
#define NOTIFY_DISMISSAL_TOUCH_POSE     "ch.xxtou.notification.dismissal.touch.show_pose"


#pragma mark - Notification (Task)

#define NOTIFY_TASK_DID_BEGIN           "ch.xxtou.notification.task.begin"
#define NOTIFY_TASK_DID_END             "ch.xxtou.notification.task.end"
#define NOTIFY_TASK_DID_END_HINT        "ch.xxtou.notification.task.end.hint"

#define NOTIFY_RECORD_DID_BEGIN         "ch.xxtou.notification.record.begin"
#define NOTIFY_RECORD_DID_END           "ch.xxtou.notification.record.end"


#endif  /* MY_CHHOOK_H */
