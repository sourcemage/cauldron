#!/bin/bash
p4 edit ${0%/*}/../iso/data/internal_version
date -u +%Y%m%d%H >${0%/*}/../iso/data/internal_version
