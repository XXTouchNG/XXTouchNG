/*
 * Copyright (C) 2011 Michael Dippery <mdippery@gmail.com>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#import "NSString+Random.h"
#include <stdlib.h>

#define DEFAULT_LENGTH  8

@implementation NSString (Randomized)

+ (NSString *)LUAE_DefaultAlphabets
{
    return @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXZY0123456789";
}

+ (instancetype)LUAE_RandomizedString
{
    return [self LUAE_RandomizedStringWithAlphabets:[self LUAE_DefaultAlphabets]];
}

+ (instancetype)LUAE_RandomizedStringWithAlphabets:(NSString *)alphabets
{
    return [self LUAE_RandomizedStringWithAlphabets:alphabets length:DEFAULT_LENGTH];
}

+ (instancetype)LUAE_RandomizedStringWithAlphabets:(NSString *)alphabets length:(NSUInteger)len
{
#if !__has_feature(objc_arc)
    return [[[self alloc] initWithLUAEAlphabets:alphabets length:len] autorelease];
#else
    return [[self alloc] initWithLUAEAlphabets:alphabets length:len];
#endif
}

- (instancetype)initWithLUAEDefaultAlphabets
{
    return [self initWithLUAEAlphabets:[NSString LUAE_DefaultAlphabets]];
}

- (instancetype)initWithLUAEAlphabets:(NSString *)alphabets
{
    return [self initWithLUAEAlphabets:alphabets length:DEFAULT_LENGTH];
}

#if !__has_feature(objc_arc)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"
- (instancetype)initWithLUAEAlphabets:(NSString *)alphabet length:(NSUInteger)len
{
    [self release];
    NSMutableString *s = [NSMutableString stringWithCapacity:len];
    for (NSUInteger i = 0U; i < len; i++) {
        u_int32_t r = arc4random() % [alphabet length];
        unichar c = [alphabet characterAtIndex:r];
        [s appendFormat:@"%C", c];
    }
    return [[NSString alloc] initWithString:s];
}
#pragma clang diagnostic pop
#else
- (instancetype)initWithLUAEAlphabets:(NSString *)alphabet length:(NSUInteger)len
{
    NSMutableString *s = [NSMutableString stringWithCapacity:len];
    for (NSUInteger i = 0U; i < len; i++) {
        u_int32_t r = arc4random() % [alphabet length];
        unichar c = [alphabet characterAtIndex:r];
        [s appendFormat:@"%C", c];
    }
    return [self initWithString:s];
}
#endif

@end
