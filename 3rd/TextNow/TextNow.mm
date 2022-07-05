//
//  TextNow.m
//  TextNow
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

#import <CoreData/CoreData.h>
#import "TFLuaBridge.h"


/* ----------------------------------------------------------------------- */


@interface TUINavigationController : UINavigationController
@end

@interface TUIHomeViewController: UIViewController
@property (retain, nonatomic) NSFetchedResultsController *fetchedResultsController;
@property (retain, nonatomic) UITableView *conversationTableView;
@property (retain) NSObject <UITableViewDelegate> *tableViewDelegate;
@end

@interface TMOOneOnOneConversation: NSManagedObject
- (BOOL)isAppInbox;
- (BOOL)isAnnouncement;
- (BOOL)isSponsored;
- (BOOL)isUnknown;
- (BOOL)isCallable;
- (BOOL)isBroadcast;
- (BOOL)isGroup;
- (BOOL)isDisabled;
- (BOOL)isHidden;
- (BOOL)isVisibleConversation;
- (BOOL)isBlocked;
- (NSString *)displayString;
- (NSString *)displayContactValue;
- (NSArray *)members;
- (NSArray <NSString *> *)contactNames;
- (NSString *)objectIdentifier;
@property (readonly, nonatomic) NSString *contactValueString;
@property (retain, nonatomic) NSDate *lastUpdatedTimestamp;
@end

@interface ConversationViewController: UIViewController
@property (nonatomic, retain) id conversationModel;
@end

@interface SectionedConversationViewModel : NSObject
- (NSString *)objectIdentifier;
@end

@interface TMOTextMessage : NSManagedObject
- (NSString *)activityStatusString;
- (NSString *)statusString;
@property (retain, nonatomic) NSString *authorName; // @dynamic authorName;
@property (retain, nonatomic) NSString *content; // @dynamic content;
@property (retain, nonatomic) NSNumber *messageId; // @dynamic messageId;
@property (retain, nonatomic) NSDate *remoteTimestamp; // @dynamic remoteTimestamp;
@property (retain, nonatomic) NSNumber *status; // @dynamic status;
@end

@interface TUIFlyOutViewController : UIViewController
@property (retain, nonatomic) UILabel *phoneNumberLabel;
@property (retain, nonatomic) UILabel *numberLabel;
@end

@interface TMOAccountInfo : NSObject
@property (retain, nonatomic) NSString *email;
@property (retain, nonatomic) NSNumber *emailVerified;
@property (retain, nonatomic) NSString *phoneNumber;
@end

@interface TNTAccountInfoManager : NSObject
+ (TNTAccountInfoManager *)sharedInstance;
- (TMOAccountInfo *)latestAccountInfo;
@end


/* ----------------------------------------------------------------------- */


@implementation TFLuaBridge (Actions)

+ (id)clientHello:(NSDictionary *)data error:(NSError **)error {
    return [[TFLuaBridge sharedInstance] localClientDoAction:@"ClientHello" userInfo:data error:error];
}

+ (id)getConversationsWithError:(NSError **)error {
    return [[TFLuaBridge sharedInstance] localClientDoAction:@"GetConversations" userInfo:@{} error:error];
}

+ (id)enterConversation:(NSString *)objectIdentifier error:(NSError **)error {
    return [[TFLuaBridge sharedInstance] localClientDoAction:@"EnterConversation" userInfo:@{ @"objectIdentifier": objectIdentifier } error:error];
}

+ (id)exitConversationWithError:(NSError **)error {
    return [[TFLuaBridge sharedInstance] localClientDoAction:@"ExitConversation" userInfo:@{} error:error];
}

+ (id)getMessagesWithError:(NSError **)error {
    return [[TFLuaBridge sharedInstance] localClientDoAction:@"GetMessages" userInfo:@{} error:error];
}

+ (id)getAccountInfoWithError:(NSError **)error {
    return [[TFLuaBridge sharedInstance] localClientDoAction:@"GetAccountInfo" userInfo:@{} error:error];
}

