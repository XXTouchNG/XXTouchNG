#ifndef HIDRecorderEnums_h
#define HIDRecorderEnums_h

typedef NS_ENUM(NSUInteger, HIDRecorderOperation) {
    HIDRecorderOperationNone = 0,
    HIDRecorderOperationPlay,
    HIDRecorderOperationPlayWithAlert,
    HIDRecorderOperationRecord,
    HIDRecorderOperationRecordWithAlert,
    HIDRecorderOperationBoth,
    HIDRecorderOperationBothWithAlert,
};

typedef NS_ENUM(NSUInteger, HIDRecorderAction) {
    HIDRecorderActionNone = 0,
    HIDRecorderActionLaunch,
    HIDRecorderActionPause,
    HIDRecorderActionContinue,
    HIDRecorderActionRecord,
    HIDRecorderActionStop,
};

#endif /* HIDRecorderEnums_h */
