//
//  CashApp.m
//  CashApp
//
//  Created by Darwin on 9/24/20.
//  Copyright (c) 2020 XXTouch Team. All rights reserved.
//

#if TARGET_OS_SIMULATOR
#error Do not support the simulator, please use the real iPhone Device.
#endif

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import <dlfcn.h>
#import <pthread.h>

#import "TFLuaBridge.h"


/* ----------------------------------------------------------------------- */


@class CCMoney;
@class CCPerson;
@class CCProfileAlias;
@class _TtC10Primitives7Cashtag;
@class CCSession;
@class CCAccountProfileManager;
@class SQPBCommonLocationGlobalAddress;
@class SQPBFranklinCommonIssuedCard;
@class SQPBFranklinCommonDirectDepositAccount;
@class SQPBFranklinApiInstrument;

@class CCPaymentContainer;
@class CCHistoryPayment;
@class CCPayment;
@class CCPerson;

@interface CCProfileAlias : NSObject
@property (readonly, nonatomic) NSString *displayText;
@property (nonatomic) BOOL verified; // @synthesize verified=_verified;
@end

@interface CCMoney : NSObject
@property (readonly, nonatomic) NSDecimalNumber *dollarAmount;
@end

@interface CCPerson : NSObject
@property (readonly, copy, nonatomic) _TtC10Primitives7Cashtag *cashtag; // @synthesize cashtag=_cashtag;
@property (readonly, copy, nonatomic) NSSet *emailAddresses;
@property (readonly, copy, nonatomic) NSSet *phoneNumbers;
@property (readonly, copy, nonatomic) NSString *displayName;
@end

@interface _TtC10Primitives7Cashtag : NSObject
@property (nonatomic, readonly) NSString *displayString;
@property (nonatomic, readonly) NSString *prefix;
@property (nonatomic, readonly) NSString *rootString;
@end

@interface CCAccountProfileManager : NSObject
@property (copy, nonatomic) NSArray <CCProfileAlias *> *aliases; // @synthesize aliases=_aliases;
@property (readonly, copy, nonatomic) _TtC10Primitives7Cashtag *cashtag; // @synthesize cashtag=_cashtag;
@property (copy, nonatomic) NSURL *cashtagURL;
@property (readonly, copy, nonatomic) CCMoney *totalStoredBalance;
@property (copy, nonatomic) SQPBFranklinApiInstrument *storedBalanceInstrument;
@property (copy, nonatomic) SQPBFranklinCommonIssuedCard *issuedCard;
@property (copy, nonatomic) SQPBCommonLocationGlobalAddress *postalAddress; // @synthesize postalAddress=_postalAddress;
- (NSDate *)dateLoaded;
@end

@interface SQPBFranklinCommonIssuedCard : NSObject
@property (nonatomic) BOOL activated;
@property (nonatomic) BOOL emergency;
@property (nonatomic) BOOL enabled;
@property (nonatomic) BOOL locked;
@property (copy, nonatomic) NSString *pan;
@property (copy, nonatomic) NSString *cardholderName;
@property (copy, nonatomic) NSString *expiration;
@property (copy, nonatomic) NSString *securityCode;
@end

@interface SQPBFranklinCommonDirectDepositAccount : NSObject
@property (copy, nonatomic) NSString *accountNumber; // @dynamic accountNumber;
@property (copy, nonatomic) NSString *accountNumberPrefix; // @dynamic accountNumberPrefix;
@property (copy, nonatomic) NSString *ddaExplanationText; // @dynamic ddaExplanationText;
@property (copy, nonatomic) NSString *routingNumber; // @dynamic routingNumber;
@end

@interface SQPBFranklinApiInstrument : NSObject
@property (readonly, nonatomic) CCMoney *storedBalance;
@end

@interface CCPaymentContainer : NSObject
@property (retain) CCHistoryPayment *payment;
@property (retain, nonatomic) CCPerson *recipient; // @synthesize recipient=_recipient;
@property (retain, nonatomic) CCPerson *sender; // @synthesize sender=_sender;
@property (readonly, nonatomic) NSDate *displayDate;
@property (readonly, nonatomic) NSString *identifier;
@end

@interface CCHistoryPayment : NSObject
@property (nonatomic, readonly) CCPayment *legacyPayment;
@end

