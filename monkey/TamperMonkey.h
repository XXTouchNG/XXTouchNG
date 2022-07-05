#ifndef TamperMonkey_h
#define TamperMonkey_h

#ifdef TFLuaBridge
#undef TFLuaBridge
#endif

#define TFLuaBridge TamperMonkey_TFLuaBridge

OBJC_EXTERN void SetupTamperMonkey(void);

#endif /* TamperMonkey_h */
