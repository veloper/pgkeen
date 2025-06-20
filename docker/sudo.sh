#!/bin/sh

# -----------------------------------------------------------------------------
# Fake sudo shim for trunk builds
#
# Purpose:
#   This script acts as a fake 'sudo' command so that tools (like trunk)
#   which expect 'sudo' to be present do not fail during Docker builds
#   or in minimal environments where 'sudo' is not installed or needed.
#
#   It simply executes the given command as-is, without privilege escalation.
#
# Installation:
#   1. Place this script somewhere in your PATH before any real 'sudo'.
#      For example, in your Dockerfile:
#         COPY docker/sudo.sh /usr/local/bin/sudo
#         RUN chmod +x /usr/local/bin/sudo
#
#   2. Ensure /usr/local/bin is before /usr/bin in your PATH if a real sudo exists.
#
# Cleanup:
#   If you no longer need the fake sudo, simply remove it:
#      rm -f /usr/local/bin/sudo
#
#   Or, if you want to restore the real sudo, reinstall it via your package manager.
#
# -----------------------------------------------------------------------------

exec "$@"