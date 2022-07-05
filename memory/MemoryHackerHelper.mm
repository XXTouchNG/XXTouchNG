#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag.
#endif

#import <stdio.h>
#import <stdlib.h>
#import <string.h>
#import <assert.h>
#import <launch.h>
#import <cassert>

#import "MenesFunction.hpp"

typedef Function<void, const char *, launch_data_t> LaunchDataIterator;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
static __inline__ __attribute__((always_inline))
void launch_data_dict_iterate_custom(launch_data_t data, LaunchDataIterator code) {
    launch_data_dict_iterate(data, [](launch_data_t value, const char *name, void *baton) {
        (*static_cast<LaunchDataIterator *>(baton))(name, value);
    }, &code);
}
#pragma clang diagnostic pop

OBJC_EXTERN pid_t mh_pid_for_running_application_identifier(const char *);

pid_t mh_pid_for_running_application_identifier(const char *bid) {
    launch_data_t request = launch_data_new_string(LAUNCH_KEY_GETJOBS);
    launch_data_t response = launch_msg(request);
    launch_data_free(request);
    
    assert(response);
    assert(launch_data_get_type(response) == LAUNCH_DATA_DICTIONARY);
    
    pid_t pid = 0;
    launch_data_dict_iterate_custom(response, [=, &bid, &pid](const char *name, launch_data_t value) {
        if (pid != 0) return;
        if (launch_data_get_type(value) != LAUNCH_DATA_DICTIONARY) return;
        
        launch_data_t label = launch_data_dict_lookup(value, LAUNCH_JOBKEY_LABEL);
        if (label == NULL || launch_data_get_type(label) != LAUNCH_DATA_STRING) return;
        
        const char *identifier = launch_data_get_string(label);
        if (strncmp(identifier, "UIKitApplication:", 17) == 0) {
            const char *real = identifier + 17;
            const char *e = strchr(real, '[');
            
            if (!e) return;
            int len = (int)(e - real);
            if (strncmp(real, bid, len) != 0) return;
            
        } else if (strcmp(identifier, bid) != 0) return;
        
        launch_data_t integer = launch_data_dict_lookup(value, LAUNCH_JOBKEY_PID);
        if (integer == NULL || launch_data_get_type(integer) != LAUNCH_DATA_INTEGER) return;
        
        pid = (pid_t)launch_data_get_integer(integer);
    });
    
    return pid;
}