@interface CCPayment : NSObject
@property (readonly, nonatomic) int paymentState; // @synthesize paymentState=_paymentState;
@property (readonly, nonatomic) long long paymentType; // @synthesize paymentType=_paymentType;
@property (readonly, copy, nonatomic) CCMoney *amount; // @synthesize amount=_amount;
@property (readonly, nonatomic) NSDate *createdAt; // @synthesize createdAt=_createdAt;
@property (readonly, copy, nonatomic) NSString *paymentIdString;
@end

@interface SQPBCommonLocationGlobalAddress : NSObject
- (id)JSONRepresentation;
@end

@interface CCSessionManager : NSObject
+ (CCSessionManager *)defaultManager;
- (id)directDepositAccountForSession:(id)arg1;
@end


/* ----------------------------------------------------------------------- */


static CCSession *kSession = nil;
static CCAccountProfileManager *kAccountProfileManager = nil;
static SQPBFranklinCommonDirectDepositAccount *kDirectDepositAccount = nil;

static NSMutableDictionary <NSString *, CCPaymentContainer *> *kAllPayments = nil;
static pthread_rwlock_t kAllPaymentsLock;


/* ----------------------------------------------------------------------- */


@implementation TFLuaBridge (Actions)

+ (id)ClientHello:(NSDictionary *)data error:(NSError **)error {
    return [[TFLuaBridge sharedInstance] localClientDoAction:@"ClientHello" userInfo:data error:error];
}

+ (id)getAliasesWithError:(NSError **)error {
    return [[TFLuaBridge sharedInstance] localClientDoAction:@"GetAliases" userInfo:@{} error:error];
}

+ (id)getAddressWithError:(NSError **)error {
    return [[TFLuaBridge sharedInstance] localClientDoAction:@"GetAddress" userInfo:@{} error:error];
}

+ (id)getBalanceWithError:(NSError **)error {
    return [[TFLuaBridge sharedInstance] localClientDoAction:@"GetBalance" userInfo:@{} error:error];
}

+ (id)getCashTagWithError:(NSError **)error {
    return [[TFLuaBridge sharedInstance] localClientDoAction:@"GetCashTag" userInfo:@{} error:error];
}

+ (id)getLoadedAtWithError:(NSError **)error {
    return [[TFLuaBridge sharedInstance] localClientDoAction:@"GetLoadedAt" userInfo:@{} error:error];
}

+ (id)getIssuedCardWithError:(NSError **)error {
    return [[TFLuaBridge sharedInstance] localClientDoAction:@"GetIssuedCard" userInfo:@{} error:error];
}

+ (id)getDirectDepositAccountWithError:(NSError **)error {
    return [[TFLuaBridge sharedInstance] localClientDoAction:@"GetDirectDepositAccount" userInfo:@{} error:error];
}

+ (id)getTransactionsWithError:(NSError **)error {
    return [[TFLuaBridge sharedInstance] localClientDoAction:@"GetTransactions" userInfo:@{} error:error];
}

+ (id)updateProfileWithError:(NSError **)error {
    return [[TFLuaBridge sharedInstance] localClientDoAction:@"UpdateProfile" userInfo:@{} error:error];
}

