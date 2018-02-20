#!/usr/bin/env bash

# path to the host base library modules
export CAULDRON_BASE="${CAULDRON_BASE:-${0%/*}/..}"

export CONFIG_FILE="${0%/*}/cauldron.conf"
export PATH="$CAULDRON_BASE/cauldron/bin:$PATH"

cauldron "${@:-shell}"
