#!/bin/sh
# Before each commit (the global git pre-commit hook runs it): the quick checks of tools/check.sh, the layer
# rules, the web interface's areas and the tickets (an audit due refuses the commit).
exec sh "$(dirname "$0")/check.sh" layers webimports tickets