- (NSDictionary *)handleRemoteActionWithRequest:(NSDictionary *)request {
    
    NSString *actionName = request[@"action"];
    
    if ([actionName isEqualToString:@"ClientHello"]) {
        NSMutableDictionary *data = [request[@"data"] mutableCopy];
        data[@"session"] = [[TFLuaBridge sharedInstance] sessionID] ?: @"";
        return @{
            @"code": @(200),
            @"msg": @"Hello",
            @"data": data,
        };
    }
    
    else if ([actionName isEqualToString:@"GetAliases"]) {
        if (kAccountProfileManager.aliases) {
            NSMutableArray <NSString *> *aliases = [[NSMutableArray alloc] initWithCapacity:kAccountProfileManager.aliases.count];
            for (CCProfileAlias *alias in kAccountProfileManager.aliases) {
                if (![alias isKindOfClass:NSClassFromString(@"CCProfileAlias")]) {
                    continue;
                }
                if (!alias.displayText) {
                    continue;
                }
                [aliases addObject:alias.displayText];
            }
            return @{
                @"code": @(200),
                @"msg": @"OK",
                @"data": @{
                        @"aliases": aliases
                }
            };
        } else {
            return @{
                @"code": @(500),
                @"msg": @"Not Ready",
                @"data": @{},
            };
        }
    }
    
    else if ([actionName isEqualToString:@"GetAddress"]) {
        if (kAccountProfileManager.postalAddress) {
            return @{
                @"code": @(200),
                @"msg": @"OK",
                @"data": [kAccountProfileManager.postalAddress JSONRepresentation] ?: @{},
            };
        } else {
            return @{
                @"code": @(500),
                @"msg": @"Not Ready",
                @"data": @{},
            };
        }
    }
    
    else if ([actionName isEqualToString:@"GetBalance"]) {
        if (kAccountProfileManager.storedBalanceInstrument.storedBalance) {
            return @{
                @"code": @(200),
                @"msg": @"OK",
                @"data": @{
                        @"balance": kAccountProfileManager.storedBalanceInstrument.storedBalance.dollarAmount ?: @(0),
                },
            };
        } else {
            return @{
                @"code": @(500),
                @"msg": @"Not Ready",
                @"data": @{},
            };
        }
    }
    
    else if ([actionName isEqualToString:@"GetCashTag"]) {
        if (kAccountProfileManager.cashtag) {
            return @{
                @"code": @(200),
                @"msg": @"OK",
                @"data": @{
                        @"cashtag": kAccountProfileManager.cashtag.displayString ?: @"",
                },
            };
        } else {
            return @{
                @"code": @(500),
                @"msg": @"Not Ready",
                @"data": @{},
            };
        }
    }
    
    else if ([actionName isEqualToString:@"GetLoadedAt"]) {
        if (kAccountProfileManager.dateLoaded) {
            return @{
                @"code": @(200),
                @"msg": @"OK",
                @"data": @{
                        @"timestamp": @([kAccountProfileManager.dateLoaded timeIntervalSince1970]),
                },
            };
        } else {
            return @{
                @"code": @(500),
                @"msg": @"Not Ready",
                @"data": @{},
            };
        }
    }
    
    else if ([actionName isEqualToString:@"GetIssuedCard"]) {
        if (kAccountProfileManager.issuedCard) {
            return @{
                @"code": @(200),
                @"msg": @"OK",
                @"data": @{
                        @"activated":       @(kAccountProfileManager.issuedCard.activated),
                        @"emergency":       @(kAccountProfileManager.issuedCard.emergency),
                        @"enabled":         @(kAccountProfileManager.issuedCard.enabled),
                        @"locked":          @(kAccountProfileManager.issuedCard.locked),
                        @"pan":             kAccountProfileManager.issuedCard.pan ?: @"",
                        @"cardholderName":  kAccountProfileManager.issuedCard.cardholderName ?: @"",
                        @"expiration":      kAccountProfileManager.issuedCard.expiration ?: @"",
                        @"securityCode":    kAccountProfileManager.issuedCard.securityCode ?: @"",
                },
            };
        } else {
            return @{
                @"code": @(500),
                @"msg": @"Not Ready",
                @"data": @{},
            };
        }
    }
    
    else if ([actionName isEqualToString:@"GetDirectDepositAccount"]) {
        if (kDirectDepositAccount) {
            return @{
                @"code": @(200),
                @"msg": @"OK",
                @"data": @{
                        @"accountNumber":        kDirectDepositAccount.accountNumber ?: @"",
                        @"accountNumberPrefix":  kDirectDepositAccount.accountNumberPrefix ?: @"",
                        @"ddaExplanationText":   kDirectDepositAccount.ddaExplanationText ?: @"",
                        @"routingNumber":        kDirectDepositAccount.routingNumber ?: @"",
                },
            };
        } else {
            return @{
                @"code": @(500),
                @"msg": @"Not Ready",
                @"data": @{},
            };
        }
    }
    
    else if ([actionName isEqualToString:@"GetTransactions"]) {
        pthread_rwlock_rdlock(&kAllPaymentsLock);
        NSMutableArray <NSDictionary *> *serializedPayments = [[NSMutableArray alloc] initWithCapacity:kAllPayments.count];
        for (CCPaymentContainer *container in [kAllPayments.allValues sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"displayDate" ascending:NO selector:@selector(compare:)]]])
        {
            if (!container.sender || !container.recipient) {
                continue;
            }
            NSDictionary *serializedPayment = @{
                @"sender": @{
                        @"displayName":   container.sender.displayName ?: @"",
                        @"cashtag":       container.sender.cashtag.displayString ?: @"",
                        @"emailAddress":  container.sender.emailAddresses.anyObject ?: @"",
                        @"phoneNumber":   container.sender.phoneNumbers.anyObject ?: @"",
                },
                @"recipient": @{
                        @"displayName":   container.recipient.displayName ?: @"",
                        @"cashtag":       container.recipient.cashtag.displayString ?: @"",
                        @"emailAddress":  container.recipient.emailAddresses.anyObject ?: @"",
                        @"phoneNumber":   container.recipient.phoneNumbers.anyObject ?: @"",
                },
                @"amount":         container.payment.legacyPayment.amount.dollarAmount ?: @(0),
                @"createdAt":      @([container.payment.legacyPayment.createdAt timeIntervalSince1970]),
                @"paymentState":   @(container.payment.legacyPayment.paymentState),
                @"paymentType":    @(container.payment.legacyPayment.paymentType),
                @"paymentId":      container.identifier ?: @"",
            };
            [serializedPayments addObject:serializedPayment];
        }
        pthread_rwlock_unlock(&kAllPaymentsLock);
        return @{
            @"code": @(200),
            @"msg": @"OK",
            @"data": @{
                    @"transactions": serializedPayments
            },
        };
    }
    
    else if ([actionName isEqualToString:@"UpdateProfile"]) {
        UIApplication *application = [UIApplication sharedApplication];
        [application.delegate applicationWillResignActive:application];
        [application.delegate applicationDidEnterBackground:application];
        [application.delegate applicationWillEnterForeground:application];
        [application.delegate applicationDidBecomeActive:application];
        return @{
            @"code": @(200),
            @"msg": @"OK",
            @"data": @{},
        };
    }
    
    return nil;
    
}

