//
//  LSApplicationWorkspace.h
//  TFContainer
//
//  Created by Darwin on 7/27/20.
//

#ifndef LSApplicationWorkspace_h
#define LSApplicationWorkspace_h

#import <Foundation/Foundation.h>

@class LSApplicationProxy;

@interface LSApplicationWorkspace : NSObject
+ (LSApplicationWorkspace *)defaultWorkspace;
- (NSArray <LSApplicationProxy *> *)allApplications;
- (BOOL)openApplicationWithBundleID:(NSString *)bundleIdentifier;
- (BOOL)installApplication:(NSURL *)ipaPath withOptions:(id)arg2 error:(NSError *__autoreleasing*)error;
- (BOOL)uninstallApplication:(NSString *)bundleIdentifier withOptions:(id)arg2;
- (BOOL)invalidateIconCache:(id)arg1;
- (BOOL)openSensitiveURL:(NSURL *)url withOptions:(id)arg2 error:(NSError *__autoreleasing*)error;
@end

#endif /* LSApplicationWorkspace_h */
