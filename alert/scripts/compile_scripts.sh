#!/bin/bash


# prepare items
read -r -d '' SOURCE_ITEMS << __EOF__
AHCommonPayload.json
__EOF__


# compile items
for SOURCE_ITEM in $SOURCE_ITEMS; do

TARGET_ITEM="${SOURCE_ITEM}.h"
ATOMIC_ITEM="${TARGET_ITEM}.atomic"

ESCAPED_NAME=$(echo ${SOURCE_ITEM} | tr ./ _)
xxd -i "${SOURCE_ITEM}" > "${ATOMIC_ITEM}"
cat >> "${ATOMIC_ITEM}" << __EOF__

NS_INLINE
NSData *__InlineData_${ESCAPED_NAME}(void) __attribute((__annotate__(("nostrenc"))));
NSData *__InlineData_${ESCAPED_NAME}() {
    static NSData *payloadData = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        payloadData = [[NSData alloc] initWithBytes:${ESCAPED_NAME} length:${ESCAPED_NAME}_len];
    });
    return payloadData;
}

__EOF__

ATOMIC_MD5=$(md5 -q "${ATOMIC_ITEM}")
TARGET_MD5=$(md5 -q "${TARGET_ITEM}")

if [[ "${TARGET_MD5}" != "${ATOMIC_MD5}" ]]; then
    mv -f "${ATOMIC_ITEM}" "${TARGET_ITEM}"
    echo "warning: Compiled ${TARGET_ITEM}"
else
    rm "${ATOMIC_ITEM}"
    echo "warning: Skipped ${TARGET_ITEM}"
fi

done  # for


exit 0

