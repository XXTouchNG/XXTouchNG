#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import "NSData+Stringify.h"

@implementation NSData (Stringify)

- (NSString *)xxte_toIPv4Address {
    const unsigned char *bytes = (const unsigned char *)[self bytes];
    return [NSString stringWithFormat:@"%d.%d.%d.%d", bytes[0], bytes[1], bytes[2], bytes[3]];
}

- (NSString *)xxte_toMACAddress {
    const unsigned char *bytes = (const unsigned char *)[self bytes];
    return [NSString stringWithFormat:@"%02x:%02x:%02x:%02x:%02x:%02x", bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5]];
}

- (NSString *)xxte_toUDIDString {
    const unsigned char *bytes = (const unsigned char *)[self bytes];
    return [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15],
            bytes[16], bytes[17], bytes[18], bytes[19]];
}

- (NSString *)xxte_toHexString {
    NSMutableString *hex = [[NSMutableString alloc] init];
    const unsigned char *bytes = (const unsigned char *)[self bytes];
    NSUInteger len = self.length;
    for (NSUInteger i = 0; i < len; i++) {
        [hex appendFormat:@"%02x", bytes[i]];
    }
    return [hex copy];
}

@end
