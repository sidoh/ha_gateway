#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

ha_gateway_tmpdir() {
  cd $DIR/..
  mkdir -p tmp
  cd tmp

  pwd
}

ha_gateway_pidfile() {
  process=$1
  echo "$(ha_gateway_tmpdir)/${process}.pid"
}

ha_gateway_locate() {
  process=$1
  pidfile=$(ha_gateway_pidfile "$process")
  if [[ -e "$pidfile" ]] && [[ $(ps -p $(cat "$pidfile") -o 'pid=' | wc -l) -gt 0 ]]; then
    cat "$pidfile"
  fi
}

ha_gateway_logdir() {
  cd $DIR/..
  [ -e log ] || mkdir -p log
  cd log

  pwd
}
