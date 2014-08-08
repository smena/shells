#!/bin/bash
#
## NOTE: Unknown original author. - smena
#
#    This script implements file locking.  If run using this mechanism, a job will not be able to stomp on itself.  You will get, at maximum, one running instance of the job at any time.
#
#    This is not a complete, runnable script on its own.  You MUST write another script that implements the variables listed here:
#        name
#        numLockTriesMax
#        nameFacility
#    and the function:
#        doTask()
#    in order to actually use it.  That other script should source this file in, which will execute the code below and run the doTask() function.

function error () { # 1=ERROR_STRING
    /usr/bin/logger -i -s -p ${nameFacility}.err -t ${name} "${1}"
    echo -e "${1}" | /bin/mail -s "${name}" "alert.tech@spirevision.com"
    return 0
}

function removeLock () {
    local flagErrorRemoval="0"
    # FIXME: Check permissions on the count file--there is a degenerate edge case where another (root) process changes perms after we create it.  We should know about it and flag it separately.
    if [ -e "${fpathLockCount}" ]; then
        if ! /bin/rm ${fpathLockCount}; then
            error "could not remove count file '${fpathLockCount}' on exit"
            flagErrorRemoval="1"
        fi
    fi
    # FIXME: Check permissions on the lock file--there is a degenerate edge case where another (root) process changes perms after we create it.  We should know about it and flag it separately.
    if ! /bin/rm ${fpathLock}; then
        error "could not remove lock file '${fpathLock}' on exit"
        flagErrorRemoval="1"
    fi
    # FIXME:  Is this a proper comparison?
    if [ "${flagErrorRemoval}" == "1" ]; then
        return 1
    else
        return 0
    fi
}

# Defines the system-wide lock directory.
dpathLock="/var/lock"

# Determine where the 'mktemp' program lives on this system.  If we can't find it, error out--we really need it!
if ! cmd_mktemp=$(which mktemp); then
    error "necessary utility 'mktemp' cannot be found"
    exit 1
fi

# Check that this script is being sourced in from an environment that properly defined the necessary variables.  We haven't yet attempted to get a lock, so don't try to remove the lock on exit, because it's not our lock.
if [ "${name}" == "" ]; then
    error "necessary variable 'name' has not been defined"
    exit 1
fi
if [ "${numLockTriesMax}" == "" ]; then
    error "necessary variable 'numLockTriesMax' has not been defined"
    exit 1
fi
if [ "${nameFacility}" == "" ]; then
    error "necessary variable 'nameFacility' has not been defined"
    exit 1
fi

# Set the runtime values that are particular to this invocation of the script.
fpathLock="${dpathLock}/${name}"
fpathLockCount="${dpathLock}/${name}.count"
numPid="${$}"

# Check that the lock file location is suitable.  Remember, the lock isn't yet ours, so don't try to remove it on exit.
if ! [ -e "${dpathLock}" ]; then
    error "lock directory '${dpathLock}' does not exist"
    exit 1
fi
if ! [ -d "${dpathLock}" ]; then
    error "'${dpathLock}' exists, but is not a directory"
    exit 1
fi
if !( [ -r "${dpathLock}" ] && [ -w "${dpathLock}" ] && [ -x "${dpathLock}" ] ); then
    error "lock directory '${dpathLock}' does not have sufficient permissions for lock operations"
    exit 1
fi

