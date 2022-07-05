#ifndef JST_COLOR_h
#define JST_COLOR_h

#import <stdint.h>

typedef union JST_COLOR JST_COLOR;

#define JST_COLOR_COMPONENT_TYPE uint8_t
#define JST_COLOR_TYPE uint32_t
#define JST_COLOR_COMPONENTS_PER_ELEMENT 4
#define JST_COLOR_COMPONENT_MAX_VALUE 0xFF

/* Color Struct */
union JST_COLOR {
    JST_COLOR_TYPE theColor; /* theColor is name of color value */
    struct { /* RGB struct */
        JST_COLOR_COMPONENT_TYPE blue;
        JST_COLOR_COMPONENT_TYPE green;
        JST_COLOR_COMPONENT_TYPE red;
        JST_COLOR_COMPONENT_TYPE alpha;
    };
};

#endif /* JST_COLOR_h */

