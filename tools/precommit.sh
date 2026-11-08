#!/bin/sh
# Before each commit (the global git pre-commit hook runs it): the quick checks of tools/check.sh, the layer
# rules and the web interface's areas.
exec sh "$(dirname "$0")/check.sh" layers webimports
