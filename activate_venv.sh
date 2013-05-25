#!/bin/bash
#
# Use as SLAVE_RUNNER in /etc/default/buildslave.

if [ -e $3/../bin/activate ]; then 
    source $3/../bin/activate
fi

/usr/bin/buildslave $@
