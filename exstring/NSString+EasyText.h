//
// Created by Zheng on 2018/4/26.
// Copyright (c) 2018 Zheng. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (EasyText)

- (NSUInteger)LUAE_CountOfSubstring:(NSString *)little options:(NSStringCompareOptions)options;
- (NSString *)LUAE_SubstringByBounds:(NSString *)leftBound :(NSString *)rightBound beginOffset:(NSUInteger)beginOffset options:(NSStringCompareOptions)options;
- (NSString *)LUAE_SubstringByBackwardBounds:(NSString *)leftBound :(NSString *)rightBound beginOffset:(NSUInteger)beginOffset options:(NSStringCompareOptions)options;
- (NSString *)LUAE_StringByTrimmingAll;
- (NSString *)LUAE_StringByTrimmingBothBounds;
- (NSString *)LUAE_StringByTrimmingLeftCharactersInSet:(NSCharacterSet *)characterSet;
- (NSString *)LUAE_StringByTrimmingRightCharactersInSet:(NSCharacterSet *)characterSet;

- (NSUInteger)LUAE_CountOfLines;
- (NSUInteger)LUAE_CountOfIdenticalLinesToLineAtIndex:(NSUInteger)idx;
//- (NSIndexSet *)LUAE_IndexSetOfIdenticalLinesToLineAtIndex:(NSUInteger)idx startingAtIndex:(NSUInteger)beginIndex;
- (NSArray <NSNumber *> *)LUAE_IndexSetArrayOfIdenticalLinesToLineAtIndex:(NSUInteger)idx startingAtIndex:(NSUInteger)beginIndex;
//- (NSIndexSet *)LUAE_IndexSetOfIdenticalSubstrings:(NSString *)substring startingAtIndex:(NSUInteger)beginIndex maxCapacity:(NSUInteger)capacity;
- (NSArray <NSNumber *> *)LUAE_IndexSetArrayOfIdenticalSubstrings:(NSString *)substring startingAtIndex:(NSUInteger)beginIndex maxCapacity:(NSUInteger)capacity;

- (BOOL)LUAE_IsAlphabet;
- (BOOL)LUAE_IsNumeric;
- (BOOL)LUAE_IsChineseFirst;
- (BOOL)LUAE_IsUppercasedAlphabet;
- (BOOL)LUAE_IsLowercasedAlphabet;
- (BOOL)LUAE_IsDigit;
- (BOOL)LUAE_IsEmail;
- (BOOL)LUAE_IsLink;

- (NSString *)LUAE_StringByRemovingLineAtIndex:(NSUInteger)idx;
- (NSString *)LUAE_LineAtIndex:(NSUInteger)idx;
- (NSString *)LUAE_StringByReplacingLineAtIndex:(NSUInteger)idx newContent:(NSString *)content;
- (NSString *)LUAE_StringByInsertingLineAtIndex:(NSUInteger)idx newContent:(NSString *)content;
- (NSString *)LUAE_InsertBeforeLineAtIndex:(NSUInteger)idx additionalContent:(NSString *)content;
- (NSString *)LUAE_InsertAfterLineAtIndex:(NSUInteger)idx additionalContent:(NSString *)content;
- (NSString *)LUAE_StringByRemovingEmptyLines;

- (BOOL)LUAE_IsSubstringRepeated:(NSString *)substring options:(NSStringCompareOptions)options;
- (NSUInteger)LUAE_LocationOfSubstring:(NSString *)substring beginOffset:(NSUInteger)beginOffset options:(NSStringCompareOptions)options;
- (NSUInteger)LUAE_LocationOfBackwardSubstring:(NSString *)substring endOffset:(NSUInteger)beginOffset options:(NSStringCompareOptions)options;
- (NSUInteger)LUAE_LineIndexOfSubstring:(NSString *)substring options:(NSStringCompareOptions)options;

- (NSString *)LUAE_StringByF2H;
- (NSString *)LUAE_StringByH2F;
- (NSString *)LUAE_PinyinStringByRemovingAscent:(BOOL)removeAscent;
- (NSString *)LUAE_StringByRepeating:(NSUInteger)repeatTimes;

- (NSArray <NSString *> *)LUAE_ComponentsSeparatedByString:(NSString *)littleStr maxCapacity:(NSUInteger)capacity;
- (NSString *)LUAE_StringByPaddingTheLeftToLength:(NSUInteger)newLength withString:(NSString *)padString startingAtIndex:(NSUInteger)padIndex;
- (NSArray <NSString *> *)LUAE_Characters;
- (NSString *)LUAE_StringByRemovingRepeatedComponentsSeparatedByString:(NSString *)littleStr;

- (NSString *)LUAE_ReplaceSubstring:(NSString *)substring withString:(NSString *)needleString beginOffset:(NSUInteger)beginOffset replaceTimes:(NSUInteger)replaceTimes options:(NSStringCompareOptions)options;

- (NSComparisonResult)LUAE_compareVersion:(NSString *)version;

@end
