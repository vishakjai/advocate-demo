#!/usr/bin/env bash

# Imported from the runbook documentation script from jarv@gitlab.com
# https://ops.gitlab.net/gitlab-com/runbooks/-/commit/8f6c96672c87ab451bcdf6f5b40ddfab4f929c99
#
# Resets yubikey with a cached touch policy, cribbed from
# https://github.com/FiloSottile/yubikey-agent/issues/95#issuecomment-904101391

if ! command -v ykman >/dev/null 2>&1; then
  echo "Please install ykman"
  echo "See: https://docs.yubico.com/software/yubikey/tools/ykman/Install_ykman.html"
  exit
fi

set -e

PIN=${PIN:-000000}

read -rp "THIS WILL RESET YOUR YUBIKEY WITH PIN=$PIN, type "CTRL+C" to cancel"

# Reset PIV module
ykman piv reset -f

# Using PIN $PIN just for the sake of example, ofc.
ykman piv access change-pin -P 123456 -n "$PIN"
# Set the same PUK
ykman piv access change-puk -p 12345678 -n "$PIN"
# Store management key on the device, protect by pin
ykman piv access change-management-key -P "$PIN" -p

# Generate a key in slot 9a
ykman piv keys generate --pin="$PIN" -a ECCP256 --pin-policy=ONCE --touch-policy=CACHED 9a /var/tmp/pkey.pub
# Generate cert
ykman piv certificates generate --subject="CN=SSH Name+O=yubikey-agent+OU=0.1.5" --valid-days=10950 9a /var/tmp/pkey.pub

# Read the public key and use it as you normally would
ssh-add -L
