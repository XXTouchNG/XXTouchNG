%group DingtoneAds

%hook DTAdFreeMgr
- (bool)isAdFreeNow:(bool)arg2 {
    %orig(arg2);
    return YES;
}
%end

%hook DTNativeAdMgr
- (bool)canDisplayAvaiableNativeAd:(int)arg2 {
    return NO;
}
%end

%hook DTSubscriptionModel
+(bool)canBuySubscription:(void *)arg2 {
    return NO;
}
- (long long)status {
    return 1;
}
%end

%hook ADCDevice
- (NSString *)collectMACAddress:(NSError **)arg2 {
    return @"02:00:00:00:00:00";
}
%end

%hook NUtils
+ (bool)isValidatIP:(id)arg2 {
    return YES;
}
+ (NSString *)getIPAddressByCheckFormat:(BOOL)validate {
    return @"192.168.100.101";
}
%end


%hook InAppPurchaseManager
- (void *)init {
    return nil;
}
%end

%hook TZIAPManager
- (void *)init {
    return nil;
}
%end

%hook TZSKPaymentManager
- (void *)init {
    return nil;
}
%end

%hook WKWebView
+ (id)alloc {
    %log; return nil;
}
%end

%end

%ctor {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    %init(DingtoneAds);
#pragma clang diagnostic pop
}