- (NSRegularExpression *)cachedCodeExp {
    __strong static NSRegularExpression *regex = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        regex = [NSRegularExpression regularExpressionWithPattern:@"\\d{4,6}(?!\\d)" options:kNilOptions error:nil];
    });
    return regex;
}

- (NSDictionary *)handleRemoteActionWithRequest:(NSDictionary *)request {
    
    NSString *actionName = request[@"action"];
    
    if ([actionName isEqualToString:@"ClientHello"]) {
        NSDictionary *data = request[@"data"];
        return @{
            @"code": @(200),
            @"msg": @"Hello",
            @"data": data,
        };
    }
    
    else if ([actionName isEqualToString:@"GetConversations"]) {
        TUIHomeViewController *topController = (TUIHomeViewController *)[TFLuaBridge findViewControllerByClassName:@"TUIHomeViewController"];
        if (topController) {
            NSArray <NSManagedObject *> *objects = topController.fetchedResultsController.fetchedObjects;
            NSMutableArray <NSDictionary <NSString *, id> *> *retObjects = [NSMutableArray arrayWithCapacity:objects.count];
            for (NSManagedObject *object in objects) {
                if (![object isKindOfClass:[objc_getClass("TMOOneOnOneConversation") class]]) {
                    continue;
                }
                TMOOneOnOneConversation *conversation = (TMOOneOnOneConversation *)object;
                if ([conversation isDisabled] || [conversation isHidden] || [conversation isBlocked]) {
                    continue;
                }
                else if (![conversation isVisibleConversation]) {
                    continue;
                }
                else if ([conversation isAnnouncement] || [conversation isSponsored] || [conversation isBroadcast]) {
                    continue;
                }
                else if ([conversation isGroup]) {
                    continue;
                }
                NSDictionary <NSString *, id> *retObject = @{
                    @"objectIdentifier": [conversation objectIdentifier] ?: @"",
                    @"displayString": [conversation displayString] ?: @"",
                    @"displayContactValue": [conversation displayContactValue] ?: @"",
                    @"contactValueString": [conversation contactValueString] ?: @"",
                    @"lastUpdatedTimestamp": @([[conversation lastUpdatedTimestamp] timeIntervalSince1970]),
                };
                [retObjects addObject:retObject];
            }
            return @{
                @"code": @(200),
                @"msg": @"OK",
                @"data": retObjects,
            };
        } else {
            return @{
                @"code": @(400),
                @"msg": @"Page Not Found",
                @"data": @[],
            };
        }
    }
    
    else if ([actionName isEqualToString:@"EnterConversation"]) {
        NSString *objectIdentifier = request[@"data"][@"objectIdentifier"];
        TUIHomeViewController *topController = (TUIHomeViewController *)[TFLuaBridge findViewControllerByClassName:@"TUIHomeViewController"];
        if (topController) {
            NSInteger objectIdx = NSNotFound;
            NSArray <NSManagedObject *> *objects = topController.fetchedResultsController.fetchedObjects;
            for (NSManagedObject *object in objects) {
                if (![object isKindOfClass:[objc_getClass("TMOOneOnOneConversation") class]]) {
                    continue;
                }
                TMOOneOnOneConversation *conversation = (TMOOneOnOneConversation *)object;
                if ([conversation.objectIdentifier isEqualToString:objectIdentifier]) {
                    objectIdx = [objects indexOfObject:conversation];
                    break;
                }
            }
            if (objectIdx == NSNotFound) {
                return @{
                    @"code": @(404),
                    @"msg": @"Item Not Found",
                    @"data": @{
                            @"objectIdentifier": objectIdentifier,
                    },
                };
            }
            [[topController tableViewDelegate] tableView:[topController conversationTableView] didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:objectIdx inSection:0]];
            return @{
                @"code": @(200),
                @"msg": @"OK",
                @"data": @{
                        @"objectIdentifier": objectIdentifier,
                },
            };
        } else {
            return @{
                @"code": @(400),
                @"msg": @"Page Not Found",
                @"data": @{},
            };
        }
    }
    
    else if ([actionName isEqualToString:@"ExitConversation"]) {
        TUINavigationController *topController = (TUINavigationController *)[TFLuaBridge findViewControllerByClassName:@"TUINavigationController"];
        [topController popToRootViewControllerAnimated:YES];
        return @{
            @"code": @(200),
            @"msg": @"OK",
            @"data": @{},
        };
    }
    
    else if ([actionName isEqualToString:@"GetMessages"]) {
        ConversationViewController *topController = (ConversationViewController *)[TFLuaBridge findViewControllerByClassName:@"TextNowSwift.ConversationViewController"];
        if (topController) {
            SectionedConversationViewModel *conversationModel = [topController conversationModel];
            NSString *objectIdentifier = [conversationModel objectIdentifier];
            NSFetchedResultsController *interactionsFRC = CHIvar(conversationModel, interactionsFRC, __strong NSFetchedResultsController *);
            
            NSArray <NSManagedObject *> *objects = interactionsFRC.fetchedObjects;
            NSMutableArray <NSDictionary <NSString *, id> *> *retObjects = [NSMutableArray arrayWithCapacity:objects.count];
            for (NSManagedObject *object in objects) {
                if (![object isKindOfClass:[objc_getClass("TMOTextMessage") class]]) {
                    continue;
                }
                TMOTextMessage *textMessage = (TMOTextMessage *)object;
                if ([[textMessage status] intValue] != 2) {  // Received messages only
                    continue;
                }
                NSMutableDictionary *retObject = [NSMutableDictionary dictionaryWithDictionary:@{
                    @"authorName": [textMessage authorName] ?: @"",
                    @"content": [textMessage content] ?: @"",
                    @"messageId": [textMessage messageId] ?: @"",
                    @"remoteTimestamp": @([[textMessage remoteTimestamp] timeIntervalSince1970]),
                }];
                NSRange guessedRange = [[self cachedCodeExp] rangeOfFirstMatchInString:textMessage.content options:kNilOptions range:NSMakeRange(0, textMessage.content.length)];
                if (guessedRange.location != NSNotFound) {
                    NSString *guessedCode = [[textMessage content] substringWithRange:guessedRange];
                    if (guessedCode.length >= 4) {
                        retObject[@"guessedCode"] = guessedCode;
                    }
                }
                [retObjects addObject:retObject];
            }
            return @{
                @"code": @(200),
                @"msg": @"OK",
                @"data": @{
                        @"objectIdentifier": objectIdentifier ?: @"",
                        @"fetchedMessages": retObjects,
                }
            };
        } else {
            return @{
                @"code": @(400),
                @"msg": @"Page Not Found",
                @"data": @{},
            };
        }
    }
    
    else if ([actionName isEqualToString:@"GetAccountInfo"]) {
//        TUIFlyOutViewController *topController = (TUIFlyOutViewController *)[self findViewControllerByClassName:@"TUIFlyOutViewController"];
//        if (topController) {
//            return @{
//                @"code": @(200),
//                @"msg": @"OK",
//                @"data": @{
//                        @"phoneNumber": topController.phoneNumberLabel.text ?: @"",
//                        @"number": topController.numberLabel.text ?: @"",
//                }
//            };
//        } else {
//            return @{
//                @"code": @(400),
//                @"msg": @"Page Not Found",
//                @"data": @{},
//            };
//        }
        TMOAccountInfo *accountInfo = [[objc_getClass("TNTAccountInfoManager") sharedInstance] latestAccountInfo];
        if (accountInfo) {
            return @{
                @"code": @(200),
                @"msg": @"OK",
                @"data": @{
                    @"email": accountInfo.email ?: @"",
                    @"emailVerified": @([accountInfo.emailVerified boolValue]),
                    @"phoneNumber": accountInfo.phoneNumber ?: @"",
                }
            };
        } else {
            return @{
                @"code": @(400),
                @"msg": @"Page Not Found",
                @"data": @{},
            };
        }
    }
    
    return nil;
    
}

