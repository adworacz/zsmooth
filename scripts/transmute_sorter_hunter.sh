#!/bin/sh
echo "$1" | sed 's/[()]//g' | sed 's/\[/{/g' | sed 's/\]/}/g' | awk '{ print "&[_]usize"$1"," }'
