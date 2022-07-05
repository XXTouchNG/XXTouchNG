#line 1 "LogosDingtone.xm"

#include <substrate.h>
#if defined(__clang__)
#if __has_feature(objc_arc)
#define _LOGOS_SELF_TYPE_NORMAL __unsafe_unretained
#define _LOGOS_SELF_TYPE_INIT __attribute__((ns_consumed))
#define _LOGOS_SELF_CONST const
#define _LOGOS_RETURN_RETAINED __attribute__((ns_returns_retained))
#else
#define _LOGOS_SELF_TYPE_NORMAL
#define _LOGOS_SELF_TYPE_INIT
#define _LOGOS_SELF_CONST
#define _LOGOS_RETURN_RETAINED
#endif
#else
#define _LOGOS_SELF_TYPE_NORMAL
#define _LOGOS_SELF_TYPE_INIT
#define _LOGOS_SELF_CONST
#define _LOGOS_RETURN_RETAINED
#endif

@class DTSubscriptionModel; @class InAppPurchaseManager; @class TZIAPManager; @class DTNativeAdMgr; @class WKWebView; @class ADCDevice; @class NUtils; @class TZSKPaymentManager; @class DTAdFreeMgr; 


#line 1 "LogosDingtone.xm"
static bool (*_logos_orig$DingtoneAds$DTAdFreeMgr$isAdFreeNow$)(_LOGOS_SELF_TYPE_NORMAL DTAdFreeMgr* _LOGOS_SELF_CONST, SEL, bool); static bool _logos_method$DingtoneAds$DTAdFreeMgr$isAdFreeNow$(_LOGOS_SELF_TYPE_NORMAL DTAdFreeMgr* _LOGOS_SELF_CONST, SEL, bool); static bool (*_logos_orig$DingtoneAds$DTNativeAdMgr$canDisplayAvaiableNativeAd$)(_LOGOS_SELF_TYPE_NORMAL DTNativeAdMgr* _LOGOS_SELF_CONST, SEL, int); static bool _logos_method$DingtoneAds$DTNativeAdMgr$canDisplayAvaiableNativeAd$(_LOGOS_SELF_TYPE_NORMAL DTNativeAdMgr* _LOGOS_SELF_CONST, SEL, int); static bool (*_logos_meta_orig$DingtoneAds$DTSubscriptionModel$canBuySubscription$)(_LOGOS_SELF_TYPE_NORMAL Class _LOGOS_SELF_CONST, SEL, void *); static bool _logos_meta_method$DingtoneAds$DTSubscriptionModel$canBuySubscription$(_LOGOS_SELF_TYPE_NORMAL Class _LOGOS_SELF_CONST, SEL, void *); static long long (*_logos_orig$DingtoneAds$DTSubscriptionModel$status)(_LOGOS_SELF_TYPE_NORMAL DTSubscriptionModel* _LOGOS_SELF_CONST, SEL); static long long _logos_method$DingtoneAds$DTSubscriptionModel$status(_LOGOS_SELF_TYPE_NORMAL DTSubscriptionModel* _LOGOS_SELF_CONST, SEL); static NSString * (*_logos_orig$DingtoneAds$ADCDevice$collectMACAddress$)(_LOGOS_SELF_TYPE_NORMAL ADCDevice* _LOGOS_SELF_CONST, SEL, NSError **); static NSString * _logos_method$DingtoneAds$ADCDevice$collectMACAddress$(_LOGOS_SELF_TYPE_NORMAL ADCDevice* _LOGOS_SELF_CONST, SEL, NSError **); static bool (*_logos_meta_orig$DingtoneAds$NUtils$isValidatIP$)(_LOGOS_SELF_TYPE_NORMAL Class _LOGOS_SELF_CONST, SEL, id); static bool _logos_meta_method$DingtoneAds$NUtils$isValidatIP$(_LOGOS_SELF_TYPE_NORMAL Class _LOGOS_SELF_CONST, SEL, id); static NSString * (*_logos_meta_orig$DingtoneAds$NUtils$getIPAddressByCheckFormat$)(_LOGOS_SELF_TYPE_NORMAL Class _LOGOS_SELF_CONST, SEL, BOOL); static NSString * _logos_meta_method$DingtoneAds$NUtils$getIPAddressByCheckFormat$(_LOGOS_SELF_TYPE_NORMAL Class _LOGOS_SELF_CONST, SEL, BOOL); static void * (*_logos_orig$DingtoneAds$InAppPurchaseManager$init)(_LOGOS_SELF_TYPE_NORMAL InAppPurchaseManager* _LOGOS_SELF_CONST, SEL); static void * _logos_method$DingtoneAds$InAppPurchaseManager$init(_LOGOS_SELF_TYPE_NORMAL InAppPurchaseManager* _LOGOS_SELF_CONST, SEL); static void * (*_logos_orig$DingtoneAds$TZIAPManager$init)(_LOGOS_SELF_TYPE_NORMAL TZIAPManager* _LOGOS_SELF_CONST, SEL); static void * _logos_method$DingtoneAds$TZIAPManager$init(_LOGOS_SELF_TYPE_NORMAL TZIAPManager* _LOGOS_SELF_CONST, SEL); static void * (*_logos_orig$DingtoneAds$TZSKPaymentManager$init)(_LOGOS_SELF_TYPE_NORMAL TZSKPaymentManager* _LOGOS_SELF_CONST, SEL); static void * _logos_method$DingtoneAds$TZSKPaymentManager$init(_LOGOS_SELF_TYPE_NORMAL TZSKPaymentManager* _LOGOS_SELF_CONST, SEL); static WKWebView* (*_logos_meta_orig$DingtoneAds$WKWebView$alloc)(_LOGOS_SELF_TYPE_NORMAL Class _LOGOS_SELF_CONST, SEL) _LOGOS_RETURN_RETAINED; static WKWebView* _logos_meta_method$DingtoneAds$WKWebView$alloc(_LOGOS_SELF_TYPE_NORMAL Class _LOGOS_SELF_CONST, SEL) _LOGOS_RETURN_RETAINED; 


