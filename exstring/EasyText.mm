//
//  EasyText.m
//  EasyText
//
//  Created by Zheng on 25/04/2018.
//  Copyright © 2018 Zheng. All rights reserved.
//

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import "EasyText.h"
#import "NSString+EasyText.h"
#import "NSData+KKHASH.h"
#import "NSData+KKAES.h"
#import "NSString+Random.h"

_ELIB_DECL(xxtouch_exstring);


#define _ERR_TENC @"cannot initialize string with UTF-8 encoding"
#define NSIDX(LIDX) ((NSUInteger)(LIDX) -1)
#define LIDX(NSIDX) (NSIDX != NSNotFound ? ((lua_Integer)(NSIDX) +1) : (-1))

#define luaE_prepstring(L, IDX) \
    const char *luae_str ## IDX = luaL_checkstring((L), (IDX));

#define luaE_preplstring(L, IDX, LEN) \
    const char *luae_str ## IDX = luaL_checklstring((L), (IDX), (LEN));

#define luaE_prepoptstring(L, IDX, DEF) \
    const char *luae_str ## IDX = luaL_optstring((L), (IDX), (DEF));

#define luaE_checknsstring(L, DEST, IDX) \
    NSString *DEST = nil; \
    _ECHK { \
        (DEST) = [NSString stringWithUTF8String:(luae_str ## IDX)]; \
        if (!(DEST)) \
        _EARG((IDX), _ERR_TENC); \
    };

#define luaE_checknsdata(L, DEST, IDX, LEN) \
    NSData *DEST = nil; \
    _ECHK { \
        (DEST) = [NSData dataWithBytesNoCopy:(void *)(luae_str ## IDX) length:(LEN) freeWhenDone:NO]; \
        if (!(DEST)) \
        _EARG((IDX), _ERR_TENC); \
    };

#define luaE_optboolean(L, IDX, DEF) \
    (BOOL)(lua_isboolean((L), (IDX)) ? lua_toboolean(L, (IDX)) : (DEF))


_EFUNC(StringByTrimmingBothBounds) {
    _EBEGIN
        _EPOOL {
        luaE_prepstring(L, 1);
        luaE_checknsstring(L, bigStr, 1);
        _ECHK {
            lua_pushNSValue(L, [bigStr LUAE_StringByTrimmingBothBounds]);
            return 1;
        };
    };
    _EEND(xxtouch_exstring)
}


_EFUNC(StringByTrimmingLeftSpaces) {
    _EBEGIN
        _EPOOL {
        luaE_prepstring(L, 1);
        luaE_checknsstring(L, bigStr, 1);
        _ECHK {
            lua_pushNSValue(L, [bigStr LUAE_StringByTrimmingLeftCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]);
            return 1;
        };
    };
    _EEND(xxtouch_exstring)
}


_EFUNC(StringByTrimmingRightSpaces) {
    _EBEGIN
        _EPOOL {
        luaE_prepstring(L, 1);
        luaE_checknsstring(L, bigStr, 1);
        _ECHK {
            lua_pushNSValue(L, [bigStr LUAE_StringByTrimmingRightCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]);
            return 1;
        };
    };
    _EEND(xxtouch_exstring)
}



_EFUNC(CapitalizedString) {
    _EBEGIN
        _EPOOL {
        luaE_prepstring(L, 1);
        luaE_checknsstring(L, bigStr, 1);
        _ECHK {
            lua_pushNSValue(L, [bigStr capitalizedString]);
            return 1;
        };
    };
    _EEND(xxtouch_exstring)
}


_EFUNC(CountOfLines) {
    _EBEGIN
        _EPOOL {
        luaE_prepstring(L, 1);
        luaE_checknsstring(L, bigStr, 1);
        _ECHK {
            lua_pushinteger(L, (lua_Integer) [bigStr LUAE_CountOfLines]);
            return 1;
        };
    };
    _EEND(xxtouch_exstring)
}


_EFUNC(IsAlphabet) {
    _EBEGIN
        _EPOOL {
        luaE_prepstring(L, 1);
        luaE_checknsstring(L, bigStr, 1);
        _ECHK {
            lua_pushboolean(L, [bigStr LUAE_IsAlphabet]);
            return 1;
        };
    };
    _EEND(xxtouch_exstring)
}


_EFUNC(IsNumeric) {
    _EBEGIN
        _EPOOL {
        luaE_prepstring(L, 1);
        luaE_checknsstring(L, bigStr, 1);
        _ECHK {
            lua_pushboolean(L, [bigStr LUAE_IsNumeric]);
            return 1;
        };
    };
    _EEND(xxtouch_exstring)
}


_EFUNC(IsDigit) {
    _EBEGIN
        _EPOOL {
        luaE_prepstring(L, 1);
        luaE_checknsstring(L, bigStr, 1);
        _ECHK {
            lua_pushboolean(L, [bigStr LUAE_IsDigit]);
            return 1;
        };
    };
    _EEND(xxtouch_exstring)
}


_EFUNC(IsEmail) {
    _EBEGIN
        _EPOOL {
        luaE_prepstring(L, 1);
        luaE_checknsstring(L, bigStr, 1);
        _ECHK {
            lua_pushboolean(L, [bigStr LUAE_IsEmail]);
            return 1;
        };
    };
    _EEND(xxtouch_exstring)
}


_EFUNC(IsLink) {
    _EBEGIN
        _EPOOL {
        luaE_prepstring(L, 1);
        luaE_checknsstring(L, bigStr, 1);
        _ECHK {
            lua_pushboolean(L, [bigStr LUAE_IsLink]);
            return 1;
        };
    };
    _EEND(xxtouch_exstring)
}


_EFUNC(IsChineseFirst) {
    _EBEGIN
        _EPOOL {
        luaE_prepstring(L, 1);
        luaE_checknsstring(L, bigStr, 1);
        _ECHK {
            lua_pushboolean(L, [bigStr LUAE_IsChineseFirst]);
            return 1;
        };
    };
    _EEND(xxtouch_exstring)
}


_EFUNC(IsUppercasedAlphabet) {
    _EBEGIN
        _EPOOL {
        luaE_prepstring(L, 1);
        luaE_checknsstring(L, bigStr, 1);
        _ECHK {
            lua_pushboolean(L, [bigStr LUAE_IsUppercasedAlphabet]);
            return 1;
        };
    };
    _EEND(xxtouch_exstring)
}


_EFUNC(IsLowercasedAlphabet) {
    _EBEGIN
        _EPOOL {
        luaE_prepstring(L, 1);
        luaE_checknsstring(L, bigStr, 1);
        _ECHK {
            lua_pushboolean(L, [bigStr LUAE_IsLowercasedAlphabet]);
            return 1;
        };
    };
    _EEND(xxtouch_exstring)
}


_EFUNC(StringByRemovingLineAtIndex) {
    _EBEGIN
        _EPOOL {
        luaE_prepstring(L, 1);
        lua_Integer lNum = luaL_checkinteger(L, 2);
        luaE_checknsstring(L, bigStr, 1);
        _ECHK {
            NSUInteger lCnt = [bigStr LUAE_CountOfLines];
            if (lNum < 1 || lNum > lCnt) {
                _EARG(2, ([NSString stringWithFormat:@"line number %lld out of range (1, %lld)", lNum, (lua_Integer) lCnt]));
            }
        };
        _ECHK {
            lua_pushNSValue(L, [bigStr LUAE_StringByRemovingLineAtIndex:NSIDX(lNum)]);
            return 1;
        };
    };
    _EEND(xxtouch_exstring)
}


_EFUNC(StringByRemovingEmptyLines) {
    _EBEGIN
        _EPOOL {
        luaE_prepstring(L, 1);
        luaE_checknsstring(L, bigStr, 1);
        _ECHK {
            lua_pushstring(L, [[bigStr LUAE_StringByRemovingEmptyLines] UTF8String]);
            return 1;
        };
    };
    _EEND(xxtouch_exstring)
}


_EFUNC(StringByTrimmingAll) {
    _EBEGIN
        _EPOOL {
        luaE_prepstring(L, 1);
        luaE_checknsstring(L, bigStr, 1);
        _ECHK {
            lua_pushNSValue(L, [bigStr LUAE_StringByTrimmingAll]);
            return 1;
        };
    };
    _EEND(xxtouch_exstring)
}


_EFUNC(StringByF2H) {
    _EBEGIN
        _EPOOL {
        luaE_prepstring(L, 1);
        luaE_checknsstring(L, bigStr, 1);
        _ECHK {
            lua_pushNSValue(L, [bigStr LUAE_StringByF2H]);
            return 1;
        };
    };
    _EEND(xxtouch_exstring)
}


_EFUNC(StringByH2F) {
    _EBEGIN
        _EPOOL {
        luaE_prepstring(L, 1);
        luaE_checknsstring(L, bigStr, 1);
        _ECHK {
            lua_pushNSValue(L, [bigStr LUAE_StringByH2F]);
            return 1;
        };
    };
    _EEND(xxtouch_exstring)
}


_EFUNC(CompareToString) {
    _EBEGIN
        _EPOOL {
        luaE_prepstring(L, 1);
        luaE_prepstring(L, 2);
        BOOL caseInsensitive = luaE_optboolean(L, 3, NO);
        luaE_checknsstring(L, bigStr, 1);
        luaE_checknsstring(L, littleStr, 2);
        _ECHK {
            NSStringCompareOptions options = 0;
            if (caseInsensitive)
                options = NSCaseInsensitiveSearch;
            NSComparisonResult result = [bigStr compare:littleStr options:options];
            if (result == NSOrderedAscending) {
                lua_pushinteger(L, -1);
            } else if (result == NSOrderedDescending) {
                lua_pushinteger(L, 1);
            } else {
                lua_pushinteger(L, 0);
            }
            return 1;
        };
    };
    _EEND(xxtouch_exstring)
}


_EFUNC(ComponentsSeparatedByString) {
    _EBEGIN
        _EPOOL {
        luaE_prepstring(L, 1);
        luaE_prepstring(L, 2);
        lua_Integer maxCapacity = luaL_optinteger(L, 3, -1);
        luaE_checknsstring(L, bigStr, 1);
        luaE_checknsstring(L, littleStr, 2);
        _ECHK {
            if (maxCapacity < 0) {
                lua_pushNSArray(L, [bigStr componentsSeparatedByString:littleStr]);
            } else {
                lua_pushNSArray(L, [bigStr LUAE_ComponentsSeparatedByString:littleStr maxCapacity:(NSUInteger) maxCapacity]);
            }
            return 1;
        };
    };
    _EEND(xxtouch_exstring)
}


_EFUNC(LineAtIndex) {
    _EBEGIN
        _EPOOL {
        luaE_prepstring(L, 1);
        lua_Integer lNum = luaL_checkinteger(L, 2);
        luaE_checknsstring(L, bigStr, 1);
        _ECHK {
            NSUInteger lCnt = [bigStr LUAE_CountOfLines];
            if (lNum < 1 || lNum > lCnt) {
                _EARG(2, ([NSString stringWithFormat:@"line number %lld out of range (1, %lld)", lNum, (lua_Integer) lCnt]));
            }
        };
        _ECHK {
            lua_pushNSValue(L, [bigStr LUAE_LineAtIndex:NSIDX(lNum)]);
            return 1;
        };
    };
    _EEND(xxtouch_exstring)
}


_EFUNC(LineIndexOfSubstring) {
    _EBEGIN
        _EPOOL {
        luaE_prepstring(L, 1);
        luaE_prepstring(L, 2);
        BOOL caseInsensitive = luaE_optboolean(L, 3, NO);
        luaE_checknsstring(L, bigStr, 1);
        luaE_checknsstring(L, littleStr, 2);
        _ECHK {
            NSStringCompareOptions options = 0;
            if (caseInsensitive) {
                options = NSCaseInsensitiveSearch;
            }
            NSUInteger loc = [bigStr LUAE_LineIndexOfSubstring:littleStr options:options];
            lua_pushinteger(L, LIDX(loc));
            return 1;
        };
    };
    _EEND(xxtouch_exstring)
}


_EFUNC(PinyinString) {
    _EBEGIN
        _EPOOL {
        luaE_prepstring(L, 1);
        BOOL removeAscent = luaE_optboolean(L, 2, NO);
        luaE_checknsstring(L, bigStr, 1);
        _ECHK {
            lua_pushNSValue(L, [bigStr LUAE_PinyinStringByRemovingAscent:removeAscent]);
            return 1;
        };
    };
    _EEND(xxtouch_exstring)
}


_EFUNC(Characters) {
    _EBEGIN
        _EPOOL {
        luaE_prepstring(L, 1);
        luaE_checknsstring(L, bigStr, 1);
        _ECHK {
            lua_pushNSArray(L, [bigStr LUAE_Characters]);
            return 1;
        };
    };
    _EEND(xxtouch_exstring)
}


_EFUNC(StringByRemovingRepeatedComponents) {
    _EBEGIN
        _EPOOL {
        luaE_prepstring(L, 1);
        luaE_prepoptstring(L, 2, "\n");
        luaE_checknsstring(L, bigStr, 1);
        luaE_checknsstring(L, littleStr, 2);
        _ECHK {
            lua_pushNSValue(L, [bigStr LUAE_StringByRemovingRepeatedComponentsSeparatedByString:littleStr]);
            return 1;
        };
    };
    _EEND(xxtouch_exstring)
}


_EFUNC(CountOfIdenticalLines) {
    _EBEGIN
        _EPOOL {
        luaE_prepstring(L, 1);
        lua_Integer lNum = luaL_checkinteger(L, 2);
        luaE_checknsstring(L, bigStr, 1);
        _ECHK {
            NSUInteger lCnt = [bigStr LUAE_CountOfLines];
            if (lNum < 1 || lNum > lCnt) {
                _EARG(2, ([NSString stringWithFormat:@"line number %lld out of range (1, %lld)", lNum, (lua_Integer) lCnt]));
            }
        };
        _ECHK {
            lua_pushinteger(L, (lua_Integer) [bigStr LUAE_CountOfIdenticalLinesToLineAtIndex:NSIDX(lNum)]);
            return 1;
        };
    };
    _EEND(xxtouch_exstring)
}


_EFUNC(IndexSetOfIdenticalLines)
{
    _EBEGIN
        _EPOOL {
        luaE_prepstring(L, 1);
        lua_Integer lNum = luaL_checkinteger(L, 2);
        luaE_checknsstring(L, bigStr, 1);
        _ECHK {
            NSUInteger lCnt = [bigStr LUAE_CountOfLines];
            if (lNum < 1 || lNum > lCnt) {
                _EARG(2, ([NSString stringWithFormat:@"line number %lld out of range (1, %lld)", lNum, (lua_Integer) lCnt]));
            }
        };
        _ECHK {
            lua_pushNSArray(L, [bigStr LUAE_IndexSetArrayOfIdenticalLinesToLineAtIndex:NSIDX(lNum) startingAtIndex:1]);
            return 1;
        };
    };
    _EEND(xxtouch_exstring)
}


_EFUNC(StringByPaddingRight) {
    _EBEGIN
        _EPOOL {
        luaE_prepstring(L, 1);
        lua_Integer lLength = luaL_checkinteger(L, 2);
        luaE_prepoptstring(L, 3, " ");
        luaE_checknsstring(L, bigStr, 1);
        _ECHK {
            if (lLength < 0) {
                _EARG(2, ([NSString stringWithFormat:@"padding length %lld less than 0", lLength]));
            }
        };
        luaE_checknsstring(L, littleStr, 3);
        _ECHK {
            if (lLength <= bigStr.length) {
                lua_pushNSValue(L, bigStr);
                return 1;
            }
            NSString *newStr = [bigStr stringByPaddingToLength:(NSUInteger)lLength withString:littleStr startingAtIndex:0];
            lua_pushNSValue(L, newStr);
            return 1;
        };
    };
    _EEND(xxtouch_exstring)
}


_EFUNC(StringByPaddingLeft) {
    _EBEGIN
        _EPOOL {
        luaE_prepstring(L, 1);
        lua_Integer lLength = luaL_checkinteger(L, 2);
        luaE_prepoptstring(L, 3, " ");
        luaE_checknsstring(L, bigStr, 1);
        _ECHK {
            if (lLength < 0) {
                _EARG(2, ([NSString stringWithFormat:@"padding length %lld less than 0", lLength]));
            }
        };
        luaE_checknsstring(L, littleStr, 3);
        _ECHK {
            if (lLength <= bigStr.length) {
                lua_pushNSValue(L, bigStr);
                return 1;
            }
            NSString *newStr = [bigStr LUAE_StringByPaddingTheLeftToLength:(NSUInteger)lLength withString:littleStr startingAtIndex:0];
            lua_pushNSValue(L, newStr);
            return 1;
        };
    };
    _EEND(xxtouch_exstring)
}


_EFUNC(ReplaceLineAtIndex) {
    _EBEGIN
        _EPOOL {
        luaE_prepstring(L, 1);
        lua_Integer lNum = luaL_checkinteger(L, 2);
        luaE_prepstring(L, 3);
        luaE_checknsstring(L, bigStr, 1);
        _ECHK {
            NSUInteger lCnt = [bigStr LUAE_CountOfLines];
            if (lNum < 1 || lNum > lCnt) {
                _EARG(2, ([NSString stringWithFormat:@"line number %lld out of range (1, %lld)", lNum, (lua_Integer) lCnt]));
            }
        };
        luaE_checknsstring(L, needleStr, 3);
        _ECHK {
            lua_pushNSValue(L, [bigStr LUAE_StringByReplacingLineAtIndex:NSIDX(lNum) newContent:needleStr]);
            return 1;
        };
    };
    _EEND(xxtouch_exstring)
}


_EFUNC(InsertStringAtIndex) {
    _EBEGIN
        _EPOOL {
        luaE_prepstring(L, 1);
        lua_Integer lOffset = luaL_checkinteger(L, 2);
        luaE_prepstring(L, 3);
        luaE_checknsstring(L, bigStr, 1);
        _ECHK {
            NSUInteger bigLen = bigStr.length;
            if (lOffset < 1 || NSIDX(lOffset) > bigLen) {
                _EARG(2, ([NSString stringWithFormat:@"inserting position %lld out of range (1, %lld)", lOffset, LIDX(bigLen)]));
            }
        };
        luaE_checknsstring(L, needleStr, 3);
        _ECHK {
            lua_pushNSValue(L, [bigStr stringByReplacingCharactersInRange:NSMakeRange(NSIDX(lOffset), 0) withString:needleStr]);
            return 1;
        };
    };
    _EEND(xxtouch_exstring)
}


_EFUNC(InsertLineAtIndex) {
    _EBEGIN
        _EPOOL {
        luaE_prepstring(L, 1);
        lua_Integer lNum = luaL_checkinteger(L, 2);
        luaE_prepstring(L, 3);
        luaE_checknsstring(L, bigStr, 1);
        _ECHK {
            NSUInteger lCnt = [bigStr LUAE_CountOfLines];
            if (lNum < 1 || lNum > lCnt + 1) { // + 1
                _EARG(2, ([NSString stringWithFormat:@"line number %lld out of range (1, %lld)", lNum, (lua_Integer) (lCnt + 1)]));
            }
        };
        luaE_checknsstring(L, needleStr, 3);
        _ECHK {
            lua_pushNSValue(L, [bigStr LUAE_StringByInsertingLineAtIndex:NSIDX(lNum) newContent:needleStr]);
            return 1;
        };
    };
    _EEND(xxtouch_exstring)
}


_EFUNC(InsertBeforeLineAtIndex) {
    _EBEGIN
        _EPOOL {
        luaE_prepstring(L, 1);
        lua_Integer lNum = luaL_checkinteger(L, 2);
        luaE_prepstring(L, 3);
        luaE_checknsstring(L, bigStr, 1);
        _ECHK {
            NSUInteger lCnt = [bigStr LUAE_CountOfLines];
            if (lNum < 1 || lNum > lCnt) {
                _EARG(2, ([NSString stringWithFormat:@"line number %lld out of range (1, %lld)", lNum, (lua_Integer) lCnt]));
            }
        };
        luaE_checknsstring(L, needleStr, 3);
        _ECHK {
            lua_pushNSValue(L, [bigStr LUAE_InsertBeforeLineAtIndex:NSIDX(lNum) additionalContent:needleStr]);
            return 1;
        };
    };
    _EEND(xxtouch_exstring)
}


_EFUNC(InsertAfterLineAtIndex) {
    _EBEGIN
        _EPOOL {
        luaE_prepstring(L, 1);
        lua_Integer lNum = luaL_checkinteger(L, 2);
        luaE_prepstring(L, 3);
        luaE_checknsstring(L, bigStr, 1);
        _ECHK {
            NSUInteger lCnt = [bigStr LUAE_CountOfLines];
            if (lNum < 1 || lNum > lCnt) {
                _EARG(2, ([NSString stringWithFormat:@"line number %lld out of range (1, %lld)", lNum, (lua_Integer) lCnt]));
            }
        };
        luaE_checknsstring(L, needleStr, 3);
        _ECHK {
            lua_pushNSValue(L, [bigStr LUAE_InsertAfterLineAtIndex:NSIDX(lNum) additionalContent:needleStr]);
            return 1;
        };
    };
    _EEND(xxtouch_exstring)
}

_EFUNC(InsertBeforeSubstring) {
    _EBEGIN
        _EPOOL {
        luaE_prepstring(L, 1);
        luaE_prepstring(L, 2);
        luaE_prepstring(L, 3);
        lua_Integer replaceTimes = luaL_optinteger(L, 4, -1);
        luaE_checknsstring(L, bigStr, 1);
        luaE_checknsstring(L, littleStr, 2);
        luaE_checknsstring(L, prefixStr, 3);
        _ECHK {
            if (littleStr.length == 0 || prefixStr.length == 0) {
                lua_pushNSValue(L, bigStr);
                return 1;
            }
            NSString *needleStr = [prefixStr stringByAppendingString:littleStr];
            if (replaceTimes < 0) {
                lua_pushstring(L, [[bigStr stringByReplacingOccurrencesOfString:littleStr withString:needleStr options:0 range:NSMakeRange(0, bigStr.length)] UTF8String]);
                return 1;
            }
            lua_pushNSValue(L, [bigStr LUAE_ReplaceSubstring:littleStr withString:needleStr beginOffset:0 replaceTimes:(NSUInteger) replaceTimes options:0]);
            return 1;
        };
    };
    _EEND(xxtouch_exstring)
}

_EFUNC(InsertAfterSubstring) {
    _EBEGIN
        _EPOOL {
        luaE_prepstring(L, 1);
        luaE_prepstring(L, 2);
        luaE_prepstring(L, 3);
        lua_Integer replaceTimes = luaL_optinteger(L, 4, -1);
        luaE_checknsstring(L, bigStr, 1);
        luaE_checknsstring(L, littleStr, 2);
        luaE_checknsstring(L, suffixStr, 3);
        _ECHK {
            if (littleStr.length == 0 || suffixStr.length == 0) {
                lua_pushNSValue(L, bigStr);
                return 1;
            }
            NSString *needleStr = [littleStr stringByAppendingString:suffixStr];
            if (replaceTimes < 0) {
                lua_pushstring(L, [[bigStr stringByReplacingOccurrencesOfString:littleStr withString:needleStr options:0 range:NSMakeRange(0, bigStr.length)] UTF8String]);
                return 1;
            }
            lua_pushNSValue(L, [bigStr LUAE_ReplaceSubstring:littleStr withString:needleStr beginOffset:0 replaceTimes:(NSUInteger) replaceTimes options:0]);
            return 1;
        };
    };
    _EEND(xxtouch_exstring)
}

_EFUNC(ToHex) {
    _EBEGIN
        _EPOOL {
        size_t len = 0;
        luaE_preplstring(L, 1, &len);
        luaE_checknsdata(L, inputData, 1, len);
        _ECHK {
            if (inputData.length == 0) {
                lua_pushstring(L, "");
                return 1;
            }
        };
        _ECHK {
            lua_pushstring(L, [[inputData LUAE_HexString] UTF8String]);
            return 1;
        };
    }
    _EEND(xxtouch_exstring)
}

_EFUNC(FromHex) {
    _EBEGIN
        _EPOOL {
        luaE_prepstring(L, 1);
        luaE_checknsstring(L, inputString, 1);
        _ECHK {
            if (inputString.length == 0) {
                lua_pushlstring(L, "", 0);
                return 1;
            }
        };
        _ECHK {
            NSData *encodedData = [NSData LUAE_DataWithHexString:inputString];
            lua_pushlstring(L, (const char *)encodedData.bytes, encodedData.length);
            return 1;
        };
    }
    _EEND(xxtouch_exstring)
}

_EFUNC(FromGBK) {
    _EBEGIN
        _EPOOL {
        size_t len = 0;
        luaE_preplstring(L, 1, &len);
        luaE_checknsdata(L, inputData, 1, len);
        _ECHK {
            if (inputData.length == 0) {
                lua_pushstring(L, "");
                return 1;
            }
        };
        _ECHK {
            NSStringEncoding enc = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
            NSString *outputString = [[NSString alloc] initWithData:inputData encoding:enc];
            lua_pushstring(L, [outputString UTF8String]);
            return 1;
        };
    }
    _EEND(xxtouch_exstring)
}

_EFUNC(Base64Encode) {
    _EBEGIN
        _EPOOL {
        size_t len = 0;
        luaE_preplstring(L, 1, &len);
        luaE_checknsdata(L, inputData, 1, len);
        _ECHK {
            if (inputData.length == 0) {
                lua_pushstring(L, "");
                return 1;
            }
        };
        _ECHK {
            NSString *encodedString = [inputData base64EncodedStringWithOptions:kNilOptions];
            lua_pushstring(L, [encodedString UTF8String]);
            return 1;
        };
    }
    _EEND(xxtouch_exstring)
}

_EFUNC(Base64Decode) {
    _EBEGIN
        _EPOOL {
        luaE_prepstring(L, 1);
        luaE_checknsstring(L, inputString, 1);
        _ECHK {
            if (inputString.length == 0) {
                lua_pushlstring(L, "", 0);
                return 1;
            }
        };
        _ECHK {
            NSData *encodedData = [[NSData alloc] initWithBase64EncodedString:inputString options:kNilOptions];
            lua_pushlstring(L, (const char *)encodedData.bytes, encodedData.length);
            return 1;
        };
    }
    _EEND(xxtouch_exstring)
}

_EFUNC(MD5) {
    _EBEGIN
        _EPOOL {
        size_t len = 0;
        luaE_preplstring(L, 1, &len);
        luaE_checknsdata(L, inputData, 1, len);
        _ECHK {
            if (inputData.length == 0) {
                lua_pushstring(L, "");
                return 1;
            }
        };
        _ECHK {
            lua_pushstring(L, [[[inputData LUAE_HashDataWith:CCDIGEST_MD5] LUAE_HexString] UTF8String]);
            return 1;
        };
    }
    _EEND(xxtouch_exstring)
}

_EFUNC(SHA1) {
    _EBEGIN
        _EPOOL {
        size_t len = 0;
        luaE_preplstring(L, 1, &len);
        luaE_checknsdata(L, inputData, 1, len);
        _ECHK {
            if (inputData.length == 0) {
                lua_pushstring(L, "");
                return 1;
            }
        };
        _ECHK {
            lua_pushstring(L, [[[inputData LUAE_HashDataWith:CCDIGEST_SHA1] LUAE_HexString] UTF8String]);
            return 1;
        };
    }
    _EEND(xxtouch_exstring)
}

_EFUNC(SHA256) {
    _EBEGIN
        _EPOOL {
        size_t len = 0;
        luaE_preplstring(L, 1, &len);
        luaE_checknsdata(L, inputData, 1, len);
        _ECHK {
            if (inputData.length == 0) {
                lua_pushstring(L, "");
                return 1;
            }
        };
        _ECHK {
            lua_pushstring(L, [[[inputData LUAE_HashDataWith:CCDIGEST_SHA256] LUAE_HexString] UTF8String]);
            return 1;
        };
    }
    _EEND(xxtouch_exstring)
}

_EFUNC(SHA512) {
    _EBEGIN
        _EPOOL {
        size_t len = 0;
        luaE_preplstring(L, 1, &len);
        luaE_checknsdata(L, inputData, 1, len);
        _ECHK {
            if (inputData.length == 0) {
                lua_pushstring(L, "");
                return 1;
            }
        };
        _ECHK {
            lua_pushstring(L, [[[inputData LUAE_HashDataWith:CCDIGEST_SHA512] LUAE_HexString] UTF8String]);
            return 1;
        };
    }
    _EEND(xxtouch_exstring)
}

_EFUNC(AES128_ECB_Encrypt) {
    _EBEGIN
        _EPOOL {
        size_t len = 0, keylen = 0;
        luaE_preplstring(L, 1, &len);
        luaE_preplstring(L, 2, &keylen);
        luaE_checknsdata(L, inputData, 1, len);
        luaE_checknsdata(L, keyData, 2, keylen);
        _ECHK {
            if (inputData.length == 0) {
                lua_pushstring(L, "");
                return 1;
            }
        };
        _ECHK {
            unsigned char *keyBuf = (unsigned char *)malloc(16);
            bzero(keyBuf, 16);
            memcpy(keyBuf, keyData.bytes, MIN(16, keyData.length));
            NSData *mKeyData = [NSData dataWithBytesNoCopy:keyBuf length:16 freeWhenDone:NO];
            NSData *outputData = [inputData LUAE_AES_ECB_EncryptWith:mKeyData];
            free(keyBuf);
            lua_pushlstring(L, (const char *)outputData.bytes, outputData.length);
            return 1;
        };
    }
    _EEND(xxtouch_exstring)
}

_EFUNC(AES128_ECB_Decrypt) {
    _EBEGIN
        _EPOOL {
        size_t len = 0, keylen = 0;
        luaE_preplstring(L, 1, &len);
        luaE_preplstring(L, 2, &keylen);
        luaE_checknsdata(L, inputData, 1, len);
        luaE_checknsdata(L, keyData, 2, keylen);
        _ECHK {
            if (inputData.length == 0) {
                lua_pushstring(L, "");
                return 1;
            }
        };
        _ECHK {
            unsigned char *keyBuf = (unsigned char *)malloc(16);
            bzero(keyBuf, 16);
            memcpy(keyBuf, keyData.bytes, MIN(16, keyData.length));
            NSData *mKeyData = [NSData dataWithBytesNoCopy:keyBuf length:16 freeWhenDone:NO];
            NSData *outputData = [inputData LUAE_AES_ECB_DecryptWith:mKeyData];
            free(keyBuf);
            lua_pushlstring(L, (const char *)outputData.bytes, outputData.length);
            return 1;
        };
    }
    _EEND(xxtouch_exstring)
}

_EFUNC(Strip_UTF8_BOM) {
    _EBEGIN
        _EPOOL {
        size_t len = 0;
        luaE_preplstring(L, 1, &len);
        luaE_checknsdata(L, inputData, 1, len);
        _ECHK {
            if (inputData.length == 0) {
                lua_pushstring(L, "");
                return 1;
            }
        };
        _ECHK {
            const unsigned char bytes[] = { 0xEF, 0xBB, 0xBF };
            NSData *bomData = [NSData dataWithBytes:bytes length:sizeof(bytes)];
            
            NSData *prefixData = [inputData subdataWithRange:NSMakeRange(0, MIN(3, inputData.length))];
            if ([prefixData isEqualToData:bomData]) {
                inputData = [inputData subdataWithRange:NSMakeRange(3, inputData.length - 3)];
            }
            
            lua_pushlstring(L, (const char *)inputData.bytes, inputData.length);
            return 1;
        };
    }
    _EEND(xxtouch_exstring)
}

_EFUNC(Random) {
    _EBEGIN
        _EPOOL {
        luaE_prepstring(L, 1);
        luaE_checknsstring(L, characterPool, 1);
        lua_Integer lNum = luaL_checkinteger(L, 2);
        _ECHK {
            if (characterPool.length == 0) {
                lua_pushstring(L, "");
                return 1;
            }
        };
        _ECHK {
            NSString *outputString = [NSString LUAE_RandomizedStringWithAlphabets:characterPool length:lNum];
            lua_pushstring(L, [outputString UTF8String]);
            return 1;
        };
    }
    _EEND(xxtouch_exstring)
}

_EFUNC(CompareVersion) {
    _EBEGIN
        _EPOOL {
        luaE_prepstring(L, 1);
        luaE_prepstring(L, 2);
        luaE_checknsstring(L, ver1, 1);
        luaE_checknsstring(L, ver2, 2);
        NSComparisonResult result = [ver1 LUAE_compareVersion:ver2];
        if (result == NSOrderedAscending) {
            lua_pushinteger(L, -1);
        } else if (result == NSOrderedDescending) {
            lua_pushinteger(L, 1);
        } else {
            lua_pushinteger(L, 0);
        }
        return 1;
    };
    _EEND(xxtouch_exstring)
}


_EFUNC(_GetVersion) {
    _EBEGIN
        _EPOOL {
        lua_pushstring(L, "0.4");
        return 1;
    };
    _EEND(xxtouch_exstring)
}


_ELIB(xxtouch_exstring) = {
    // --------
    _EREG(LuaE_InsertLineAtIndex,                    "insert_line_at"                   ),  // "插入文本行"),
    _EREG(LuaE_InsertBeforeLineAtIndex,              "prefix_line"                      ),  // "插入文本到某行前"),
    _EREG(LuaE_InsertAfterLineAtIndex,               "suffix_line"                      ),  // "插入文本到某行后"),
    _EREG(LuaE_StringByRemovingLineAtIndex,          "remove_line"                      ),  // "删除指定文本行"),
    _EREG(LuaE_StringByRemovingEmptyLines,           "remove_empty_lines"               ),  // "删除空行"),
    _EREG(LuaE_CountOfLines,                         "count_line"                       ),  // "取总行数"),
    _EREG(LuaE_IndexSetOfIdenticalLines,             "find_iline"                       ),  // "取文本行起始位置"),
    _EREG(LuaE_LineAtIndex,                          "line_at"                          ),  // "取指定文本行"),
    _EREG(LuaE_LineIndexOfSubstring,                 "line_find"                        ),  // "取文本所在行"),
    _EREG(LuaE_CountOfIdenticalLines,                "count_iline"                      ),  // "取文本行出现次数"),
    _EREG(LuaE_ReplaceLineAtIndex,                   "replace_line"                     ),  // "替换指定文本行"),
    _EREG(LuaE_StringByRemovingRepeatedComponents,   "filter_iline"                     ),  // "去重复行"),
    // --------
    _EREG(LuaE_IsNumeric,                            "is_numeric"                       ),  // "是否为数字"),
    _EREG(LuaE_IsDigit,                              "is_digit"                         ),  // "是否为整数"),
    _EREG(LuaE_IsAlphabet,                           "is_alphabet"                      ),  // "是否为字母"),
    _EREG(LuaE_IsUppercasedAlphabet,                 "is_uppercased"                    ),  // "是否为大写字母"),
    _EREG(LuaE_IsLowercasedAlphabet,                 "is_lowercased"                    ),  // "是否为小写字母"),
    _EREG(LuaE_IsChineseFirst,                       "is_chinese"                       ),  // "首字是否为汉字"),
    _EREG(LuaE_IsEmail,                              "is_email"                         ),  // "是否为邮箱"),
    _EREG(LuaE_IsLink,                               "is_link"                          ),  // "是否为链接"),
    // --------
    _EREG(LuaE_StringByH2F,                          "h2f"                              ),  // "到全角"),
    _EREG(LuaE_StringByF2H,                          "f2h"                              ),  // "到半角"),
    _EREG(LuaE_CapitalizedString,                    "to_capitalized"                   ),  // "首字母改大写"),
    _EREG(LuaE_PinyinString,                         "to_pinyin"                        ),  // "转拼音"),
    // --------
    _EREG(LuaE_CompareToString,                      "compare"                          ),  // "文本比较"),
    _EREG(LuaE_CompareVersion,                       "compare_version"                  ),  // "版本比较"),
    // --------
    _EREG(LuaE_ComponentsSeparatedByString,          "split"                            ),  // "分割文本"),
    _EREG(LuaE_Characters,                           "to_chars"                         ),  // "逐字分割"),
    // --------
    _EREG(LuaE_InsertStringAtIndex,                  "insert_at"                        ),  // "插入文本"),
    _EREG(LuaE_InsertBeforeSubstring,                "insert_before"                    ),  // "插入文本到子文本前"),
    _EREG(LuaE_InsertAfterSubstring,                 "insert_after"                     ),  // "插入文本到子文本后"),
    // --------
    _EREG(LuaE_StringByTrimmingBothBounds,           "trim"                             ),  // "删首尾空"),
    _EREG(LuaE_StringByTrimmingLeftSpaces,           "ltrim"                            ),  // "删首空"),
    _EREG(LuaE_StringByTrimmingRightSpaces,          "rtrim"                            ),  // "删尾空"),
    _EREG(LuaE_StringByTrimmingAll,                  "atrim"                            ),  // "删全部空"),
    _EREG(LuaE_StringByPaddingLeft,                  "lpad"                             ),  // "左补齐"),
    _EREG(LuaE_StringByPaddingRight,                 "rpad"                             ),  // "右补齐"),
    // --------
    _EREG(LuaE_ToHex,                                "to_hex"                           ),
    _EREG(LuaE_FromHex,                              "from_hex"                         ),
    // --------
    _EREG(LuaE_FromGBK,                              "from_gbk"                         ),
    // --------
    _EREG(LuaE_MD5,                                  "md5"                              ),
    _EREG(LuaE_SHA1,                                 "sha1"                             ),
    _EREG(LuaE_SHA256,                               "sha256"                           ),
    _EREG(LuaE_SHA512,                               "sha512"                           ),
    // --------
    _EREG(LuaE_Base64Encode,                         "base64_encode"                    ),
    _EREG(LuaE_Base64Decode,                         "base64_decode"                    ),
    // --------
    _EREG(LuaE_AES128_ECB_Encrypt,                   "aes128_encrypt"                   ),
    _EREG(LuaE_AES128_ECB_Decrypt,                   "aes128_decrypt"                   ),
    // --------
    _EREG(LuaE_Strip_UTF8_BOM,                       "strip_utf8_bom"                   ),
    // --------
    _EREG(LuaE_Random,                               "random"                           ),
    // --------
    _EREG(LuaE__GetVersion,                          "version"                          ),  // "版本"),
    // --------
    {NULL, NULL}
    // --------
};

_ELIB_API(xxtouch_exstring) {
    
    {
        lua_getglobal(L, "string");
        luaE_setelib(L, LUAE_LIB_FUNCS_xxtouch_exstring);
        lua_pop(L, 1);
    }
    
    return 0;
}
