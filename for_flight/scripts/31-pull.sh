#!/bin/sh
. "$(dirname "$0")/common.sh"
say "guix pull из локальных каналов (без подстановок)..."
guix pull --no-substitutes
G=$(pulled_guix)
"$G" --version | head -n1
say "PULL: OK -> $G"
