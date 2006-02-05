#!/bin/bash

function saveinfo() {
  echo "$ROOTDEV" >/proc/rootdev
  echo "$ACTION" >/proc/action
  echo "$CDDEV" >/proc/cddev
  exit 0
}

exec >/dev/console
exec 2>/dev/console
echo "Press enter to eject the CD..."
# print it here so we know this part of the script is ready
trap saveinfo SIGUSR1
sleep 1h
return 1