static bool _logos_method$DingtoneAds$DTAdFreeMgr$isAdFreeNow$(_LOGOS_SELF_TYPE_NORMAL DTAdFreeMgr* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, bool arg2) {
    _logos_orig$DingtoneAds$DTAdFreeMgr$isAdFreeNow$(self, _cmd, arg2);
    return YES;
}



static bool _logos_method$DingtoneAds$DTNativeAdMgr$canDisplayAvaiableNativeAd$(_LOGOS_SELF_TYPE_NORMAL DTNativeAdMgr* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, int arg2) {
    return NO;
}



static bool _logos_meta_method$DingtoneAds$DTSubscriptionModel$canBuySubscription$(_LOGOS_SELF_TYPE_NORMAL Class _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, void * arg2) {
    return NO;
}
static long long _logos_method$DingtoneAds$DTSubscriptionModel$status(_LOGOS_SELF_TYPE_NORMAL DTSubscriptionModel* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd) {
    return 1;
}



static NSString * _logos_method$DingtoneAds$ADCDevice$collectMACAddress$(_LOGOS_SELF_TYPE_NORMAL ADCDevice* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, NSError ** arg2) {
    return @"02:00:00:00:00:00";
}



static bool _logos_meta_method$DingtoneAds$NUtils$isValidatIP$(_LOGOS_SELF_TYPE_NORMAL Class _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, id arg2) {
    return YES;
}
static NSString * _logos_meta_method$DingtoneAds$NUtils$getIPAddressByCheckFormat$(_LOGOS_SELF_TYPE_NORMAL Class _LOGOS_SELF_CONST __unused self, SEL __unused _cmd, BOOL validate) {
    return @"192.168.100.101";
}




static void * _logos_method$DingtoneAds$InAppPurchaseManager$init(_LOGOS_SELF_TYPE_NORMAL InAppPurchaseManager* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd) {
    return nil;
}



static void * _logos_method$DingtoneAds$TZIAPManager$init(_LOGOS_SELF_TYPE_NORMAL TZIAPManager* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd) {
    return nil;
}



static void * _logos_method$DingtoneAds$TZSKPaymentManager$init(_LOGOS_SELF_TYPE_NORMAL TZSKPaymentManager* _LOGOS_SELF_CONST __unused self, SEL __unused _cmd) {
    return nil;
}



static WKWebView* _logos_meta_method$DingtoneAds$WKWebView$alloc(_LOGOS_SELF_TYPE_NORMAL Class _LOGOS_SELF_CONST __unused self, SEL __unused _cmd) _LOGOS_RETURN_RETAINED {
    NSLog(@"+[<WKWebView: %p> alloc]", self); return nil;
}




