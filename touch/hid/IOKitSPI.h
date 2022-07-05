/*
 * Copyright (C) 2015 Apple Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. AND ITS CONTRIBUTORS ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL APPLE INC. OR ITS CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 */

//#pragma once
//
//#if USE(APPLE_INTERNAL_SDK)
//
//#import <IOKit/hid/IOHIDEvent.h>
//#import <IOKit/hid/IOHIDEventData.h>
//#import <IOKit/hid/IOHIDEventSystemClient.h>
//#import <IOKit/hid/IOHIDUsageTables.h>
//
//#else

#import <Foundation/Foundation.h>

//WTF_EXTERN_C_BEGIN
#ifdef __cplusplus
extern "C" {
#endif

/**
 *  Private class source:
 *  http://www.opensource.apple.com/source/IOHIDFamily/IOHIDFamily-503.92.1/IOHIDFamily/IOHIDEventTypes.h
 */
typedef double IOHIDFloat;

enum {
    kIOHIDEventOptionNone = 0,
};

typedef UInt32 IOOptionBits;
typedef uint32_t IOHIDEventOptionBits;
typedef uint32_t IOHIDEventField;
typedef kern_return_t IOReturn;

typedef struct __IOHIDEventSystemClient *IOHIDEventSystemClientRef;
typedef void *IOHIDEventQueueRef;

/**
 *  Structure that represents IOHIDEvents, which are sent from iOS to the application.
 */
typedef struct __IOHIDEvent *IOHIDEventRef;

#define IOHIDEventFieldBase(type) (type << 16)

enum {
    kHIDPage_KeyboardOrKeypad       = 0x07,
    kHIDPage_Telephony              = 0x0B,
    kHIDPage_Consumer               = 0x0C,
    kHIDPage_VendorDefinedStart     = 0xFF00
};

/**
 *  Event mask detailing the events being dispatched by a digitizer. It is possible for digitizer
 *  events to contain child digitizer events, effectively, behaving as collections. In the
 *  collection case, the child event mask field reference by
 *  kIOHIDEventFieldDigitizerChildEventMask will detail the cumulative event state of the child
 *  digitizer events. If you append a child digitizer event to a parent digitizer event, appropriate
 *  state will be transferred on to the parent.
 */
enum {
    /**
    *  Issued when the range state has changed.
    */
    kIOHIDDigitizerEventRange       = 1 << 0,
    /**
    *  Issued when the touch state has changed.
    */
    kIOHIDDigitizerEventTouch       = 1 << 1,
    /**
    *  Issued when the position has changed.
    */
    kIOHIDDigitizerEventPosition    = 1 << 2,
    kIOHIDDigitizerEventIdentity    = 1 << 5,
    kIOHIDDigitizerEventAttribute   = 1 << 6,
    kIOHIDDigitizerEventCancel      = 1 << 7,
    kIOHIDDigitizerEventStart       = 1 << 8,
    kIOHIDDigitizerEventEstimatedAltitude = 1 << 28,
    kIOHIDDigitizerEventEstimatedAzimuth  = 1 << 29,
    kIOHIDDigitizerEventEstimatedPressure = 1 << 30,
    
    kIOHIDDigitizerEventSwipeUp     = 0x01000000,
    kIOHIDDigitizerEventSwipeDown   = 0x02000000,
    kIOHIDDigitizerEventSwipeLeft   = 0x04000000,
    kIOHIDDigitizerEventSwipeRight  = 0x08000000,
    kIOHIDDigitizerEventSwipeMask   = 0xFF000000,
};
typedef uint32_t IOHIDDigitizerEventMask;

enum {
    kIOHIDDigitizerEventUpdateAltitudeMask = 1 << 28,
    kIOHIDDigitizerEventUpdateAzimuthMask = 1 << 29,
    kIOHIDDigitizerEventUpdatePressureMask = 1 << 30
};

enum {
    kIOHIDEventTypeNULL,
    kIOHIDEventTypeVendorDefined,
    kIOHIDEventTypeKeyboard = 3,
    kIOHIDEventTypeRotation = 5,
    kIOHIDEventTypeScroll = 6,
    kIOHIDEventTypeZoom = 8,
    kIOHIDEventTypeDigitizer = 11,
    kIOHIDEventTypeNavigationSwipe = 16,
    kIOHIDEventTypeForce = 32,
    
};
typedef uint32_t IOHIDEventType;

/*
    @typedef IOHIDEventField
    @abstract Keys used to set and get individual event fields.
 */
enum {
    kIOHIDEventFieldIsRelative = IOHIDEventFieldBase(kIOHIDEventTypeNULL),
    kIOHIDEventFieldIsCollection,
    kIOHIDEventFieldIsPixelUnits,
    kIOHIDEventFieldIsCenterOrigin,
    kIOHIDEventFieldIsBuiltIn
};

enum {
    kIOHIDEventFieldKeyboardUsagePage = IOHIDEventFieldBase(kIOHIDEventTypeKeyboard),
    kIOHIDEventFieldKeyboardUsage,
    kIOHIDEventFieldKeyboardDown,
    kIOHIDEventFieldKeyboardRepeat
};

enum {
    kIOHIDEventFieldVendorDefinedUsagePage = IOHIDEventFieldBase(kIOHIDEventTypeVendorDefined),
    kIOHIDEventFieldVendorDefinedReserved,
    kIOHIDEventFieldVendorDefinedReserved1,
    kIOHIDEventFieldVendorDefinedDataLength,
    kIOHIDEventFieldVendorDefinedData
};

enum {
    kIOHIDEventFieldDigitizerX = IOHIDEventFieldBase(kIOHIDEventTypeDigitizer),
    kIOHIDEventFieldDigitizerY,
    kIOHIDEventFieldDigitizerType = kIOHIDEventFieldDigitizerX + 4,
    kIOHIDEventFieldDigitizerIndex,
    kIOHIDEventFieldDigitizerIdentity,
    kIOHIDEventFieldDigitizerEventMask,
    kIOHIDEventFieldDigitizerRange,
    kIOHIDEventFieldDigitizerTouch,
    kIOHIDEventFieldDigitizerPressure,
    kIOHIDEventFieldDigitizerBarrelPressure,
    kIOHIDEventFieldDigitizerTwist,
    kIOHIDEventFieldDigitizerMajorRadius = kIOHIDEventFieldDigitizerX + 20,
    kIOHIDEventFieldDigitizerMinorRadius,
    kIOHIDEventFieldDigitizerIsDisplayIntegrated = kIOHIDEventFieldDigitizerMajorRadius + 5,
};

enum {
    kIOHIDTransducerRange               = 0x00010000,
    kIOHIDTransducerTouch               = 0x00020000,
    kIOHIDTransducerInvert              = 0x00040000,
    kIOHIDTransducerDisplayIntegrated   = 0x00080000
};

enum {
    kIOHIDDigitizerTransducerTypeStylus  = 0,
    kIOHIDDigitizerTransducerTypeFinger = 2,
    kIOHIDDigitizerTransducerTypeHand = 3
};
typedef uint32_t IOHIDDigitizerTransducerType;

enum {
    kIOHIDEventFieldDigitizerWillUpdateMask = 720924,
    kIOHIDEventFieldDigitizerDidUpdateMask = 720925
};

enum {
    kIOHIDMotionStart   = 0,
    kIOHIDMotionEnd     = 1,
};
typedef uint32_t IOHIDMotionType;

enum {
    kIOHIDAccelerometerTypeNormal   = 0,
    kIOHIDAccelerometerTypeShake    = 1
};
typedef uint32_t IOHIDAccelerometerType;
typedef IOHIDMotionType IOHIDAccelerometerSubType;

enum {
    kIOHIDEventFieldAccelerometerX = IOHIDEventFieldBase(0x0D),
    kIOHIDEventFieldAccelerometerY,
    kIOHIDEventFieldAccelerometerZ,
    kIOHIDEventFieldAccelerometerType,
    kIOHIDEventFieldAccelerometerSubType
};

IOHIDEventRef IOHIDEventCreateDigitizerEvent(CFAllocatorRef, uint64_t, IOHIDDigitizerTransducerType, uint32_t, uint32_t, IOHIDDigitizerEventMask, uint32_t, IOHIDFloat, IOHIDFloat, IOHIDFloat, IOHIDFloat, IOHIDFloat, boolean_t, boolean_t, IOOptionBits);

/**
 *  Creates a digitizer event that sourced from a finger touching the screen.
 */
IOHIDEventRef IOHIDEventCreateDigitizerFingerEvent(
    CFAllocatorRef allocator, 
    uint64_t timeStamp, 
    uint32_t index, 
    uint32_t identity, 
    IOHIDDigitizerEventMask eventMask, 
    IOHIDFloat x, 
    IOHIDFloat y, 
    IOHIDFloat z, 
    IOHIDFloat tipPressure, 
    IOHIDFloat twist, 
    boolean_t range, 
    boolean_t touch, 
    IOHIDEventOptionBits options
);

IOHIDEventRef IOHIDEventCreateForceEvent(CFAllocatorRef, uint64_t, uint32_t, IOHIDFloat, uint32_t, IOHIDFloat, IOHIDEventOptionBits);

IOHIDEventRef IOHIDEventCreateKeyboardEvent(CFAllocatorRef, uint64_t, uint32_t, uint32_t, boolean_t, IOOptionBits);

IOHIDEventRef IOHIDEventCreateVendorDefinedEvent(CFAllocatorRef, uint64_t, uint32_t, uint32_t, uint32_t, uint8_t *, CFIndex, IOHIDEventOptionBits);

IOHIDEventRef IOHIDEventCreateDigitizerStylusEventWithPolarOrientation(CFAllocatorRef, uint64_t, uint32_t, uint32_t, IOHIDDigitizerEventMask, uint32_t, IOHIDFloat, IOHIDFloat, IOHIDFloat, IOHIDFloat, IOHIDFloat, IOHIDFloat, IOHIDFloat, IOHIDFloat, boolean_t, boolean_t, IOHIDEventOptionBits);

IOHIDEventRef IOHIDEventCreateAccelerometerEvent(CFAllocatorRef, uint64_t, IOHIDFloat, IOHIDFloat, IOHIDFloat, IOOptionBits);

IOHIDEventType IOHIDEventGetType(IOHIDEventRef);

uint64_t /* AbsoulteTime */ IOHIDEventGetTimeStamp(IOHIDEventRef event);
void IOHIDEventSetTimeStamp(IOHIDEventRef event, uint64_t timeStamp);

CFArrayRef IOHIDEventGetChildren(IOHIDEventRef event);

CFIndex IOHIDEventGetIntegerValue(IOHIDEventRef, IOHIDEventField);
void IOHIDEventSetIntegerValue(IOHIDEventRef, IOHIDEventField, CFIndex);

IOHIDFloat IOHIDEventGetFloatValue(IOHIDEventRef event, IOHIDEventField field);
void IOHIDEventSetFloatValue(IOHIDEventRef event, IOHIDEventField field, IOHIDFloat value);

void IOHIDEventSetSenderID(IOHIDEventRef, uint64_t);
void IOHIDEventAppendEvent(IOHIDEventRef, IOHIDEventRef, IOOptionBits);

typedef void(*IOHIDEventSystemClientEventCallback)(void* target, void* refcon, IOHIDEventQueueRef queue, IOHIDEventRef event);

void IOHIDEventSystemClientRegisterEventCallback(IOHIDEventSystemClientRef client, IOHIDEventSystemClientEventCallback callback, void* target, void* refcon);
void IOHIDEventSystemClientUnregisterEventCallback(IOHIDEventSystemClientRef client);

void IOHIDEventSystemClientUnscheduleWithRunLoop(IOHIDEventSystemClientRef client, CFRunLoopRef runloop, CFStringRef mode);
void IOHIDEventSystemClientScheduleWithRunLoop(IOHIDEventSystemClientRef client, CFRunLoopRef runloop, CFStringRef mode);

IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef);
void IOHIDEventSystemClientDispatchEvent(IOHIDEventSystemClientRef, IOHIDEventRef);


