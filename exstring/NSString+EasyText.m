//
// Created by Zheng on 2018/4/26.
// Copyright (c) 2018 Zheng. All rights reserved.
//

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import "NSString+EasyText.h"


@implementation NSString (LUAE)

- (NSUInteger)LUAE_CountOfSubstring:(NSString *)little options:(NSStringCompareOptions)options {
    NSUInteger bigLen = self.length;
    NSUInteger littleLen = little.length;
    NSUInteger cnt = 0;
    NSUInteger offset = 0;
    while (offset <= bigLen) {
        offset = [self rangeOfString:little options:options range:NSMakeRange(offset, bigLen - offset)].location;
        if (offset == NSNotFound) {
            break;
        }
        cnt++;
        offset += littleLen;
    }
    return cnt;
}

- (NSString *)LUAE_SubstringByBounds:(NSString *)leftBound :(NSString *)rightBound beginOffset:(NSUInteger)beginOffset options:(NSStringCompareOptions)options {
    
    NSRange leftLoc;
    if (leftBound == nil) {
        leftLoc = NSMakeRange(0, 0);
    } else {
        leftLoc = [self rangeOfString:leftBound options:options range:NSMakeRange(beginOffset, self.length - beginOffset)];
        if (leftLoc.location == NSNotFound) {
            return nil;
        }
    }
    
    NSRange rightLoc;
    if (rightBound == nil) {
        rightLoc = NSMakeRange(self.length, 0);
    } else {
        rightLoc = [self rangeOfString:rightBound options:options range:NSMakeRange(leftLoc.location + leftLoc.length, self.length - (leftLoc.location + leftLoc.length))];
        if (rightLoc.location == NSNotFound) {
            return nil;
        }
    }
    
    @autoreleasepool {
        NSString *subStr = [self substringWithRange:NSMakeRange(leftLoc.location + leftLoc.length, rightLoc.location - (leftLoc.location + leftLoc.length))];
        return subStr;
    }
}

- (NSString *)LUAE_SubstringByBackwardBounds:(NSString *)leftBound :(NSString *)rightBound beginOffset:(NSUInteger)beginOffset options:(NSStringCompareOptions)options {
    
    NSRange rightLoc;
    if (rightBound == nil) {
        rightLoc = NSMakeRange(self.length, 0);
    } else {
        rightLoc = [self rangeOfString:rightBound options:options range:NSMakeRange(0, self.length - beginOffset)];
        if (rightLoc.location == NSNotFound) {
            return nil;
        }
    }
    
    NSRange leftLoc;
    if (leftBound == nil) {
        leftLoc = NSMakeRange(0, 0);
    } else {
        leftLoc = [self rangeOfString:leftBound options:options range:NSMakeRange(0, rightLoc.location)];
        if (leftLoc.location == NSNotFound) {
            return nil;
        }
    }
    
    @autoreleasepool {
        NSString *subStr = [self substringWithRange:NSMakeRange(leftLoc.location + leftLoc.length, rightLoc.location - (leftLoc.location + leftLoc.length))];
        return subStr;
    }
}

- (NSString *)LUAE_StringByTrimmingAll {
    @autoreleasepool {
        return [[self componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] componentsJoinedByString:@""];
    }
}

