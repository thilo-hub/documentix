#!/bin/sh

# Ensure we are in the top-level directory
cd $(dirname $0)
INST="$(pwd -P)"

export PERL5LIB=$INST/local/lib/perl5
export PATH=$INST/local/bin:$PATH
export LD_LIBRARY_PATH=$INST/local/lib:$LD_LIBRARY_PATH

"$@"