#define kGSEventPathInfoInRange (1 << 0)
#define kGSEventPathInfoInTouch (1 << 1)

enum {
    kHIDUsage_KeyboardA = 0x04,
    kHIDUsage_Keyboard1 = 0x1E,
    kHIDUsage_Keyboard2 = 0x1F,
    kHIDUsage_Keyboard3 = 0x20,
    kHIDUsage_Keyboard4 = 0x21,
    kHIDUsage_Keyboard5 = 0x22,
    kHIDUsage_Keyboard6 = 0x23,
    kHIDUsage_Keyboard7 = 0x24,
    kHIDUsage_Keyboard8 = 0x25,
    kHIDUsage_Keyboard9 = 0x26,
    kHIDUsage_Keyboard0 = 0x27,
    kHIDUsage_KeyboardReturnOrEnter = 0x28,
    kHIDUsage_KeyboardEscape = 0x29,
    kHIDUsage_KeyboardDeleteOrBackspace = 0x2A,
    kHIDUsage_KeyboardTab = 0x2B,
    kHIDUsage_KeyboardSpacebar = 0x2C,
    kHIDUsage_KeyboardHyphen = 0x2D,
    kHIDUsage_KeyboardEqualSign = 0x2E,
    kHIDUsage_KeyboardOpenBracket = 0x2F,
    kHIDUsage_KeyboardCloseBracket = 0x30,
    kHIDUsage_KeyboardBackslash = 0x31,
    kHIDUsage_KeyboardSemicolon = 0x33,
    kHIDUsage_KeyboardQuote = 0x34,
    kHIDUsage_KeyboardGraveAccentAndTilde = 0x35,
    kHIDUsage_KeyboardComma = 0x36,
    kHIDUsage_KeyboardPeriod = 0x37,
    kHIDUsage_KeyboardSlash = 0x38,
    kHIDUsage_KeyboardCapsLock = 0x39,
    kHIDUsage_KeyboardF1 = 0x3A,
    kHIDUsage_KeyboardF12 = 0x45,
    kHIDUsage_KeyboardPrintScreen = 0x46,
    kHIDUsage_KeyboardPause = 0x48,
    kHIDUsage_KeyboardInsert = 0x49,
    kHIDUsage_KeyboardHome = 0x4A,
    kHIDUsage_KeyboardPageUp = 0x4B,
    kHIDUsage_KeyboardDeleteForward = 0x4C,
    kHIDUsage_KeyboardEnd = 0x4D,
    kHIDUsage_KeyboardPageDown = 0x4E,
    kHIDUsage_KeyboardRightArrow = 0x4F,
    kHIDUsage_KeyboardLeftArrow = 0x50,
    kHIDUsage_KeyboardDownArrow = 0x51,
    kHIDUsage_KeyboardUpArrow = 0x52,
    kHIDUsage_KeypadNumLock = 0x53,
    kHIDUsage_KeyboardF13 = 0x68,
    kHIDUsage_KeyboardF24 = 0x73,
    kHIDUsage_KeyboardMenu = 0x76,
    kHIDUsage_KeypadComma = 0x85,
    kHIDUsage_KeyboardLeftControl = 0xE0,
    kHIDUsage_KeyboardLeftShift = 0xE1,
    kHIDUsage_KeyboardLeftAlt = 0xE2,
    kHIDUsage_KeyboardLeftGUI = 0xE3,
    kHIDUsage_KeyboardRightControl = 0xE4,
    kHIDUsage_KeyboardRightShift = 0xE5,
    kHIDUsage_KeyboardRightAlt = 0xE6,
    kHIDUsage_KeyboardRightGUI = 0xE7,
};