@end


/* ----------------------------------------------------------------------- */


static CCAccountProfileManager *(*original_CCAccountProfileManager_initWithSession_plistRepresentation_logger_)(CCAccountProfileManager *self, SEL _cmd, CCSession *arg2, id arg3, id arg4);
static CCAccountProfileManager *replaced_CCAccountProfileManager_initWithSession_plistRepresentation_logger_(CCAccountProfileManager *self, SEL _cmd, CCSession *arg2, id arg3, id arg4)
{
    kSession = arg2;
    kAccountProfileManager = self;
    return original_CCAccountProfileManager_initWithSession_plistRepresentation_logger_(self, _cmd, arg2, arg3, arg4);
}
static SQPBFranklinCommonDirectDepositAccount *(*original_CCAccountProfileManager_directDepositAccount)(CCAccountProfileManager *self, SEL _cmd);
static SQPBFranklinCommonDirectDepositAccount *replaced_CCAccountProfileManager_directDepositAccount(CCAccountProfileManager *self, SEL _cmd)
{
    SQPBFranklinCommonDirectDepositAccount *account = original_CCAccountProfileManager_directDepositAccount(self, _cmd);
    kDirectDepositAccount = account;
    return account;
}
static id (*original_CCPaymentContainer_init)(CCPaymentContainer *self, SEL _cmd);
static id replaced_CCPaymentContainer_init(CCPaymentContainer *self, SEL _cmd)
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        int lock_state = pthread_rwlock_init(&kAllPaymentsLock, NULL);
        assert(lock_state == 0);
        kAllPayments = [[NSMutableDictionary alloc] init];
    });
    return original_CCPaymentContainer_init(self, _cmd);
}
static id (*original_CCPaymentContainer_initWithOfflineTransferFundsRequest_paymentHistoryDataFactory_personManager_)(CCPaymentContainer *self, SEL _cmd, id arg1, id arg2, id arg3);
static id replaced_CCPaymentContainer_initWithOfflineTransferFundsRequest_paymentHistoryDataFactory_personManager_(CCPaymentContainer *self, SEL _cmd, id arg1, id arg2, id arg3)
{
    id ret = original_CCPaymentContainer_initWithOfflineTransferFundsRequest_paymentHistoryDataFactory_personManager_(self, _cmd, arg1, arg2, arg3);
    if ([self.identifier isKindOfClass:[NSString class]]) {
        pthread_rwlock_wrlock(&kAllPaymentsLock);
        [kAllPayments setObject:self forKey:self.identifier];
        pthread_rwlock_unlock(&kAllPaymentsLock);
    }
    return ret;
}
static id (*original_CCPaymentContainer_initWithOfflinePaymentRequest_paymentHistoryDataFactory_personManager_)(CCPaymentContainer *self, SEL _cmd, id arg1, id arg2, id arg3);
static id replaced_CCPaymentContainer_initWithOfflinePaymentRequest_paymentHistoryDataFactory_personManager_(CCPaymentContainer *self, SEL _cmd, id arg1, id arg2, id arg3)
{
    id ret = original_CCPaymentContainer_initWithOfflinePaymentRequest_paymentHistoryDataFactory_personManager_(self, _cmd, arg1, arg2, arg3);
    if ([self.identifier isKindOfClass:[NSString class]]) {
        pthread_rwlock_wrlock(&kAllPaymentsLock);
        [kAllPayments setObject:self forKey:self.identifier];
        pthread_rwlock_unlock(&kAllPaymentsLock);
    }
    return ret;
}
static id (*original_CCPaymentContainer_initWithPBPayment_sender_recipient_personManager_hasBadge_isOutstanding_isScheduled_receiptRenderData_paymentHistoryDataFactory_paymentHistoryRenderer_)(CCPaymentContainer *self, SEL _cmd, id arg1, id arg2, id arg3, id arg4, _Bool arg5, _Bool arg6, _Bool arg7, id arg8, id arg9, id arg10);
static id replaced_CCPaymentContainer_initWithPBPayment_sender_recipient_personManager_hasBadge_isOutstanding_isScheduled_receiptRenderData_paymentHistoryDataFactory_paymentHistoryRenderer_(CCPaymentContainer *self, SEL _cmd, id arg1, id arg2, id arg3, id arg4, _Bool arg5, _Bool arg6, _Bool arg7, id arg8, id arg9, id arg10)
{
    id ret = original_CCPaymentContainer_initWithPBPayment_sender_recipient_personManager_hasBadge_isOutstanding_isScheduled_receiptRenderData_paymentHistoryDataFactory_paymentHistoryRenderer_(self, _cmd, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10);
    if ([self.identifier isKindOfClass:[NSString class]]) {
        pthread_rwlock_wrlock(&kAllPaymentsLock);
        [kAllPayments setObject:self forKey:self.identifier];
        pthread_rwlock_unlock(&kAllPaymentsLock);
    }
    return ret;
}
static id (*original_CCPaymentContainer_initWithPayment_)(CCPaymentContainer *self, SEL _cmd, id arg1);
static id replaced_CCPaymentContainer_initWithPayment_(CCPaymentContainer *self, SEL _cmd, id arg1)
{
    id ret = original_CCPaymentContainer_initWithPayment_(self, _cmd, arg1);
    if ([self.identifier isKindOfClass:[NSString class]]) {
        pthread_rwlock_wrlock(&kAllPaymentsLock);
        [kAllPayments setObject:self forKey:self.identifier];
        pthread_rwlock_unlock(&kAllPaymentsLock);
    }
    return ret;
}
static id (*original_CCPaymentContainer_initWithPaymentID_childContainers_compositePaymentHistoryRenderer_)(CCPaymentContainer *self, SEL _cmd, id arg1, id arg2, id arg3);
static id replaced_CCPaymentContainer_initWithPaymentID_childContainers_compositePaymentHistoryRenderer_(CCPaymentContainer *self, SEL _cmd, id arg1, id arg2, id arg3)
{
    id ret = original_CCPaymentContainer_initWithPaymentID_childContainers_compositePaymentHistoryRenderer_(self, _cmd, arg1, arg2, arg3);
    if ([self.identifier isKindOfClass:[NSString class]]) {
        pthread_rwlock_wrlock(&kAllPaymentsLock);
        [kAllPayments setObject:self forKey:self.identifier];
        pthread_rwlock_unlock(&kAllPaymentsLock);
    }
    return ret;
}

