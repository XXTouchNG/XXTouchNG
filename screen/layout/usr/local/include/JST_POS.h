#ifndef JST_POS_h
#define JST_POS_h

#import <stdint.h>
#import "JST_COLOR.h"

typedef struct JST_POS JST_POS;

/* Position Struct */
struct JST_POS {
    int32_t x;
    int32_t y;
    JST_COLOR color;
    int8_t similarity;
    JST_COLOR color_offset;
};

#endif /* JST_POS_h */
