#!/bin/bash

for FOLDER in ./out/*; do
    for FILE in $FOLDER/*; do
        NAME=$(basename $FILE)
        if [ $NAME == $1 ]
        then
            cast abi-encode "result(string)" $FILE
            break
        fi
    done
done