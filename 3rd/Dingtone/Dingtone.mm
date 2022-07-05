//
//  Dingtone.m
//  Dingtone
//
//  Created by Darwin on 12/21/21.
//  Copyright (c) 2021 XXTouch Team. All rights reserved.
//

#if TARGET_OS_SIMULATOR
#error Do not support the simulator, please use the real iPhone Device.
#endif

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import "TFLuaBridge.h"

#define kSharedVersion "0.1-2"
#define kSharedBundleID "me.dingtone.im"
static NSString * const kSharedInstanceName = @"com.darwindev.Dingtone";


/* ----------------------------------------------------------------------- */


@interface Contact : NSObject
- (NSString *)displayName;
@property (nonatomic) long long userId;
@end

@interface Message : NSObject
@property (retain, nonatomic) NSString *msgId;
//@property (retain, nonatomic) NSString *sentName;
//@property (retain, nonatomic) NSString *recvName;
//@property (retain, nonatomic) NSString *phoneNumber;
@property (nonatomic) unsigned long long senderType;
@property (nonatomic) long long sequenceId;
@property (retain, nonatomic) NSString *sentUserId;
@property (retain, nonatomic) NSString *text;
- (NSString *)getFormatDisplayText;
@property double timestamp;
@end

@interface ChatSession : NSObject
@property (retain, nonatomic) NSString *conversationId;
// NSString *_sessionName;
// NSString *_sessionTitle;
- (BOOL)isDisabled;
@property (nonatomic) BOOL isGroupChat;
@property (retain, nonatomic) NSMutableArray <Contact *> *buddyArray;
@property (retain, nonatomic) NSMutableArray <Message *> *msgArray;
@property (retain, nonatomic) Message *latestNotSysMsg;
@end

@interface DTChatCellData : NSObject
@property (retain, nonatomic) Message *message;
@end

@interface MessageCellData : NSObject
@property (retain, nonatomic) ChatSession *chatSession;
@end

@interface DTChatViewController : UIViewController
@property (retain, nonatomic) NSMutableArray <DTChatCellData *> *arrayCellData;
- (ChatSession *)getCurrentChatSession;
@end

@interface MessageViewController: UIViewController <UITableViewDelegate>
// NSArray <ChatSession *> *currentSessions;
@property (retain, nonatomic) NSMutableArray <MessageCellData *> *arrayCellDatas;
@property (retain, nonatomic) UITableView *tableChatView;
@end

@interface DTMyPrivatePhone : NSObject
@property (retain, nonatomic) NSString *phoneNumber;
@property (nonatomic) double expireTime;
@end

@interface DTNumbersViewController : UIViewController
@property (copy, nonatomic) NSArray <DTMyPrivatePhone *> *privatePhoneList;
@end

@interface DtNavigationController : UINavigationController
@end

@interface DTContactListViewController : UIViewController
@property (retain, nonatomic) MessageViewController *msgViewController;
@property (retain, nonatomic) DTNumbersViewController *numbersViewController;
@end


/* ----------------------------------------------------------------------- */


@implementation TFLuaBridge (Actions)

+ (id)ClientHello:(NSDictionary *)data error:(NSError **)error {
    return [[TFLuaBridge sharedInstance] localClientDoAction:@"ClientHello" userInfo:data error:error];
}