CHConstructor
{
	@autoreleasepool
	{
        [TFLuaBridge setSharedInstanceName:@"com.darwindev.CashApp"];
        [TFLuaBridge sharedInstance];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
        MSHookMessageEx(objc_getClass("CCAccountProfileManager"), @selector(initWithSession:plistRepresentation:logger:), (IMP)&replaced_CCAccountProfileManager_initWithSession_plistRepresentation_logger_, (IMP *)&original_CCAccountProfileManager_initWithSession_plistRepresentation_logger_);
        MSHookMessageEx(objc_getClass("CCAccountProfileManager"), @selector(directDepositAccount), (IMP)&replaced_CCAccountProfileManager_directDepositAccount, (IMP *)&original_CCAccountProfileManager_directDepositAccount);
        MSHookMessageEx(objc_getClass("CCPaymentContainer"), @selector(_init), (IMP)&replaced_CCPaymentContainer_init, (IMP *)&original_CCPaymentContainer_init);
        MSHookMessageEx(objc_getClass("CCPaymentContainer"), @selector(initWithOfflineTransferFundsRequest:paymentHistoryDataFactory:personManager:), (IMP)&replaced_CCPaymentContainer_initWithOfflineTransferFundsRequest_paymentHistoryDataFactory_personManager_, (IMP *)&original_CCPaymentContainer_initWithOfflineTransferFundsRequest_paymentHistoryDataFactory_personManager_);
        MSHookMessageEx(objc_getClass("CCPaymentContainer"), @selector(initWithOfflinePaymentRequest:paymentHistoryDataFactory:personManager:), (IMP)&replaced_CCPaymentContainer_initWithOfflinePaymentRequest_paymentHistoryDataFactory_personManager_, (IMP *)&original_CCPaymentContainer_initWithOfflinePaymentRequest_paymentHistoryDataFactory_personManager_);
        MSHookMessageEx(objc_getClass("CCPaymentContainer"), @selector(initWithPBPayment:sender:recipient:personManager:hasBadge:isOutstanding:isScheduled:receiptRenderData:paymentHistoryDataFactory:paymentHistoryRenderer:), (IMP)&replaced_CCPaymentContainer_initWithPBPayment_sender_recipient_personManager_hasBadge_isOutstanding_isScheduled_receiptRenderData_paymentHistoryDataFactory_paymentHistoryRenderer_, (IMP *)&original_CCPaymentContainer_initWithPBPayment_sender_recipient_personManager_hasBadge_isOutstanding_isScheduled_receiptRenderData_paymentHistoryDataFactory_paymentHistoryRenderer_);
        MSHookMessageEx(objc_getClass("CCPaymentContainer"), @selector(initWithPayment:), (IMP)&replaced_CCPaymentContainer_initWithPayment_, (IMP *)&original_CCPaymentContainer_initWithPayment_);
        MSHookMessageEx(objc_getClass("CCPaymentContainer"), @selector(initWithPaymentID:childContainers:compositePaymentHistoryRenderer:), (IMP)&replaced_CCPaymentContainer_initWithPaymentID_childContainers_compositePaymentHistoryRenderer_, (IMP *)&original_CCPaymentContainer_initWithPaymentID_childContainers_compositePaymentHistoryRenderer_);
#pragma clang diagnostic pop
	}
}