enum {
    kHIDUsage_Csmr_Power              = 0x30,          /* On/Off Control */
    kHIDUsage_Csmr_Menu               = 0x40,          /* On/Off Control */
    kHIDUsage_Csmr_Snapshot           = 0x65,          /* One-Shot Control */
    
    kHIDUsage_Csmr_DisplayBrightnessIncrement = 0x6F,  /* Re-Trigger Control */
    kHIDUsage_Csmr_DisplayBrightnessDecrement = 0x70,  /* Re-Trigger Control */
    
    kHIDUsage_Csmr_Play               = 0xB0,          /* On/Off Control */
    kHIDUsage_Csmr_Pause              = 0xB1,          /* On/Off Control */
    kHIDUsage_Csmr_FastForward        = 0xB3,          /* On/Off Control */
    kHIDUsage_Csmr_Rewind             = 0xB4,          /* On/Off Control */
    kHIDUsage_Csmr_ScanNextTrack      = 0xB5,          /* One-Shot Control */
    kHIDUsage_Csmr_ScanPreviousTrack  = 0xB6,          /* One-Shot Control */
    kHIDUsage_Csmr_Stop               = 0xB7,          /* One-Shot Control */
    kHIDUsage_Csmr_Eject              = 0xB8,          /* One-Shot Control */
    kHIDUsage_Csmr_StopOrEject        = 0xCC,          /* One-Shot Control */
    kHIDUsage_Csmr_PlayOrPause        = 0xCD,          /* One-Shot Control */
    
    kHIDUsage_Csmr_Mute               = 0xE2,          /* On/Off Control */
    kHIDUsage_Csmr_VolumeIncrement    = 0xE9,          /* Re-Trigger Control */
    kHIDUsage_Csmr_VolumeDecrement    = 0xEA,          /* Re-Trigger Control */
    
    kHIDUsage_Csmr_ALKeyboardLayout   = 0x1AE,         /* Selector */
    kHIDUsage_Csmr_ACSearch           = 0x221,         /* Selector */
    kHIDUsage_Csmr_ACLock             = 0x26B,         /* Selector */
    kHIDUsage_Csmr_ACUnlock           = 0x26C,         /* Selector */
};

//WTF_EXTERN_C_END
#ifdef __cplusplus
}
#endif

//#endif // USE(APPLE_INTERNAL_SDK)
