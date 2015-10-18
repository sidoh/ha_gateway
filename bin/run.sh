#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source $DIR/locate.sh
cd $DIR/..

bundle install

exec bundle exec ruby ha_gateway.rb -p 8000 -o 0.0.0.0 >>$(ha_gateway_logdir)/ha_gateway.log
