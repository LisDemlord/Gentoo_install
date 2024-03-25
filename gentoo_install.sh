#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

echo -ne "label:gpt\nsize=2GiB,type=\"EFI System\"\nsize=12GiB,type=\"Linux swap\"\nsize=+,type=\"Linux root (x86-64)\"\n" | sfdisk /dev/vda
