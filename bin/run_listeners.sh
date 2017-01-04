#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source $DIR/locate.sh
cd $DIR/..

bundle install --deployment

if [ "$EUID" -ne 0 ] && [ $(bundle exec ruby run_listeners.rb --requires-sudo) == "true" ]; then
  echo "ERROR: run_listeners.sh was not run as root. Some listener drivers "
  echo "       require root access."
  exit 1
fi

exec bundle exec ruby run_listeners.rb
