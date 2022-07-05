//
//  LSPlugInKitProxy.h
//  TFContainer
//
//  Created by Darwin on 7/27/20.
//

#ifndef LSPlugInKitProxy_h
#define LSPlugInKitProxy_h

#import <Foundation/Foundation.h>

@interface LSPlugInKitProxy : NSObject
+ (LSPlugInKitProxy *)pluginKitProxyForIdentifier:(NSString *)bundleIdentifier;
- (NSString *)pluginIdentifier;
- (NSURL *)dataContainerURL;
- (NSURL *)bundleContainerURL;  // not used
@end

#endif /* LSPlugInKitProxy_h */
