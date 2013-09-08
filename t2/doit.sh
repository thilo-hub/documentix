#!/bin/sh
cat >out.$$.data
env >out.$$.env
echo "$@" >out.$$.set