+ (id)getAccountInfoWithError:(NSError **)error {
    return [[TFLuaBridge sharedInstance] localClientDoAction:@"GetAccountInfo" userInfo:@{} error:error];
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

    else if ([actionName isEqualToString:@"GetAccountInfo"]) {
        DTContactListViewController *tabController = (DTContactListViewController *)[TFLuaBridge findViewControllerByClassName:@"DTContactListViewController"];
        DTNumbersViewController *topController = [tabController numbersViewController];
        if (topController) {
            NSArray <DTMyPrivatePhone *> *phoneList = [topController privatePhoneList];
            NSMutableArray <NSDictionary *> *retPhoneList = [NSMutableArray arrayWithCapacity:phoneList.count];
            for (DTMyPrivatePhone *phone in phoneList) {
                [retPhoneList addObject:@{
                    @"phoneNumber": phone.phoneNumber ?: @"",
                    @"expiredAt": @(phone.expireTime / 1000.0),
                }];
            }
            return @{
                @"code": @(200),
                @"msg": @"OK",
                @"data": retPhoneList,
            };
        } else {
            return @{
                @"code": @(400),
                @"msg": @"Page Not Found",
                @"data": @{},
            };
        }
    }
    
    else if ([actionName isEqualToString:@"GetConversations"]) {
        DTContactListViewController *tabController = (DTContactListViewController *)[TFLuaBridge findViewControllerByClassName:@"DTContactListViewController"];
        MessageViewController *topController = [tabController msgViewController];
        if (topController) {
            Ivar ivar = class_getInstanceVariable([topController class], "currentSessions");
            NSArray *objects = object_getIvar(topController, ivar);
            NSMutableArray <NSDictionary <NSString *, id> *> *retObjects = [NSMutableArray arrayWithCapacity:objects.count];
            for (id object in objects) {
                if (![object isKindOfClass:[objc_getClass("ChatSession") class]]) {
                    continue;
                }
                ChatSession *conversation = (ChatSession *)object;
                if ([conversation isDisabled] || [conversation isGroupChat]) {
                    continue;
                }
                Contact *contact = (Contact *)[[conversation buddyArray] lastObject];
                if (![contact isKindOfClass:[objc_getClass("Contact") class]]) {
                    continue;
                }
                Message *lastMsg = (Message *)[conversation latestNotSysMsg];
                if (![lastMsg isKindOfClass:[objc_getClass("Message") class]]) {
                    continue;
                }
                Ivar ivar = class_getInstanceVariable([conversation class], "_sessionName");
                NSString *sessionName = object_getIvar(conversation, ivar);
                NSDictionary <NSString *, id> *retObject = @{
                    @"objectIdentifier": [conversation conversationId] ?: @"",
                    @"displayString": sessionName ?: @"",
                    @"displayContactValue": [contact displayName] ?: @"",
                    @"contactValueString": [NSString stringWithFormat:@"%@", @([contact userId])],
                    @"lastMessage": [lastMsg getFormatDisplayText] ?: @"",
                    @"lastUpdatedTimestamp": @([lastMsg timestamp]),
                };
                [retObjects addObject:retObject];
            }
            [retObjects sortUsingComparator:^NSComparisonResult(NSDictionary *_Nonnull obj1, NSDictionary *_Nonnull obj2) {
                return [[obj2 objectForKey:@"lastUpdatedTimestamp"] compare:[obj1 objectForKey:@"lastUpdatedTimestamp"]];
            }];
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
        DTContactListViewController *tabController = (DTContactListViewController *)[TFLuaBridge findViewControllerByClassName:@"DTContactListViewController"];
        MessageViewController *topController = [tabController msgViewController];
        if (topController) {
            NSInteger objectIdx = NSNotFound;
            NSArray <MessageCellData *> *objects = [topController arrayCellDatas];
            for (MessageCellData *object in objects) {
                if (![object isKindOfClass:[objc_getClass("MessageCellData") class]]) {
                    continue;
                }
                MessageCellData *conversationCell = (MessageCellData *)object;
                ChatSession *conversation = [conversationCell chatSession];
                if ([[conversation conversationId] isEqualToString:objectIdentifier]) {
                    objectIdx = [objects indexOfObject:conversationCell];
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
            [topController tableView:[topController tableChatView] didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:objectIdx inSection:0]];
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
        DTContactListViewController *tabController = (DTContactListViewController *)[TFLuaBridge findViewControllerByClassName:@"DTContactListViewController"];
        DtNavigationController *topController = (DtNavigationController *)[tabController navigationController];
        if (topController) {
            [topController popToRootViewControllerAnimated:YES];
        }
        return @{
            @"code": @(200),
            @"msg": @"OK",
            @"data": @{},
        };
    }
    
    else if ([actionName isEqualToString:@"GetMessages"]) {
        DTChatViewController *topController = (DTChatViewController *)[TFLuaBridge findViewControllerByClassName:@"DTChatViewController"];
        if (topController) {
            NSString *objectIdentifier = [[topController getCurrentChatSession] conversationId];
            NSArray <DTChatCellData *> *objects = [topController arrayCellData];
            NSMutableArray <NSDictionary <NSString *, id> *> *retObjects = [NSMutableArray arrayWithCapacity:objects.count];
            for (id object in objects) {
                if (![object isKindOfClass:[objc_getClass("DTChatCellData") class]]) {
                    continue;
                }
                DTChatCellData *textMessageCell = (DTChatCellData *)object;
                Message *textMessage = [textMessageCell message];
                if (![textMessage isKindOfClass:[objc_getClass("Message") class]]) {
                    continue;
                }
                NSString *content = [textMessage text];
                NSString *displayContent = [textMessage getFormatDisplayText];
                NSMutableDictionary *retObject = [NSMutableDictionary dictionaryWithDictionary:@{
                    @"authorName": [textMessage sentUserId] ?: @"",
                    @"content": content ?: @"",
                    @"displayContent": displayContent ?: @"",
                    @"messageId": [textMessage msgId] ?: @"",
                    @"remoteTimestamp": @([textMessage timestamp]),
                    @"senderType": @([textMessage senderType]),
                    @"sequenceId": @([textMessage sequenceId]),
                }];
                NSRange guessedRange = [[self cachedCodeExp] rangeOfFirstMatchInString:content options:kNilOptions range:NSMakeRange(0, content.length)];
                if (guessedRange.location != NSNotFound) {
                    NSString *guessedCode = [content substringWithRange:guessedRange];
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
    
    return nil;
    
}

@end

CHConstructor
{
	@autoreleasepool
	{
        [TFLuaBridge setSharedInstanceName:kSharedInstanceName];
        [TFLuaBridge sharedInstance];
	}
}


/* ----------------------------------------------------------------------- */


#import "TFLuaBridge+Object.h"

static int Dingtone_Hello(lua_State *L) {
    id value = lua_toNSValuex(L, 1, 0);
    if (![value isKindOfClass:[NSDictionary class]]) {
        return luaL_argerror(L, 1, "dictionary expected");
    }
    NSError *error = nil;
    NSDictionary *ret = [TFLuaBridge ClientHello:value error:&error];
    if (!ret) {
        if ([[error domain] hasSuffix:@".RecoverableError"]) {
            lua_pushnil(L);
            lua_pushstring(L, [[NSString stringWithFormat:@"%@", error.localizedDescription] UTF8String]);
            return 2;
        }
        return luaL_error(L, [NSString stringWithFormat:@"%@", error.localizedDescription].UTF8String);
    }
    lua_pushNSValuex(L, ret, 0);
    lua_pushnil(L);
    return 2;
}

static int Dingtone_GetConversations(lua_State *L) {
    NSError *error = nil;
    NSDictionary *ret = [TFLuaBridge getConversationsWithError:&error];
    if (!ret) {
        if ([[error domain] hasSuffix:@".RecoverableError"]) {
            lua_pushnil(L);
            lua_pushstring(L, [[NSString stringWithFormat:@"%@", error.localizedDescription] UTF8String]);
            return 2;
        }
        return luaL_error(L, [NSString stringWithFormat:@"%@", error.localizedDescription].UTF8String);
    }
    lua_pushNSValuex(L, ret, 0);
    lua_pushnil(L);
    return 2;
}

static int Dingtone_EnterConversation(lua_State *L) {
    const char *objectId = luaL_checkstring(L, 1);
    NSError *error = nil;
    NSDictionary *ret = [TFLuaBridge enterConversation:[NSString stringWithUTF8String:objectId] error:&error];
    if (!ret) {
        if ([[error domain] hasSuffix:@".RecoverableError"]) {
            lua_pushnil(L);
            lua_pushstring(L, [[NSString stringWithFormat:@"%@", error.localizedDescription] UTF8String]);
            return 2;
        }
        return luaL_error(L, [NSString stringWithFormat:@"%@", error.localizedDescription].UTF8String);
    }
    lua_pushNSValuex(L, ret, 0);
    lua_pushnil(L);
    return 2;
}

static int Dingtone_ExitConversation(lua_State *L) {
    NSError *error = nil;
    NSDictionary *ret = [TFLuaBridge exitConversationWithError:&error];
    if (!ret) {
        if ([[error domain] hasSuffix:@".RecoverableError"]) {
            lua_pushboolean(L, false);
            lua_pushstring(L, [[NSString stringWithFormat:@"%@", error.localizedDescription] UTF8String]);
            return 2;
        }
        return luaL_error(L, [NSString stringWithFormat:@"%@", error.localizedDescription].UTF8String);
    }
    lua_pushboolean(L, true);
    lua_pushnil(L);
    return 2;
}

static int Dingtone_GetMessages(lua_State *L) {
    NSError *error = nil;
    NSDictionary *ret = [TFLuaBridge getMessagesWithError:&error];
    if (!ret) {
        if ([[error domain] hasSuffix:@".RecoverableError"]) {
            lua_pushnil(L);
            lua_pushstring(L, [[NSString stringWithFormat:@"%@", error.localizedDescription] UTF8String]);
            return 2;
        }
        return luaL_error(L, [NSString stringWithFormat:@"%@", error.localizedDescription].UTF8String);
    }
    lua_pushNSValuex(L, ret, 0);
    lua_pushnil(L);
    return 2;
}

static int Dingtone_GetAccountInfo(lua_State *L) {
    NSError *error = nil;
    NSDictionary *ret = [TFLuaBridge getAccountInfoWithError:&error];
    if (!ret) {
        if ([[error domain] hasSuffix:@".RecoverableError"]) {
            lua_pushnil(L);
            lua_pushstring(L, [[NSString stringWithFormat:@"%@", error.localizedDescription] UTF8String]);
            return 2;
        }
        return luaL_error(L, [NSString stringWithFormat:@"%@", error.localizedDescription].UTF8String);
    }
    lua_pushNSValuex(L, ret, 0);
    lua_pushnil(L);
    return 2;
}

static const luaL_Reg Dingtone_AuxLib[] = {
    {"Hello",              Dingtone_Hello},
    {"GetAccountInfo",     Dingtone_GetAccountInfo},
    {"GetConversations",   Dingtone_GetConversations},
    {"EnterConversation",  Dingtone_EnterConversation},
    {"ExitConversation",   Dingtone_ExitConversation},
    {"GetMessages",        Dingtone_GetMessages},
    {NULL, NULL}
};

XXTouchF_CAPI int luaopen_Dingtone(lua_State *L);
XXTouchF_CAPI int luaopen_Dingtone(lua_State *L) {
    
    [TFLuaBridge setSharedInstanceName:kSharedInstanceName];
    [TFLuaBridge sharedInstance];
    
    lua_createtable(L, 0, (sizeof(Dingtone_AuxLib) / sizeof((Dingtone_AuxLib)[0]) - 1) + 2);
    lua_pushliteral(L, kSharedVersion);
    lua_setfield(L, -2, "_VERSION");
    lua_pushliteral(L, kSharedBundleID);
    lua_setfield(L, -2, "_APP");
    luaL_setfuncs(L, Dingtone_AuxLib, 0);
    
    return 1;
    
}

