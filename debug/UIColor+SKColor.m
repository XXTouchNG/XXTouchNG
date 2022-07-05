//
//  UIColor+SKColor.m
//  XXTExplorer
//
//  Created by Zheng on 19/08/2017.
//  Copyright © 2017 Zheng. All rights reserved.
//

#import "UIColor+SKColor.h"

@implementation UIColor (Hex)

+ (UIColor *)xxte_colorWithHex:(NSString *)representation {
    NSString *hex = representation;
    if ([hex hasPrefix:@"#"]) {
        hex = [hex substringFromIndex:1];
    } else if ([hex hasPrefix:@"0x"]) {
        hex = [hex substringFromIndex:2];
    }
    NSUInteger length = hex.length;
    if (length != 3 && length != 6 && length != 8)
        return nil;
    if (length == 3) {
        NSString *r = [hex substringWithRange:NSMakeRange(0, 1)];
        NSString *g = [hex substringWithRange:NSMakeRange(1, 1)];
        NSString *b = [hex substringWithRange:NSMakeRange(2, 1)];
        hex = [NSString stringWithFormat:@"%@%@%@%@%@%@ff", r, r, g, g, b, b];
    } else if (length == 6) {
        hex = [NSString stringWithFormat:@"%@ff", hex];
    }
    NSScanner *scanner = [NSScanner scannerWithString:hex];
    unsigned int rgbaValue = 0;
    [scanner scanHexInt:&rgbaValue];
    return [self colorWithRed:((rgbaValue & 0xFF000000) >> 24) / 255.f
                        green:((rgbaValue & 0xFF0000) >> 16) / 255.f
                         blue:((rgbaValue & 0xFF00) >> 8) / 255.f
                        alpha:((rgbaValue & 0xFF)) / 255.f];
}

@end
