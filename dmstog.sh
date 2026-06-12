#!/bin/bash
status=$(dms ipc call bar status index 0)
if echo "$status" | grep -q "hidden"; then
    dms ipc call bar reveal index 0
    dms ipc call dash open ""
else
    dms ipc call bar hide index 0
    dms ipc call dash close
fi