@end

CHConstructor
{
	@autoreleasepool
	{
        [TFLuaBridge setSharedInstanceName:@"com.darwindev.TextNow"];
        [TFLuaBridge sharedInstance];
	}
}


/* ----------------------------------------------------------------------- */


#import "TFLuaBridge+Object.h"

static int TextNow_Hello(lua_State *L) {
    id value = lua_toNSValuex(L, 1, 0);
    if (![value isKindOfClass:[NSDictionary class]]) {
        return luaL_argerror(L, 1, "dictionary expected");
    }
    NSError *error = nil;
    NSDictionary *ret = [TFLuaBridge clientHello:value error:&error];
    if (!ret) {
        return luaL_error(L, [NSString stringWithFormat:@"%@", error.localizedDescription].UTF8String);
    }
    lua_pushNSValuex(L, ret, 0);
    return 1;
}

static int TextNow_GetConversations(lua_State *L) {
    NSError *error = nil;
    NSDictionary *ret = [TFLuaBridge getConversationsWithError:&error];
    if (!ret) {
        return luaL_error(L, [NSString stringWithFormat:@"%@", error.localizedDescription].UTF8String);
    }
    lua_pushNSValuex(L, ret, 0);
    return 1;
}

static int TextNow_EnterConversation(lua_State *L) {
    const char *objectId = luaL_checkstring(L, 1);
    NSError *error = nil;
    NSDictionary *ret = [TFLuaBridge enterConversation:[NSString stringWithUTF8String:objectId] error:&error];
    if (!ret) {
        return luaL_error(L, [NSString stringWithFormat:@"%@", error.localizedDescription].UTF8String);
    }
    lua_pushNSValuex(L, ret, 0);
    return 1;
}

