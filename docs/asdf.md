## Notes on porting tweaks to arm64e

- **You don't have to do anything** with pointers you pass to MSHookMessage/Function/etc.
  Those are handled internally, and we will sign the %orig function for you.
- Function pointers from MSFindSymbol, etc. are no longer callable directly because they are
  returned without a PAC. To make them callable, you must sign them first.
- Similarly, function pointers created manually (e.g. by using a direct offset + slide)
  cannot be called directly either.
- Trying to access the contents of a signed function pointer is no longer possible,
  you will segfault.
- You can use the following header to convert between PACed and non-PACed pointers. It just
  wraps the intrinsics so your code will still compile if the toolchain doesn't understand
  arm64e yet.
- If you encounter an issue you believe is caused by our version of Substitute, let us know.

```c
#ifndef PTRAUTH_HELPERS_H
#define PTRAUTH_HELPERS_H
// Helpers for PAC archs.

// If the compiler understands __arm64e__, assume it's paired with an SDK that has
// ptrauth.h. Otherwise, it'll probably error if we try to include it so don't.
#if __arm64e__
#include <ptrauth.h>
#endif

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-function"

// Given a pointer to instructions, sign it so you can call it like a normal fptr.
static void *make_sym_callable(void *ptr) {
#if __arm64e__
    ptr = ptrauth_sign_unauthenticated(ptrauth_strip(ptr, ptrauth_key_function_pointer), ptrauth_key_function_pointer, 0);
#endif
    return ptr;
}

// Given a function pointer, strip the PAC so you can read the instructions.
static void *make_sym_readable(void *ptr) {
#if __arm64e__
    ptr = ptrauth_strip(ptr, ptrauth_key_function_pointer);
#endif
    return ptr;
}

#pragma clang diagnostic pop
#endif
```