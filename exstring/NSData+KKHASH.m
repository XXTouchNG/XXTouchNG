//
//  NSData+KKHASH.m
//  SecurityiOS
//
//  Created by cocoa on 16/12/15.
//  Copyright © 2016年 dev.keke@gmail.com. All rights reserved.
//

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import "NSData+KKHASH.h"
#include <CommonCrypto/CommonDigest.h>

@implementation NSData (KKHASH)

- (NSData *)LUAE_HashDataWith:(CCDIGESTAlgorithm)ccAlgorithm
{
    @autoreleasepool {
        NSData *retData = nil;
        if (self.length < 1) {
            return nil;
        }
        
        unsigned char *md;
        
        switch (ccAlgorithm) {
        case CCDIGEST_MD2:
        {
            md = malloc(CC_MD2_DIGEST_LENGTH);
            bzero(md, CC_MD2_DIGEST_LENGTH);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            CC_MD2(self.bytes, (CC_LONG)self.length, md);
#pragma clang diagnostic pop
            retData = [NSData dataWithBytes:md length:CC_MD2_DIGEST_LENGTH];
        }
        break;
        case CCDIGEST_MD4:
        {
            md = malloc(CC_MD4_DIGEST_LENGTH);
            bzero(md, CC_MD4_DIGEST_LENGTH);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            CC_MD4(self.bytes, (CC_LONG)self.length, md);
#pragma clang diagnostic pop
            retData = [NSData dataWithBytes:md length:CC_MD4_DIGEST_LENGTH];
            
        }
        break;
        case CCDIGEST_MD5:
        {
            md = malloc(CC_MD5_DIGEST_LENGTH);
            bzero(md, CC_MD5_DIGEST_LENGTH);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            CC_MD5(self.bytes, (CC_LONG)self.length, md);
#pragma clang diagnostic pop
            retData = [NSData dataWithBytes:md length:CC_MD5_DIGEST_LENGTH];
            
        }
        break;
        case CCDIGEST_SHA1:
        {
            md = malloc(CC_SHA1_DIGEST_LENGTH);
            bzero(md, CC_SHA1_DIGEST_LENGTH);
            CC_SHA1(self.bytes, (CC_LONG)self.length, md);
            retData = [NSData dataWithBytes:md length:CC_SHA1_DIGEST_LENGTH];
            
        }
        break;
        case CCDIGEST_SHA224:
        {
            md = malloc(CC_SHA224_DIGEST_LENGTH);
            bzero(md, CC_SHA224_DIGEST_LENGTH);
            CC_SHA224(self.bytes, (CC_LONG)self.length, md);
            retData = [NSData dataWithBytes:md length:CC_SHA224_DIGEST_LENGTH];
            
        }
        break;
        case CCDIGEST_SHA256:
        {
            md = malloc(CC_SHA256_DIGEST_LENGTH);
            bzero(md, CC_SHA256_DIGEST_LENGTH);
            CC_SHA256(self.bytes, (CC_LONG)self.length, md);
            retData = [NSData dataWithBytes:md length:CC_SHA256_DIGEST_LENGTH];
            
        }
        break;
        case CCDIGEST_SHA384:
        {
            md = malloc(CC_SHA384_DIGEST_LENGTH);
            bzero(md, CC_SHA384_DIGEST_LENGTH);
            CC_SHA384(self.bytes, (CC_LONG)self.length, md);
            retData = [NSData dataWithBytes:md length:CC_SHA384_DIGEST_LENGTH];
            
        }
        break;
        case CCDIGEST_SHA512:
        {
            md = malloc(CC_SHA512_DIGEST_LENGTH);
            bzero(md, CC_SHA512_DIGEST_LENGTH);
            CC_SHA512(self.bytes, (CC_LONG)self.length, md);
            retData = [NSData dataWithBytes:md length:CC_SHA512_DIGEST_LENGTH];
            
        }
        break;
            
        default:
            md = malloc(1);
            break;
        }
        
        free(md);
        md = NULL;
        
        return retData;
    }
}


- (NSString *)LUAE_HexString
{
    @autoreleasepool {
        NSMutableString *result = nil;
        if (self.length < 1) {
            return nil;
        }
        result = [[NSMutableString alloc] initWithCapacity:self.length * 2];
        for (size_t i = 0; i < self.length; i++) {
            [result appendFormat:@"%02x", ((const uint8_t *) self.bytes)[i]];
        }
        return result;
    }
}


+ (NSData *)LUAE_DataWithHexString:(NSString *)hexString {
    @autoreleasepool {
        NSMutableData *result = nil;
        NSUInteger cursor;
        NSUInteger limit;
        
        NSParameterAssert(hexString != nil);
        
        result = nil;
        cursor = 0;
        limit = hexString.length;
        if ((limit % 2) == 0) {
            result = [[NSMutableData alloc] init];
            
            while (cursor != limit) {
                @autoreleasepool {
                    unsigned int thisUInt;
                    uint8_t thisByte;
                    
                    if (sscanf([hexString substringWithRange:NSMakeRange(cursor, 2)].UTF8String, "%x", &thisUInt) != 1) {
                        result = nil;
                        break;
                    }
                    thisByte = (uint8_t) thisUInt;
                    [result appendBytes:&thisByte length:sizeof(thisByte)];
                    cursor += 2;
                }
            }
        }
        
        return result;
    }
}

@end