static int TextNow_ExitConversation(lua_State *L) {
    NSError *error = nil;
    NSDictionary *ret = [TFLuaBridge exitConversationWithError:&error];
    if (!ret) {
        return luaL_error(L, [NSString stringWithFormat:@"%@", error.localizedDescription].UTF8String);
    }
    lua_pushboolean(L, true);
    return 1;
}

static int TextNow_GetMessages(lua_State *L) {
    NSError *error = nil;
    NSDictionary *ret = [TFLuaBridge getMessagesWithError:&error];
    if (!ret) {
        return luaL_error(L, [NSString stringWithFormat:@"%@", error.localizedDescription].UTF8String);
    }
    lua_pushNSValuex(L, ret, 0);
    return 1;
}

static int TextNow_GetAccountInfo(lua_State *L) {
    NSError *error = nil;
    NSDictionary *ret = [TFLuaBridge getAccountInfoWithError:&error];
    if (!ret) {
        return luaL_error(L, [NSString stringWithFormat:@"%@", error.localizedDescription].UTF8String);
    }
    lua_pushNSValuex(L, ret, 0);
    return 1;
}

static const luaL_Reg TextNow_AuxLib[] = {
    {"Hello",              TextNow_Hello},
    {"GetAccountInfo",     TextNow_GetAccountInfo},
    {"GetConversations",   TextNow_GetConversations},
    {"EnterConversation",  TextNow_EnterConversation},
    {"ExitConversation",   TextNow_ExitConversation},
    {"GetMessages",        TextNow_GetMessages},
    {NULL, NULL}
};

XXTouchF_CAPI int luaopen_TextNow(lua_State *L);
XXTouchF_CAPI int luaopen_TextNow(lua_State *L) {
    
    [TFLuaBridge setSharedInstanceName:@"com.darwindev.TextNow"];
    [TFLuaBridge sharedInstance];
    
    lua_createtable(L, 0, (sizeof(TextNow_AuxLib) / sizeof((TextNow_AuxLib)[0]) - 1) + 2);
    lua_pushliteral(L, "0.1-2");
    lua_setfield(L, -2, "_VERSION");
    lua_pushliteral(L, "com.tinginteractive.usms");
    lua_setfield(L, -2, "_APP");
    luaL_setfuncs(L, TextNow_AuxLib, 0);
    
    return 1;
    
}

