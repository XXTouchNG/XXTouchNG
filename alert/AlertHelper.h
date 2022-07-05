#ifndef AlertHelper_h
#define AlertHelper_h

#import <Foundation/Foundation.h>

#ifdef TFLuaBridge
#undef TFLuaBridge
#endif

#define TFLuaBridge AlertHelper_TFLuaBridge

OBJC_EXTERN void SetupAlertHelper(void);

#endif /* AlertHelper_h */