# Attempt to get a lock on the defined lock file.
if ! fpathLockCheck="$( ${cmd_mktemp} -qp ${dpathLock} ${name} )"; then
    # Inside here, we failed to obtain the lock.
    # FIXME: Grab the PID from the lock file and check whether the process is still running, too.
    # If a count file already exists, we need to read it to determine how many consecutive lockouts have occurred.
    if [ -e "${fpathLockCount}" ]; then
        # Sanity check the type and permissions of the count file before we start messing with it.
        if ! [ -f "${fpathLockCount}" ]; then
            error "'${fpathLockCount}' exists, but is not a file"
            exit 1
        fi
        if ! ( [ -r "${fpathLockCount}" ] && [ -w "${fpathLockCount}" ] ); then
            error "count file '${fpathLockCount}' does not have sufficient permissions for lock operations"
            exit 1
        fi
        numLockTries="$( /bin/cat ${fpathLockCount} )"
    else
        # A count file doesn't already exist, so this is the first consecutive lockout.
        numLockTries="0"
    fi
    # Check whether the user-defined limit on the maximum acceptable number of consecutive lockouts has been reached.
    if [ "${numLockTries}" -le "${numLockTriesMax}" ]; then
        # No error, just increment the lock try counter.
        echo -e "${numLockTries} + 1" | /usr/bin/bc > ${fpathLockCount}
        exit 0
    else
        # The number of consecutive logouts is great enough to be troubling, so this warrants an error.
        error "lock file '${fpathLock}' already exists (${numLockTries} consecutive occurances, according to count file '${fpathLockCount}')"
        echo -e "${numLockTries} + 1" | /usr/bin/bc > ${fpathLockCount}
        exit 1
    fi
fi

# Past here, we have successfully obtained a lock.  If we exit, no matter what the cause, we should remove both the lock file and the count file.
#if [ -e "${fpathLockCount}" ]; then
    # Sanity check the type and permissions of the count file before we start messing with it.
#   if ! [ -f "${fpathLockCount}" ]; then
#       /usr/bin/logger -i -s -p ${nameFacility}.err -t ${name} "'${fpathLockCount}' exists, but is not a file"
#       exit 1
#   fi
#   if ! ( [ -r "${fpathLockCount}" ] && [ -w "${fpathLockCount}" ] ); then
#       /usr/bin/logger -i -s -p ${nameFacility}.err -t ${name} "count file '${fpathLockCount}' does not have sufficient permissions for lock operations"
#       exit 1
#   fi
#   numLockTries="$( /bin/cat ${fpathLockCount} )"
#else
    # A count file doesn't already exist, so this is the first consecutive lockout.
#   numLockTries="0"
#fi

# To guarantee that we remove our lock files on exit, we need to trap some signals.
# FIXME: Is this overkill?  Underkill?  Verify that this list of signals to trap is appropriate.
# FIXME: Verify that this distribution of exit values in relation to signal types is appropriate.
trap 'if ! removeLock; then exit 1; else exit 0; fi' SIGHUP    # We need to check the return code of 'removeLock()' because if it runs OK, we exit without error.
trap 'removeLock; exit 1' SIGINT    # Always implies exit with error.
trap 'removeLock; exit 1' SIGQUIT    # Always implies exit with error.
trap 'removeLock; exit 1' SIGTERM    # Always implies exit with error.
# We don't want to trap the BASH psuedo-signal 'EXIT' because we need different behavior on exit, depending on whether we have the lock file or not.  Well, we COULD implement it that way, but it seems like more work, and more global flag variables.

# This should never be triggered--'mktemp()' should always return the value we fed to it if it exists with success.
if [ "${fpathLock}" != "${fpathLockCheck}" ]; then
    error "(WTF) attempt to get lock on file '${fpathLock}' failed and got file '${fpathLockCheck}' instead"
    removeLock
    exit 1
fi

# Write the current PID into the lock file, just in case we need it.  Actually, we need it to implement the FIXME involving checking whether the locking process is actually still running (above, in the 'failed to get lock' section).
# FIXME: Check permissions on the lock file--there is a degenerate edge case where another (root) process changes perms after we create it.
if ! echo -n -e "$$" > ${fpathLock}; then
    error "(WTF) could not write current PID '${numPid}' to lock file '${fpathLock}'"
    removeLock
    exit 1
fi

# While we have the lock, try the task itself.
if ! doTask; then
    # The task failed.
    error "task '${name}' exited with error"
    removeLock
    exit 1
else
    # We want to exit with success, unless the lock file removal fails.  Then, we exit with an error, despite the fact that the task successfully ran.
    if ! removeLock; then
        exit 1
    else
        exit 0
    fi
fi

# End of file.


