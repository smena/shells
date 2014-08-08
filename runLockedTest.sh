#!/bin/bash

name="lockTest"
numLockTriesMax="2"
nameFacility="local4"
isDebug="0"

doTask() {
    local cmd_output
    if ! cmd_output="$(sleep 300 2>&1)"; then
        echo -e "${cmd_output}"
        return 1
    else
        if [ "${isDebug}" == "1" ]; then
            echo -e "${cmd_output}"
        fi
        return 0
    fi
    
}

. /var/www/util/runLocked/runLocked.sh

# End of file.
