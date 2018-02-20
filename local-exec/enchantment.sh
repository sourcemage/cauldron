#!/usr/bin/env bash

# path to the host base library modules
export ENCHANT_BASE="${ENCHANT_BASE:-${0%/*}/..}"

export CONFIG="${0%/*}/enchantment.conf"
export PATH="$ENCHANT_BASE/enchantment/enchanters/shell/bin:$PATH"

enchantment-shell "$@"
