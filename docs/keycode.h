/*
    *  Summary:
    *    Virtual keycodes
    *  
    *  Discussion:
    *    These constants are the virtual keycodes defined originally in
    *    Inside Mac Volume V, pg. V-191. They identify physical keys on a
    *    keyboard. Those constants with "ANSI" in the name are labeled
    *    according to the key position on an ANSI-standard US keyboard.
    *    For example, kVK_ANSI_A indicates the virtual keycode for the key
    *    with the letter 'A' in the US keyboard layout. Other keyboard
    *    layouts may have the 'A' key label on a different physical key;
    *    in this case, pressing 'A' will generate a different virtual
    *    keycode.
    */
enum {
    kVK_ANSI_A                    = 0x00,  // 0x41
    kVK_ANSI_S                    = 0x01,  // 0x53
    kVK_ANSI_D                    = 0x02,  // 0x44
    kVK_ANSI_F                    = 0x03,  // 0x46
    kVK_ANSI_H                    = 0x04,  // 0x48
    kVK_ANSI_G                    = 0x05,  // 0x47
    kVK_ANSI_Z                    = 0x06,  // 0x5A
    kVK_ANSI_X                    = 0x07,  // 0x58
    kVK_ANSI_C                    = 0x08,  // 0x43
    kVK_ANSI_V                    = 0x09,  // 0x56
    kVK_ANSI_B                    = 0x0B,  // 0x42
    kVK_ANSI_Q                    = 0x0C,  // 0x51
    kVK_ANSI_W                    = 0x0D,  // 0x57
    kVK_ANSI_E                    = 0x0E,  // 0x45
    kVK_ANSI_R                    = 0x0F,  // 0x52
    kVK_ANSI_Y                    = 0x10,  // 0x59
    kVK_ANSI_T                    = 0x11,  // 0x54
    kVK_ANSI_1                    = 0x12,  // 0x31
    kVK_ANSI_2                    = 0x13,  // 0x32
    kVK_ANSI_3                    = 0x14,  // 0x33
    kVK_ANSI_4                    = 0x15,  // 0x34
    kVK_ANSI_6                    = 0x16,  // 0x36
    kVK_ANSI_5                    = 0x17,  // 0x35
    kVK_ANSI_Equal                = 0x18,  // 0xBB
    kVK_ANSI_9                    = 0x19,  // 0x39
    kVK_ANSI_7                    = 0x1A,  // 0x37
    kVK_ANSI_Minus                = 0x1B,  // 0xBD
    kVK_ANSI_8                    = 0x1C,  // 0x38
    kVK_ANSI_0                    = 0x1D,  // 0x30
    kVK_ANSI_RightBracket         = 0x1E,  // 0xDD
    kVK_ANSI_O                    = 0x1F,  // 0x4F
    kVK_ANSI_U                    = 0x20,  // 0x55
    kVK_ANSI_LeftBracket          = 0x21,  // 0xDB
    kVK_ANSI_I                    = 0x22,  // 0x49
    kVK_ANSI_P                    = 0x23,  // 0x50
    kVK_ANSI_L                    = 0x25,  // 0x4C
    kVK_ANSI_J                    = 0x26,  // 0x4A
    kVK_ANSI_Quote                = 0x27,  // 0xDE
    kVK_ANSI_K                    = 0x28,  // 0x4B
    kVK_ANSI_Semicolon            = 0x29,  // 0xBA
    kVK_ANSI_Backslash            = 0x2A,  // 0xDC
    kVK_ANSI_Comma                = 0x2B,  // 0xBC
    kVK_ANSI_Slash                = 0x2C,  // 0xBF
    kVK_ANSI_N                    = 0x2D,  // 0x4E
    kVK_ANSI_M                    = 0x2E,  // 0x4D
    kVK_ANSI_Period               = 0x2F,  // 0xBE
    kVK_ANSI_Grave                = 0x32,  // 0xC0
    kVK_ANSI_KeypadDecimal        = 0x41,  // 0x6E
    kVK_ANSI_KeypadMultiply       = 0x43,  // 0x6A
    kVK_ANSI_KeypadPlus           = 0x45,  // 0x6B
    kVK_ANSI_KeypadClear          = 0x47,  // 0x0C
    kVK_ANSI_KeypadDivide         = 0x4B,  // 0x6F
    kVK_ANSI_KeypadEnter          = 0x4C,  // 0x0D
    kVK_ANSI_KeypadMinus          = 0x4E,  // 0x6D
    kVK_ANSI_KeypadEquals         = 0x51,  // 0xBB
    kVK_ANSI_Keypad0              = 0x52,  // 0x60
    kVK_ANSI_Keypad1              = 0x53,  // 0x61
    kVK_ANSI_Keypad2              = 0x54,  // 0x62
    kVK_ANSI_Keypad3              = 0x55,  // 0x63
    kVK_ANSI_Keypad4              = 0x56,  // 0x64
    kVK_ANSI_Keypad5              = 0x57,  // 0x65
    kVK_ANSI_Keypad6              = 0x58,  // 0x66
    kVK_ANSI_Keypad7              = 0x59,  // 0x67
    kVK_ANSI_Keypad8              = 0x5B,  // 0x68
    kVK_ANSI_Keypad9              = 0x5C,  // 0x69
};

