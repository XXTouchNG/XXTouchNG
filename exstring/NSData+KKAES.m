//
//  NSData+KKAES.m
//  SecurityiOS
//
//  Created by cocoa on 16/12/15.
//  Copyright © 2016年 dev.keke@gmail.com. All rights reserved.
//

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import "NSData+KKAES.h"
#import <CommonCrypto/CommonCryptor.h>

@implementation NSData (KKAES)

- (NSData *)LUAE_AES_CBC_EncryptWith:(NSData *)key iv:(NSData *)iv
{
    @autoreleasepool {
        NSData *retData = nil;
        NSUInteger dataLength = [self length];
        size_t bufferSize = dataLength + kCCBlockSizeAES128;
        void *buffer = malloc(bufferSize);
        bzero(buffer, bufferSize);
        size_t numBytesEncrypted = 0;
        CCCryptorStatus cryptStatus = CCCrypt(kCCEncrypt, kCCAlgorithmAES,
                                              kCCOptionPKCS7Padding,
                                              key.bytes, key.length,
                                              iv.bytes,
                                              self.bytes, self.length,
                                              buffer, bufferSize,
                                              &numBytesEncrypted);
        if (cryptStatus == kCCSuccess) {
            retData = [NSData dataWithBytes:buffer length:numBytesEncrypted];
        }
        free(buffer);
        return retData;
    }
}

- (NSData *)LUAE_AES_CBC_DecryptWith:(NSData *)key iv:(NSData *)iv
{
    @autoreleasepool {
        NSData *retData = nil;
        NSUInteger dataLength = [self length];
        size_t bufferSize = dataLength + kCCBlockSizeAES128;
        void *buffer = malloc(bufferSize);
        bzero(buffer, bufferSize);
        size_t numBytesEncrypted = 0;
        CCCryptorStatus cryptStatus = CCCrypt(kCCDecrypt, kCCAlgorithmAES,
                                              kCCOptionPKCS7Padding,
                                              key.bytes, key.length,
                                              iv.bytes,
                                              self.bytes, self.length,
                                              buffer, bufferSize,
                                              &numBytesEncrypted);
        if (cryptStatus == kCCSuccess) {
            retData = [NSData dataWithBytes:buffer length:numBytesEncrypted];
        }
        free(buffer);
        return retData;
    }
}


- (NSData *)LUAE_AES_ECB_EncryptWith:(NSData *)key
{
    @autoreleasepool {
        NSData *retData = nil;
        NSUInteger dataLength = [self length];
        size_t bufferSize = dataLength + kCCBlockSizeAES128;
        void *buffer = malloc(bufferSize);
        bzero(buffer, bufferSize);
        size_t numBytesEncrypted = 0;
        CCCryptorStatus cryptStatus = CCCrypt(kCCEncrypt, kCCAlgorithmAES,
                                              kCCOptionPKCS7Padding | kCCOptionECBMode,
                                              key.bytes, key.length,
                                              NULL,
                                              self.bytes, self.length,
                                              buffer, bufferSize,
                                              &numBytesEncrypted);
        if (cryptStatus == kCCSuccess) {
            retData = [NSData dataWithBytes:buffer length:numBytesEncrypted];
        }
        free(buffer);
        return retData;
    }
}

- (NSData *)LUAE_AES_ECB_DecryptWith:(NSData *)key
{
    @autoreleasepool {
        NSData *retData = nil;
        NSUInteger dataLength = [self length];
        size_t bufferSize = dataLength + kCCBlockSizeAES128;
        void *buffer = malloc(bufferSize);
        bzero(buffer, bufferSize);
        size_t numBytesEncrypted = 0;
        CCCryptorStatus cryptStatus = CCCrypt(kCCDecrypt, kCCAlgorithmAES,
                                              kCCOptionPKCS7Padding | kCCOptionECBMode,
                                              key.bytes, key.length,
                                              NULL,
                                              self.bytes, self.length,
                                              buffer, bufferSize,
                                              &numBytesEncrypted);
        if (cryptStatus == kCCSuccess) {
            retData = [NSData dataWithBytes:buffer length:numBytesEncrypted];
        }
        free(buffer);
        return retData;
    }
}

@end
