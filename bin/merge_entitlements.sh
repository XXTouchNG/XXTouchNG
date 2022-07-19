#!/bin/bash

if [[ $# -ne 2 ]]; then
    echo "usage: $0 from.entitlements to.entitlements"
    exit 1
fi

/usr/libexec/PlistBuddy -x -c "Merge $1" $2