/* ----------------------------------------------------------------------- */


#import "TFLuaBridge+Object.h"

static int CashApp_Hello(lua_State *L) {
    id value = lua_toNSValuex(L, 1, 0);
    if (![value isKindOfClass:[NSDictionary class]]) {
        return luaL_argerror(L, 1, "dictionary expected");
    }
    NSError *error = nil;
    NSDictionary *ret = [TFLuaBridge ClientHello:value error:&error];
    if (!ret) {
        return luaL_error(L, [NSString stringWithFormat:@"%@", error.localizedDescription].UTF8String);
    }
    lua_pushNSValuex(L, ret, 0);
    return 1;
}

static int CashApp_GetAliases(lua_State *L) {
    NSError *error = nil;
    NSDictionary *ret = [TFLuaBridge getAliasesWithError:&error];
    if (!ret[@"aliases"]) {
        return luaL_error(L, [NSString stringWithFormat:@"%@", error.localizedDescription].UTF8String);
    }
    lua_pushNSValuex(L, ret[@"aliases"], 0);
    return 1;
}

static int CashApp_GetAddress(lua_State *L) {
    NSError *error = nil;
    NSDictionary *ret = [TFLuaBridge getAddressWithError:&error];
    if (!ret) {
        return luaL_error(L, [NSString stringWithFormat:@"%@", error.localizedDescription].UTF8String);
    }
    lua_pushNSValuex(L, ret, 0);
    return 1;
}

