#!/bin/bash
p4 edit $(readlink -f ${0%/*}/../iso/data/internal_version)
# p4 can't cope with foo/../bar
date -u +%Y%m%d%H >${0%/*}/../iso/data/internal_version