- (NSString *)LUAE_StringByTrimmingBothBounds {
    @autoreleasepool {
        return [self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
}

- (NSString *)LUAE_StringByTrimmingLeftCharactersInSet:(NSCharacterSet *)characterSet {
    @autoreleasepool {
        NSUInteger location = 0;
        NSUInteger length = [self length];
        unichar charBuffer[length];
        [self getCharacters:charBuffer];
        for (; location < length; location++) {
            if (![characterSet characterIsMember:charBuffer[location]]) {
                break;
            }
        }
        return [self substringWithRange:NSMakeRange(location, length - location)];
    }
}

- (NSString *)LUAE_StringByTrimmingRightCharactersInSet:(NSCharacterSet *)characterSet {
    @autoreleasepool {
        NSUInteger location = 0;
        NSUInteger length = [self length];
        unichar charBuffer[length];
        [self getCharacters:charBuffer];
        for (; length > 0; length--) {
            if (![characterSet characterIsMember:charBuffer[length - 1]]) {
                break;
            }
        }
        return [self substringWithRange:NSMakeRange(location, length - location)];
    }
}

- (NSUInteger)LUAE_CountOfLines {
    NSUInteger cnt = 1;
    NSUInteger offset = 0;
    while (offset < self.length) {
        offset = [self rangeOfString:@"\n" options:0 range:NSMakeRange(offset, self.length - offset)].location;
        if (offset == NSNotFound) {
            break;
        }
        cnt++;
        offset += 1;
    }
    return cnt;
}

- (BOOL)LUAE_IsAlphabet {
    @autoreleasepool {
        if (!self.length) return NO;
        NSCharacterSet *alphabets = [NSCharacterSet letterCharacterSet];
        NSCharacterSet *inStringSet = [NSCharacterSet characterSetWithCharactersInString:self];
        return [alphabets isSupersetOfSet:inStringSet];
    }
}

- (BOOL)LUAE_IsNumeric {
    @autoreleasepool {
        if (!self.length) return NO;
        NSScanner* scan = [NSScanner scannerWithString:self];
        float val;
        return [scan scanFloat:&val] && [scan isAtEnd];
    }
}

- (BOOL)LUAE_IsDigit {
    @autoreleasepool {
        if (!self.length) return NO;
        NSCharacterSet *alphaNums = [NSCharacterSet decimalDigitCharacterSet];
        NSCharacterSet *inStringSet = [NSCharacterSet characterSetWithCharactersInString:self];
        return [alphaNums isSupersetOfSet:inStringSet];
    }
}

- (BOOL)LUAE_IsEmail {
    @autoreleasepool {
        // http://stackoverflow.com/questions/3139619/check-that-an-email-address-is-valid-on-ios
        NSString *emailRegex = @"[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,4}";
        NSPredicate *emailTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", emailRegex];
        return [emailTest evaluateWithObject:self];
    }
}

- (BOOL)LUAE_IsLink {
    @autoreleasepool {
        NSString *regex = @"https?:\\/\\/[\\S]+";
        NSPredicate *regExPredicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", regex];
        return [regExPredicate evaluateWithObject:self];
    }
}

- (BOOL)LUAE_IsChineseFirst {
    @autoreleasepool {
        if (!self.length) return NO;
        int utfCode = 0;
        void *buffer = &utfCode;
        NSRange range = NSMakeRange(0, 1);
        BOOL b = [self getBytes:buffer maxLength:2 usedLength:NULL encoding:NSUTF16LittleEndianStringEncoding options:NSStringEncodingConversionExternalRepresentation range:range remainingRange:NULL];
        return b && (utfCode >= 0x4e00 && utfCode <= 0x9fa5);
    }
}

- (BOOL)LUAE_IsUppercasedAlphabet {
    @autoreleasepool {
        if (!self.length) return NO;
        NSCharacterSet *alphabets = [NSCharacterSet uppercaseLetterCharacterSet];
        NSCharacterSet *inStringSet = [NSCharacterSet characterSetWithCharactersInString:self];
        return [alphabets isSupersetOfSet:inStringSet];
    }
}

- (BOOL)LUAE_IsLowercasedAlphabet {
    @autoreleasepool {
        if (!self.length) return NO;
        NSCharacterSet *alphabets = [NSCharacterSet lowercaseLetterCharacterSet];
        NSCharacterSet *inStringSet = [NSCharacterSet characterSetWithCharactersInString:self];
        return [alphabets isSupersetOfSet:inStringSet];
    }
}

- (NSString *)LUAE_LineAtIndex:(NSUInteger)idx {
    @autoreleasepool {
        NSArray <NSString *> *bigArr = [self componentsSeparatedByString:@"\n"];
        return bigArr[idx];
    }
}

- (NSString *)LUAE_StringByRemovingLineAtIndex:(NSUInteger)idx {
    @autoreleasepool {
        NSMutableArray <NSString *> *bigArr = [[self componentsSeparatedByString:@"\n"] mutableCopy];
        [bigArr removeObjectAtIndex:idx];
        return [bigArr componentsJoinedByString:@"\n"];
    }
}

- (NSString *)LUAE_StringByReplacingLineAtIndex:(NSUInteger)idx newContent:(NSString *)content {
    @autoreleasepool {
        NSMutableArray <NSString *> *bigArr = [[self componentsSeparatedByString:@"\n"] mutableCopy];
        [bigArr replaceObjectAtIndex:idx withObject:content];
        return [bigArr componentsJoinedByString:@"\n"];
    }
}

- (NSString *)LUAE_StringByInsertingLineAtIndex:(NSUInteger)idx newContent:(NSString *)content {
    @autoreleasepool {
        NSMutableArray <NSString *> *bigArr = [[self componentsSeparatedByString:@"\n"] mutableCopy];
        [bigArr insertObject:content atIndex:idx];
        return [bigArr componentsJoinedByString:@"\n"];
    }
}

- (NSString *)LUAE_InsertBeforeLineAtIndex:(NSUInteger)idx additionalContent:(NSString *)content {
    @autoreleasepool {
        NSMutableArray <NSString *> *bigArr = [[self componentsSeparatedByString:@"\n"] mutableCopy];
        [bigArr replaceObjectAtIndex:idx withObject:[content stringByAppendingString:bigArr[idx]]];
        return [bigArr componentsJoinedByString:@"\n"];
    }
}

- (NSString *)LUAE_InsertAfterLineAtIndex:(NSUInteger)idx additionalContent:(NSString *)content {
    @autoreleasepool {
        NSMutableArray <NSString *> *bigArr = [[self componentsSeparatedByString:@"\n"] mutableCopy];
        [bigArr replaceObjectAtIndex:idx withObject:[bigArr[idx] stringByAppendingString:content]];
        return [bigArr componentsJoinedByString:@"\n"];
    }
}

- (NSString *)LUAE_StringByRemovingEmptyLines {
    @autoreleasepool {
        NSMutableArray <NSString *> *bigArr = [[self componentsSeparatedByString:@"\n"] mutableCopy];
        NSMutableIndexSet *idxs = [[NSMutableIndexSet alloc] init];
        NSUInteger idx = 0;
        for (NSString *line in bigArr) {
            if ([line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].length == 0) {
                [idxs addIndex:idx];
            }
            idx++;
        }
        [bigArr removeObjectsAtIndexes:idxs];
        return [bigArr componentsJoinedByString:@"\n"];
    }
}

- (BOOL)LUAE_IsSubstringRepeated:(NSString *)substring options:(NSStringCompareOptions)options {
    @autoreleasepool {
        NSUInteger bigLen = self.length;
        NSUInteger littleLen = substring.length;
        NSUInteger offset = [self rangeOfString:substring options:options].location;
        if (offset == NSNotFound) {
            return NO;
        }
        offset = [self rangeOfString:substring options:options range:NSMakeRange(offset + littleLen, bigLen - (offset + littleLen))].location;
        return (offset != NSNotFound);
    }
}

- (NSUInteger)LUAE_LocationOfSubstring:(NSString *)substring beginOffset:(NSUInteger)beginOffset options:(NSStringCompareOptions)options {
    @autoreleasepool {
        return [self rangeOfString:substring options:options range:NSMakeRange(beginOffset, self.length - beginOffset)].location;
    }
}

- (NSUInteger)LUAE_LocationOfBackwardSubstring:(NSString *)substring endOffset:(NSUInteger)endOffset options:(NSStringCompareOptions)options {
    @autoreleasepool {
        return [self rangeOfString:substring options:options range:NSMakeRange(0, self.length - endOffset)].location;
    }
}

- (NSString *)LUAE_StringByF2H {
    @autoreleasepool {
        NSMutableString *convertedString = [self mutableCopy];
        CFStringTransform((__bridge CFMutableStringRef) convertedString, NULL, kCFStringTransformFullwidthHalfwidth, false);
        return [convertedString copy];
    }
}

- (NSString *)LUAE_StringByH2F {
    @autoreleasepool {
        NSMutableString *convertedString = [self mutableCopy];
        CFStringTransform((__bridge CFMutableStringRef) convertedString, NULL, kCFStringTransformFullwidthHalfwidth, true);
        return [convertedString copy];
    }
}

- (NSString *)LUAE_StringByRepeating:(NSUInteger)repeatTimes {
    @autoreleasepool {
        NSMutableString *newStr = [[NSMutableString alloc] initWithCapacity:((NSUInteger) repeatTimes * self.length)];
        for (NSUInteger i = 0; i < repeatTimes; ++i) {
            [newStr appendString:self];
        }
        return [newStr copy];
    }
}

- (NSArray <NSString *> *)LUAE_ComponentsSeparatedByString:(NSString *)littleStr maxCapacity:(NSUInteger)capacity {
    @autoreleasepool {
        NSUInteger bigLen = self.length;
        NSUInteger littleLen = littleStr.length;
        NSMutableArray <NSString *> *arr = [NSMutableArray array];
        NSUInteger offset = 0;
        NSUInteger newOffset;
        while (capacity > 0) {
            newOffset = [self rangeOfString:littleStr options:0 range:NSMakeRange(offset, bigLen - offset)].location;
            if (newOffset == NSNotFound || newOffset + littleLen >= bigLen) {
                [arr addObject:[self substringWithRange:NSMakeRange(offset, bigLen - offset)]];
                break;
            }
            [arr addObject:[self substringWithRange:NSMakeRange(offset, newOffset - offset)]];
            offset = newOffset + littleLen;
            capacity--;
        }
        return [arr copy];
    }
}

- (NSString *)LUAE_StringByPaddingTheLeftToLength:(NSUInteger)newLength withString:(NSString *)padString startingAtIndex:(NSUInteger)padIndex {
    @autoreleasepool {
        return [[@"" stringByPaddingToLength:newLength - [self length] withString:padString startingAtIndex:padIndex] stringByAppendingString:self];
    }
}

- (NSString *)LUAE_PinyinStringByRemovingAscent:(BOOL)removeAscent {
    @autoreleasepool {
        NSMutableString *bigStr = [self mutableCopy];
        CFStringTransform((__bridge CFMutableStringRef)bigStr, NULL, kCFStringTransformMandarinLatin, NO);
        if (removeAscent) {
            CFStringTransform((__bridge CFMutableStringRef)bigStr, NULL, kCFStringTransformStripCombiningMarks, NO);
        }
        return [bigStr copy];
    }
}

- (NSUInteger)LUAE_LineIndexOfSubstring:(NSString *)substring options:(NSStringCompareOptions)options {
    @autoreleasepool {
        NSArray <NSString *> *bigArr = [self componentsSeparatedByString:@"\n"];
        for (NSUInteger line = 0; line < bigArr.count; line++) {
            if ([bigArr[line] rangeOfString:substring options:options].location != NSNotFound) {
                return line;
            }
        }
        return NSNotFound;
    }
}

- (NSArray <NSString *> *)LUAE_Characters {
    @autoreleasepool {
        NSMutableArray *characters = [[NSMutableArray alloc] initWithCapacity:[self length]];
        for (NSUInteger i = 0; i < [self length]; i++) {
            NSString *ichar = [NSString stringWithFormat:@"%C", [self characterAtIndex:i]];
            [characters addObject:ichar];
        }
        return [characters copy];
    }
}

- (NSString *)LUAE_StringByRemovingRepeatedComponentsSeparatedByString:(NSString *)littleStr {
    @autoreleasepool {
        NSArray <NSString *> *bigArr = [self componentsSeparatedByString:littleStr];
        NSMutableArray <NSString *> *filteredArr = [NSMutableArray array];
        for (NSString *str in bigArr) {
            if (![filteredArr containsObject:str])
            {
                [filteredArr addObject:str];
            }
        }
        return [filteredArr componentsJoinedByString:littleStr];
    }
}

- (NSUInteger)LUAE_CountOfIdenticalLinesToLineAtIndex:(NSUInteger)idx {
    @autoreleasepool {
        NSArray <NSString *> *bigArr = [self componentsSeparatedByString:@"\n"];
        NSUInteger cnt = 0;
        NSString *littleStr = bigArr[idx];
        for (NSString *str in bigArr) {
            if ([str isEqualToString:littleStr]) {
                cnt++;
            }
        }
        return cnt;
    }
}

//- (NSIndexSet *)LUAE_IndexSetOfIdenticalLinesToLineAtIndex:(NSUInteger)idx startingAtIndex:(NSUInteger)beginIndex {
//    @autoreleasepool {
//        NSArray <NSString *> *bigArr = [self componentsSeparatedByString:@"\n"];
//        NSMutableIndexSet *idxSet = [NSMutableIndexSet indexSet];
//        NSUInteger line = beginIndex;
//        NSString *littleStr = bigArr[idx];
//        for (NSString *str in bigArr) {
//            if ([str isEqualToString:littleStr]) {
//                [idxSet addIndex:line];
//            }
//            line++;
//        }
//        return [idxSet copy];
//    }
//}

- (NSArray <NSNumber *> *)LUAE_IndexSetArrayOfIdenticalLinesToLineAtIndex:(NSUInteger)idx startingAtIndex:(NSUInteger)beginIndex {
    @autoreleasepool {
        NSArray <NSString *> *bigArr = [self componentsSeparatedByString:@"\n"];
        NSMutableArray <NSNumber *> *idxSet = [NSMutableArray array];
        NSUInteger line = beginIndex;
        NSString *littleStr = bigArr[idx];
        for (NSString *str in bigArr) {
            if ([str isEqualToString:littleStr]) {
                [idxSet addObject:@(line)];
            }
            line++;
        }
        return [idxSet copy];
    }
}

//- (NSIndexSet *)LUAE_IndexSetOfIdenticalSubstrings:(NSString *)substring startingAtIndex:(NSUInteger)beginIndex maxCapacity:(NSUInteger)capacity {
//    @autoreleasepool {
//        NSUInteger bigLen = self.length;
//        NSUInteger littleLen = substring.length;
//        NSMutableIndexSet *idxSet = [NSMutableIndexSet indexSet];
//        NSUInteger offset = 0;
//        while (capacity > 0) {
//            offset = [self rangeOfString:substring options:0 range:NSMakeRange(offset, bigLen - offset)].location;
//            if (offset == NSNotFound) {
//                break;
//            }
//            [idxSet addIndex:offset + beginIndex];
//            offset += littleLen;
//            capacity--;
//        }
//        return [idxSet copy];
//    }
//}

- (NSArray <NSNumber *> *)LUAE_IndexSetArrayOfIdenticalSubstrings:(NSString *)substring startingAtIndex:(NSUInteger)beginIndex  maxCapacity:(NSUInteger)capacity {
    @autoreleasepool {
        NSUInteger bigLen = self.length;
        NSUInteger littleLen = substring.length;
        NSMutableArray <NSNumber *> *arr = [NSMutableArray array];
        NSUInteger offset = 0;
        while (capacity > 0) {
            offset = [self rangeOfString:substring options:0 range:NSMakeRange(offset, bigLen - offset)].location;
            if (offset == NSNotFound) {
                break;
            }
            [arr addObject:@(offset + beginIndex)];
            offset += littleLen;
            capacity--;
        }
        return [arr copy];
    }
}

- (NSString *)LUAE_ReplaceSubstring:(NSString *)substring withString:(NSString *)needleString beginOffset:(NSUInteger)beginOffset replaceTimes:(NSUInteger)replaceTimes options:(NSStringCompareOptions)options {
    @autoreleasepool {
        NSUInteger bigLen = self.length;
        NSUInteger littleLen = substring.length;
        NSUInteger needleLen = needleString.length;
        NSMutableString *bigStr = [self mutableCopy];
        NSUInteger offset = beginOffset;
        while (replaceTimes > 0) {
            offset = [bigStr rangeOfString:substring options:options range:NSMakeRange(offset, bigLen - offset)].location;
            if (offset == NSNotFound) {
                break;
            }
            [bigStr replaceCharactersInRange:NSMakeRange(offset, littleLen) withString:needleString];
            offset += needleLen;
            replaceTimes--;
        }
        return [bigStr copy];
    }
}

static inline NSComparisonResult LUAE_NSComparationInt(int a, int b) {
    if (a == b) return NSOrderedSame;
    return (a > b) ? (NSOrderedDescending) : (NSOrderedAscending);
}

- (NSComparisonResult)LUAE_compareVersion:(NSString *)version {
    static NSCharacterSet *separatorSet = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        separatorSet = [NSCharacterSet characterSetWithCharactersInString:@" .-"];
    });
    @autoreleasepool {
        int digit = 0, digit_v = 0;
        NSScanner *scanner = [NSScanner scannerWithString:self];
        NSScanner *scanner_v = [NSScanner scannerWithString:version];
        BOOL scan = [scanner scanInt:&digit];
        BOOL scan_v = [scanner_v scanInt:&digit_v];
        while (scan && scan_v) {
            if (digit != digit_v) {
                break;
            }
            digit = 0; digit_v = 0;
            [scanner scanCharactersFromSet:separatorSet intoString:nil];
            [scanner_v scanCharactersFromSet:separatorSet intoString:nil];
            scan = [scanner scanInt:&digit];
            scan_v = [scanner_v scanInt:&digit_v];
        }
        return LUAE_NSComparationInt(digit, digit_v);
    }
}

@end
