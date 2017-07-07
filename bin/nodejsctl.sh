#!/bin/bash

#set NODE_ENV = production
export NODE_ENV='production'

#set ulimit
ulimit -c unlimited

#set for alinode
export ENABLE_NODE_LOG=YES
export NODE_LOG_DIR=/tmp/

NODEJS=$(which node)
BASE_HOME=$(pwd)
PROJECT_NAME=$(basename "${BASE_HOME}")

if [[ -z "${ENTRY_FILE}" ]]; then
  ENTRY_FILE=dispatch.js
else
  ENTRY_FILE="${ENTRY_FILE}"
fi
NODE_DISPATH_PATH=${BASE_HOME}/${ENTRY_FILE}

STDOUT_LOG_FILE=nodejs_stdout.log

if [[ -z "${LOG_DIR}" ]]; then
  if [ -d "$BASE_HOME/config" ]; then
    LOG_DIR=$($NODEJS -e "console.log(require('$BASE_HOME/config').logdir);\
process.exit(0);")
  else
    LOG_DIR=/tmp
  fi
else
  LOG_DIR="${STDOUT_LOG}"
fi

STDOUT_LOG=${LOG_DIR}/${STDOUT_LOG_FILE}

PROG_NAME=$0
ACTION=$1
usage() {
  echo "Usage: $PROG_NAME {start|stop|status|restart}"
  exit 1;
}

if [ $# -lt 1 ]; then
  usage
fi

function get_pid {
  PID=$(ps ax | grep ${NODEJS} | grep -v grep | grep ${PROJECT_NAME}/${ENTRY_FILE} | awk '{print $1}')
}

#start nodejs
start()
{
  get_pid
  if [ -z "$PID" ]; then
    echo "Starting $PROJECT_NAME ..."
    echo "nohup $NODEJS $NODE_DISPATH_PATH > $STDOUT_LOG 2>&1 &"
    nohup "$NODEJS" "$NODE_DISPATH_PATH" > "$STDOUT_LOG"  2>&1 &
    sleep 2
    get_pid
    echo "Start nodejs success. PID=$PID"
  else
    echo "$PROJECT_NAME is already running, PID=$PID"
  fi
}

stop()
{
  get_pid
  if [ ! -z "$PID" ]; then
    echo "Waiting $PROJECT_NAME stop for 2s ..."
    kill -15 "$PID"
    sleep 2

    node_num=$(ps -ef | grep "${PROJECT_NAME}" | grep -v grep | wc -l)
    if [ $node_num != 0 ]; then
      ps -ef | grep "${PROJECT_NAME}" | grep -v grep|awk '{print $2}'| xargs kill -9
      ipcs -s | grep 0x | awk '{print $2}' | xargs -n1 ipcrm -s  > /dev/null 2>&1
      ipcs -m | grep 0x | awk '{print $2}' | xargs -n1 ipcrm -m  > /dev/null 2>&1
    fi

    if [ -f "$STDOUT_LOG" ]; then
      mv -f "$STDOUT_LOG" "${STDOUT_LOG}.$(date '+%Y%m%d%H%M%S')"
    fi
  else
    echo "$PROJECT_NAME is not running"
  fi
}

status()
{
  get_pid
  if [ ! -z "$PID" ]; then
    echo "$PROJECT_NAME PID: $PID"
    node_processes=$(ps -ef | grep "$PID" | grep -v grep)
    echo "master:"
    echo "$node_processes" | grep ${ENTRY_FILE}
    worker_count=$(echo "$node_processes" | grep -v ${ENTRY_FILE} | wc -l)
    echo "workers: $worker_count"
    echo "$node_processes" | grep -v ${ENTRY_FILE}
  else
    echo "$PROJECT_NAME is not running"
  fi
  exit 0;
}

case "$ACTION" in
  start)
    start
  ;;
  status)
    status
  ;;
  stop)
    stop
  ;;
  restart)
    stop
    start
  ;;
  *)
    usage
  ;;
esac
