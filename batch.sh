#!/bin/bash

# Functions
youredoingitwrong()
{
    echo
    echo "Usage: batch.sh [serverTypeLabel] [run|put] [command|sourcefile] [destpath] "
    echo
    echo "Example: batch.sh slaveDatabase run \"hostname\""
    echo "Example: batch.sh mta put ~/main.cf /etc/postfix/main.cf"
    echo
    exit 1
}

runiter()
{
    echo -e "\E[37;44m\033[1m                                    $SERVER                                    \033[0m"
    echo -e "\033[1m * Running $ARG1 on $SERVER * \033[0m"
    /usr/bin/ssh -o ConnectTimeout=5 -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i $KEY root@`echo $SERVER | sed "s/pcposts/routename/g"` "$ARG1" &
}

putiter()
{
    echo -e "\E[37;44m\033[1m                                    $SERVER                                    \033[0m"
    echo -e "\033[1m * Putting $ARG1 in $ARG2 on $SERVER * \033[0m"
    /usr/bin/scp -o ConnectTimeout=5 -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -r -i $KEY $ARG1 root@`echo $SERVER | sed "s/pcposts/routename/g"`:$ARG2 &
}

getiter()
{
        echo -e "\E[37;44m\033[1m                                    $SERVER                                    \033[0m"
        echo -e "\033[1m * Getting $ARG1 from $SERVER * \033[0m"
    export TMPSRV=`echo $SERVER | sed "s/pcposts/routename/g"`
        /usr/bin/scp -o ConnectTimeout=5 -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -r -i $KEY root@$TMPSRV:$ARG1 `basename $ARG1`.$TMPSRV
}

run()
{
    if [ "$GROUP" = "proxy" -o "$GROUP" = "node" ]; then
        getips
        for SERVER in $IPLIST
            do
                runiter             
            done
    else
        gethosts
        for SERVER in $HOSTNAMELIST
            do
                runiter
            done
    fi
}

put()
{
    if [ -z "$GROUP" -o -z "$ACTION" -o -z "$ARG1" -o -z "$ARG2" ]; then
        youredoingitwrong
    fi
    
    if [ "$GROUP" = "proxy" ]; then
        getips
        for SERVER in $IPLIST
            do
                putiter             
            done
    else
        gethosts
        for SERVER in $HOSTNAMELIST
            do
                putiter
            done
    fi
}

get()
{
        if [ -z "$GROUP" -o -z "$ACTION" -o -z "$ARG1" -o -z "$ARG2" ]; then
                youredoingitwrong
        fi

        if [ "$GROUP" = "proxy" ]; then
                getips
                for SERVER in $IPLIST
                        do
                                getiter
                        done
        else
                gethosts
                for SERVER in $HOSTNAMELIST
                        do
                                getiter
                        done
        fi

}

getips()
{
IPLIST=`{{ ip_db_query }}`
}

gethosts()
{
HOSTNAMELIST=`{{ hostname_db_query }}`
}

# Vars
GROUP=$1
ACTION=$2
ARG1=$3
ARG2=$4

if [ -z "$GROUP" -o -z "$ACTION" -o -z "$ARG1" ]; then
    youredoingitwrong
fi

# Paths to keys (if applicable)
## Private keys for auth is a bad idea
## Use auth via authorized_keys on server
MTA="~/.ssh/mta"
PROXY="~/.ssh/proxy"
DB="~/.ssh/db"
NODE="~/.ssh/node"
CONTENT="~/.ssh/content"

# Which key to use
if [ "$1" = "mta" ]; then
    KEY=$MTA
fi
if [ "$1" = "ec" ]; then
    KEY=$MTA
fi
if [ "$1" = "pmta" ]; then
    KEY=$MTA
fi
if [ "$1" = "proxy" ]; then
    KEY=$PROXY
fi
if [ "$1" = "slaveDatabase" ]; then
    KEY=$DB
fi
if [ "$1" = "node" ]; then
    KEY=$NODE
fi
if [ "$1" = "content" ]; then
    KEY=$CONTENT
fi
if [ "$1" = "mtaData" ]; then
        KEY=$DB
fi
if [ "$1" = "database" ]; then
            KEY=$DB
fi


# What to do
if [ "$2" = "run" ]; then
    run
fi

if [ "$2" = "put" ]; then
    put
fi

if [ "$2" = "get" ]; then
    get
fi

