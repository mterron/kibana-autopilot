#!/bin/sh
if curl --fail -s -o /dev/null "http://$(hostname -i):5601"; then 
    exit 0
elif [ $? -eq 22 ]; then # Exit status on ES startup, investigate.
    exit 0
else 
    exit $?
fi