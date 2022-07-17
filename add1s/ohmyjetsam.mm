#import <Foundation/Foundation.h>

OBJC_EXTERN
void plugin_i_love_xxtouch(void);
void plugin_i_love_xxtouch(void) {}


#pragma mark -

int main(int argc, char *argv[]) {
    @autoreleasepool {

        static NSFileManager *fileManager = [NSFileManager defaultManager];
        static NSString *launchDaemonRoot = @"/System/Library/LaunchDaemons";

        static NSDictionary <NSString *, NSDictionary *> *migrateDict = @{
            @"ch.xxtou.tfcontainermanagerd": @{
                @"ExecuteAllowed": @(YES),
                @"EnablePressuredExit": @(NO),
                @"JetsamPriority": @(14),
                @"ActiveSoftMemoryLimit": @(36),
                @"InactiveHardMemoryLimit": @(36),
                @"ThreadLimit": @(32),
            },
            @"ch.xxtou.authpolicyd": @{
                @"ExecuteAllowed": @(YES),
                @"EnablePressuredExit": @(NO),
                @"JetsamPriority": @(14),
                @"ActiveSoftMemoryLimit": @(36),
                @"InactiveHardMemoryLimit": @(36),
                @"ThreadLimit": @(32),
            },
            @"ch.xxtou.simulatetouchd": @{
                @"ExecuteAllowed": @(YES),
                @"EnablePressuredExit": @(NO),
                @"JetsamPriority": @(17),
                @"ActiveSoftMemoryLimit": @(12),
                @"InactiveHardMemoryLimit": @(12),
                @"ThreadLimit": @(32),
            },
            @"ch.xxtou.procqueued": @{
                @"ExecuteAllowed": @(YES),
                @"EnablePressuredExit": @(NO),
                @"JetsamPriority": @(14),
                @"ActiveSoftMemoryLimit": @(36),
                @"InactiveHardMemoryLimit": @(36),
                @"ThreadLimit": @(32),
            },
            @"ch.xxtou.supervisord": @{
                @"ExecuteAllowed": @(YES),
                @"EnablePressuredExit": @(NO),
                @"JetsamPriority": @(21),
                @"ActiveSoftMemoryLimit": @(1536),
                @"InactiveHardMemoryLimit": @(1536),
                @"ThreadLimit": @(512),
            },
            @"ch.xxtou.webserv": @{
                @"ExecuteAllowed": @(YES),
                @"EnablePressuredExit": @(NO),
                @"JetsamPriority": @(14),
                @"ActiveSoftMemoryLimit": @(36),
                @"InactiveHardMemoryLimit": @(12),
                @"ThreadLimit": @(32),
            },
            @"ch.xxtou.elfclient": @{
                @"ExecuteAllowed": @(YES),
                @"EnablePressuredExit": @(NO),
                @"JetsamPriority": @(14),
                @"ActiveSoftMemoryLimit": @(36),
                @"InactiveHardMemoryLimit": @(12),
                @"ThreadLimit": @(32),
            },
        };

        NSError *err = nil;
        NSArray <NSString *> *daemonItemNames = [fileManager contentsOfDirectoryAtPath:launchDaemonRoot error:&err];
        for (NSString *daemonItemName in daemonItemNames) {
            if (![daemonItemName hasPrefix:@"com.apple.jetsamproperties."] || ![daemonItemName hasSuffix:@".plist"]) {
                continue;
            }

            NSString *daemonItemPath = [launchDaemonRoot stringByAppendingPathComponent:daemonItemName];
            NSMutableDictionary *daemonItemDict = [NSMutableDictionary dictionaryWithContentsOfFile:daemonItemPath];
            if (!daemonItemDict) {
                continue;
            }

            NSMutableDictionary *version4Dict = [daemonItemDict[@"Version4"] mutableCopy];
            if (!version4Dict) {
                continue;
            }

            NSMutableDictionary *version4DaemonDict = [version4Dict[@"Daemon"] mutableCopy];
            if (!version4DaemonDict) {
                continue;
            }

            NSMutableDictionary *version4DaemonDefaultDict = [version4DaemonDict[@"Default"] mutableCopy];
            if (!version4DaemonDefaultDict) {
                continue;
            }

            NSMutableDictionary *version4DaemonOverrideDict = [version4DaemonDict[@"Override"] mutableCopy];
            if (!version4DaemonOverrideDict) {
                continue;
            }

            for (NSString *key in migrateDict) {
                NSDictionary *migrateDictItem = migrateDict[key];
                version4DaemonDefaultDict[key] = migrateDictItem;
                version4DaemonOverrideDict[key] = migrateDictItem;
            }

            version4DaemonDict[@"Default"] = version4DaemonDefaultDict;
            version4DaemonDict[@"Override"] = version4DaemonOverrideDict;

            version4Dict[@"Daemon"] = version4DaemonDict;
            daemonItemDict[@"Version4"] = version4Dict;

            #if DEBUG
            daemonItemPath = [[daemonItemPath stringByDeletingPathExtension] stringByAppendingPathExtension:@"plist.debug"];
            #endif

            NSData *plistData = [NSPropertyListSerialization dataWithPropertyList:daemonItemDict format:NSPropertyListBinaryFormat_v1_0 options:0 error:&err];

            BOOL didWrite = [plistData writeToFile:daemonItemPath options:NSDataWritingAtomic error:&err];
            if (!didWrite) {
                fprintf(stderr, "ohmyjetsam: failed to write to %s\n", daemonItemPath.UTF8String);
            }
        }

        fprintf(stderr, "ohmyjetsam: done\n");
        return EXIT_SUCCESS;
    }
}
