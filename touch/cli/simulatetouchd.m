//
//  simulatetouchd.m
//  SimulateTouch
//
//  Created by Darwin on 2022/3/9.
//

#import <Foundation/Foundation.h>
#import <dlfcn.h>

#import "kern_memorystatus.h"


OBJC_EXTERN
void plugin_i_love_xxtouch(void);

__attribute__((used)) __attribute__ ((visibility("default")))
void plugin_i_love_xxtouch(void) {}

#pragma mark -

int main(int argc, char *argv[])
{
    /* increase memory usage */
    int rc;
    
    memorystatus_priority_properties_t props = {0, JETSAM_PRIORITY_CRITICAL};
    rc = memorystatus_control(MEMORYSTATUS_CMD_SET_PRIORITY_PROPERTIES, getpid(), 0, &props, sizeof(props));
    if (rc < 0) { perror ("memorystatus_control"); exit(rc); }
    
    rc = memorystatus_control(MEMORYSTATUS_CMD_SET_JETSAM_HIGH_WATER_MARK, getpid(), -1, NULL, 0);
    if (rc < 0) { perror ("memorystatus_control"); exit(rc); }
    
    rc = memorystatus_control(MEMORYSTATUS_CMD_SET_PROCESS_IS_MANAGED, getpid(), 0, NULL, 0);
    if (rc < 0) { perror ("memorystatus_control"); exit(rc); }

    rc = memorystatus_control(MEMORYSTATUS_CMD_SET_PROCESS_IS_FREEZABLE, getpid(), 0, NULL, 0);
    if (rc < 0) { perror ("memorystatus_control"); exit(rc); }
    
    CFRunLoopRun();
    return 0;
}
