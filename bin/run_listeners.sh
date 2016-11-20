#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source $DIR/locate.sh
cd $DIR/..

bundle install

if [ "$EUID" -ne 0 ]; then
  echo "WARNING: not running as root. If you're using the ARP probe driver, "
  echo "         this process needs to run as root."
fi

exec bundle exec ruby run_listeners.rb
