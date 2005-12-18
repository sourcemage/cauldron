#!/bin/bash

function saveinfo() {
  echo "$ROOTDEV" >/proc/rootdev
  echo "$ACTION" >/proc/action
  exit 0
}

exec </dev/console
exec >/dev/console
exec 2>/dev/console
echo "Not doing anything really..."
sleep 1
echo "ROOTDEV=$ROOTDEV"
echo "ACTION=$ACTION"
trap saveinfo SIGUSR1
sleep 1h
return 1