static __attribute__((constructor)) void _logosLocalCtor_c16daf74(int __unused argc, char __unused **argv, char __unused **envp) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    {Class _logos_class$DingtoneAds$DTAdFreeMgr = objc_getClass("DTAdFreeMgr"); { MSHookMessageEx(_logos_class$DingtoneAds$DTAdFreeMgr, @selector(isAdFreeNow:), (IMP)&_logos_method$DingtoneAds$DTAdFreeMgr$isAdFreeNow$, (IMP*)&_logos_orig$DingtoneAds$DTAdFreeMgr$isAdFreeNow$);}Class _logos_class$DingtoneAds$DTNativeAdMgr = objc_getClass("DTNativeAdMgr"); { MSHookMessageEx(_logos_class$DingtoneAds$DTNativeAdMgr, @selector(canDisplayAvaiableNativeAd:), (IMP)&_logos_method$DingtoneAds$DTNativeAdMgr$canDisplayAvaiableNativeAd$, (IMP*)&_logos_orig$DingtoneAds$DTNativeAdMgr$canDisplayAvaiableNativeAd$);}Class _logos_class$DingtoneAds$DTSubscriptionModel = objc_getClass("DTSubscriptionModel"); Class _logos_metaclass$DingtoneAds$DTSubscriptionModel = object_getClass(_logos_class$DingtoneAds$DTSubscriptionModel); { MSHookMessageEx(_logos_metaclass$DingtoneAds$DTSubscriptionModel, @selector(canBuySubscription:), (IMP)&_logos_meta_method$DingtoneAds$DTSubscriptionModel$canBuySubscription$, (IMP*)&_logos_meta_orig$DingtoneAds$DTSubscriptionModel$canBuySubscription$);}{ MSHookMessageEx(_logos_class$DingtoneAds$DTSubscriptionModel, @selector(status), (IMP)&_logos_method$DingtoneAds$DTSubscriptionModel$status, (IMP*)&_logos_orig$DingtoneAds$DTSubscriptionModel$status);}Class _logos_class$DingtoneAds$ADCDevice = objc_getClass("ADCDevice"); { MSHookMessageEx(_logos_class$DingtoneAds$ADCDevice, @selector(collectMACAddress:), (IMP)&_logos_method$DingtoneAds$ADCDevice$collectMACAddress$, (IMP*)&_logos_orig$DingtoneAds$ADCDevice$collectMACAddress$);}Class _logos_class$DingtoneAds$NUtils = objc_getClass("NUtils"); Class _logos_metaclass$DingtoneAds$NUtils = object_getClass(_logos_class$DingtoneAds$NUtils); { MSHookMessageEx(_logos_metaclass$DingtoneAds$NUtils, @selector(isValidatIP:), (IMP)&_logos_meta_method$DingtoneAds$NUtils$isValidatIP$, (IMP*)&_logos_meta_orig$DingtoneAds$NUtils$isValidatIP$);}{ MSHookMessageEx(_logos_metaclass$DingtoneAds$NUtils, @selector(getIPAddressByCheckFormat:), (IMP)&_logos_meta_method$DingtoneAds$NUtils$getIPAddressByCheckFormat$, (IMP*)&_logos_meta_orig$DingtoneAds$NUtils$getIPAddressByCheckFormat$);}Class _logos_class$DingtoneAds$InAppPurchaseManager = objc_getClass("InAppPurchaseManager"); { MSHookMessageEx(_logos_class$DingtoneAds$InAppPurchaseManager, @selector(init), (IMP)&_logos_method$DingtoneAds$InAppPurchaseManager$init, (IMP*)&_logos_orig$DingtoneAds$InAppPurchaseManager$init);}Class _logos_class$DingtoneAds$TZIAPManager = objc_getClass("TZIAPManager"); { MSHookMessageEx(_logos_class$DingtoneAds$TZIAPManager, @selector(init), (IMP)&_logos_method$DingtoneAds$TZIAPManager$init, (IMP*)&_logos_orig$DingtoneAds$TZIAPManager$init);}Class _logos_class$DingtoneAds$TZSKPaymentManager = objc_getClass("TZSKPaymentManager"); { MSHookMessageEx(_logos_class$DingtoneAds$TZSKPaymentManager, @selector(init), (IMP)&_logos_method$DingtoneAds$TZSKPaymentManager$init, (IMP*)&_logos_orig$DingtoneAds$TZSKPaymentManager$init);}Class _logos_class$DingtoneAds$WKWebView = objc_getClass("WKWebView"); Class _logos_metaclass$DingtoneAds$WKWebView = object_getClass(_logos_class$DingtoneAds$WKWebView); { MSHookMessageEx(_logos_metaclass$DingtoneAds$WKWebView, @selector(alloc), (IMP)&_logos_meta_method$DingtoneAds$WKWebView$alloc, (IMP*)&_logos_meta_orig$DingtoneAds$WKWebView$alloc);}}
#pragma clang diagnostic pop
}
