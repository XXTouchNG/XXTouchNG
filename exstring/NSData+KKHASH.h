//
//  NSData+KKHASH.h
//  SecurityiOS
//
//  Created by cocoa on 16/12/15.
//  Copyright © 2016年 dev.keke@gmail.com. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum : NSUInteger {
    //md2 16字节长度
    CCDIGEST_MD2 = 1000,
    //md4 16字节长度
    CCDIGEST_MD4,
    //md5 16字节长度
    CCDIGEST_MD5,
    //sha1 20字节长度
    CCDIGEST_SHA1,
    //SHA224 28字节长度
    CCDIGEST_SHA224,
    //SHA256 32字节长度
    CCDIGEST_SHA256,
    //SHA384 48字节长度
    CCDIGEST_SHA384,
    //SHA512 64字节长度
    CCDIGEST_SHA512,
} CCDIGESTAlgorithm;

@interface NSData (KKHASH)

/**
    计算数据的hash值，根据不同的算法
 */
- (NSData *)LUAE_HashDataWith:(CCDIGESTAlgorithm )ccAlgorithm;


/**
    返回 hex string的 data
 */
- (NSString *)LUAE_HexString;
+ (NSData *)LUAE_DataWithHexString:(NSString *)hexString;

@end
