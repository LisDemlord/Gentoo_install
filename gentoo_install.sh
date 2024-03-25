#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

fdisk /dev/vda
p
g
p
