#!/usr/bin/env bash
set -euo pipefail

# ID stays fedora, toolbox and third-party installers branch on it
sed -i \
    -e 's/^NAME=.*/NAME="fruppiOS"/' \
    -e 's/^PRETTY_NAME="Fedora Linux /PRETTY_NAME="fruppiOS /' \
    -e 's|^HOME_URL=.*|HOME_URL="https://github.com/trin94/fruppiOS"|' \
    -e 's|^BUG_REPORT_URL=.*|BUG_REPORT_URL="https://github.com/trin94/fruppiOS/issues"|' \
    /usr/lib/os-release

cat >>/usr/lib/os-release <<'EOF'
ID_LIKE=fedora
VARIANT="fruppiOS"
VARIANT_ID=fruppios
IMAGE_ID=fruppios
EOF