/* keycodes for keys that are independent of keyboard layout */
enum {
    kVK_Return                    = 0x24,  // 0x0D
    kVK_Tab                       = 0x30,  // 0x09
    kVK_Space                     = 0x31,  // 0x20
    kVK_Delete                    = 0x33,  // 0x08
    kVK_Escape                    = 0x35,  // 0x1B
    kVK_Command                   = 0x37,  // 0x5B
    kVK_Shift                     = 0x38,  // 0x10
    kVK_CapsLock                  = 0x39,  // 0x14
    kVK_Option                    = 0x3A,  // 0x12
    kVK_Control                   = 0x3B,  // 0x11
    kVK_RightShift                = 0x3C,  // 0x10
    kVK_RightOption               = 0x3D,  // 0x12
    kVK_RightControl              = 0x3E,  // 0x11
    kVK_Function                  = 0x3F,  // ...
    kVK_F17                       = 0x40,  // 0x80
    kVK_VolumeUp                  = 0x48,  // 0xB7
    kVK_VolumeDown                = 0x49,  // 0xB6
    kVK_Mute                      = 0x4A,  // 0xB5
    kVK_F18                       = 0x4F,  // 0x81
    kVK_F19                       = 0x50,  // 0x82
    kVK_F20                       = 0x5A,  // 0x83
    kVK_F5                        = 0x60,  // 0x74
    kVK_F6                        = 0x61,  // 0x75
    kVK_F7                        = 0x62,  // 0x76
    kVK_F3                        = 0x63,  // 0x72
    kVK_F8                        = 0x64,  // 0x77
    kVK_F9                        = 0x65,  // 0x78
    kVK_F11                       = 0x67,  // 0x7A
    kVK_F13                       = 0x69,  // 0x7C
    kVK_F16                       = 0x6A,  // 0x7F
    kVK_F14                       = 0x6B,  // 0x7D
    kVK_F10                       = 0x6D,  // 0x79
    kVK_F12                       = 0x6F,  // 0x7B
    kVK_F15                       = 0x71,  // 0x7E
    kVK_Help                      = 0x72,  // 0x2D 
    kVK_Home                      = 0x73,  // 0x24
    kVK_PageUp                    = 0x74,  // 0x21
    kVK_ForwardDelete             = 0x75,  // 0x2E
    kVK_F4                        = 0x76,  // 0x73
    kVK_End                       = 0x77,  // 0x23
    kVK_F2                        = 0x78,  // 0x71
    kVK_PageDown                  = 0x79,  // 0x22
    kVK_F1                        = 0x7A,  // 0x70
    kVK_LeftArrow                 = 0x7B,  // 0x25
    kVK_RightArrow                = 0x7C,  // 0x27
    kVK_DownArrow                 = 0x7D,  // 0x28
    kVK_UpArrow                   = 0x7E,  // 0x26
};
