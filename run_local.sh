#!/bin/sh

INST="$(pwd -P)"

export PERL5LIB=$INST/local/lib/Perl5
export PATH=$INST/local/bin:$PATH
export LD_LIBRARY_PATH=$INST/local/lib:$LD_LIBRARY_PATH

"$@"