static int CashApp_GetBalance(lua_State *L) {
    NSError *error = nil;
    NSDictionary *ret = [TFLuaBridge getBalanceWithError:&error];
    if (!ret[@"balance"]) {
        return luaL_error(L, [NSString stringWithFormat:@"%@", error.localizedDescription].UTF8String);
    }
    lua_pushNSValuex(L, ret[@"balance"], 0);
    return 1;
}

static int CashApp_GetCashTag(lua_State *L) {
    NSError *error = nil;
    NSDictionary *ret = [TFLuaBridge getCashTagWithError:&error];
    if (!ret[@"cashtag"]) {
        return luaL_error(L, [NSString stringWithFormat:@"%@", error.localizedDescription].UTF8String);
    }
    lua_pushNSValuex(L, ret[@"cashtag"], 0);
    return 1;
}

static int CashApp_GetLoadedAt(lua_State *L) {
    NSError *error = nil;
    NSDictionary *ret = [TFLuaBridge getLoadedAtWithError:&error];
    if (!ret[@"timestamp"]) {
        return luaL_error(L, [NSString stringWithFormat:@"%@", error.localizedDescription].UTF8String);
    }
    lua_pushNSValuex(L, ret[@"timestamp"], 0);
    return 1;
}

static int CashApp_GetIssuedCard(lua_State *L) {
    NSError *error = nil;
    NSDictionary *ret = [TFLuaBridge getIssuedCardWithError:&error];
    if (!ret) {
        return luaL_error(L, [NSString stringWithFormat:@"%@", error.localizedDescription].UTF8String);
    }
    lua_pushNSValuex(L, ret, 0);
    return 1;
}

static int CashApp_GetDirectDepositAccount(lua_State *L) {
    NSError *error = nil;
    NSDictionary *ret = [TFLuaBridge getDirectDepositAccountWithError:&error];
    if (!ret) {
        return luaL_error(L, [NSString stringWithFormat:@"%@", error.localizedDescription].UTF8String);
    }
    lua_pushNSValuex(L, ret, 0);
    return 1;
}

static int CashApp_GetTransactions(lua_State *L) {
    NSError *error = nil;
    NSDictionary *ret = [TFLuaBridge getTransactionsWithError:&error];
    if (!ret[@"transactions"]) {
        return luaL_error(L, [NSString stringWithFormat:@"%@", error.localizedDescription].UTF8String);
    }
    lua_pushNSValuex(L, ret[@"transactions"], 0);
    return 1;
}

static int CashApp_UpdateProfile(lua_State *L) {
    NSError *error = nil;
    NSDictionary *ret = [TFLuaBridge updateProfileWithError:&error];
    if (!ret) {
        return luaL_error(L, [NSString stringWithFormat:@"%@", error.localizedDescription].UTF8String);
    }
    return 0;
}

static const luaL_Reg CashApp_AuxLib[] = {
    {"Hello",                    CashApp_Hello},
    {"GetAddress",               CashApp_GetAddress},
    {"GetAliases",               CashApp_GetAliases},
    {"GetBalance",               CashApp_GetBalance},
    {"GetCashTag",               CashApp_GetCashTag},
    {"GetLoadedAt",              CashApp_GetLoadedAt},
    {"GetIssuedCard",            CashApp_GetIssuedCard},
    {"GetDirectDepositAccount",  CashApp_GetDirectDepositAccount},
    {"GetTransactions",          CashApp_GetTransactions},
    {"UpdateProfile",            CashApp_UpdateProfile},
    {NULL, NULL}
};


XXTouchF_CAPI int luaopen_CashApp(lua_State *L);
XXTouchF_CAPI int luaopen_CashApp(lua_State *L) {
    
    [TFLuaBridge setSharedInstanceName:@"com.darwindev.CashApp"];
    [TFLuaBridge sharedInstance];
    
    lua_createtable(L, 0, (sizeof(CashApp_AuxLib) / sizeof((CashApp_AuxLib)[0]) - 1) + 2);
    lua_pushliteral(L, "0.1-2");
    lua_setfield(L, -2, "_VERSION");
    lua_pushliteral(L, "com.squareup.cash");
    lua_setfield(L, -2, "_APP");
    luaL_setfuncs(L, CashApp_AuxLib, 0);
    
    return 1;
    
}

