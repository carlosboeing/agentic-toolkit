#!/usr/bin/env bash
#
# Forwarder for backward compatibility; canonical entry point is scripts/sync-toolkit.sh
#
exec "$(dirname "${BASH_SOURCE[0]}")/../scripts/sync-toolkit.sh" --harness "$@"
