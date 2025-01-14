#!/bin/bash
set -euo pipefail
./tpp-backend/manage.sh
# run again to check for idempotency
./tpp-backend/manage.sh

grep -q SimonDavy@OPENCORONA ~bloodearnest/.ssh/authorized_keys

# run release-hatch tests
./tests/check-release-hatch
