#!/bin/sh
# Builds and runs the database publishing tool (tools/dbtool/main.swift) with
# the app's own validator and signature check compiled in.
#   tools/dbtool.sh keygen --public-out Saklolo/Resources/database-public-key.txt
#   tools/dbtool.sh sign path/to/database.json
#   tools/dbtool.sh verify database/database.json database/database.json.sig Saklolo/Resources/database-public-key.txt
# See docs/DATABASE-UPDATES.md.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
build=$(mktemp -d "${TMPDIR:-/tmp}/dbtool.XXXXXX")
trap 'rm -rf "$build"' EXIT

xcrun swiftc -O -o "$build/dbtool" \
    "$root/tools/dbtool/main.swift" \
    "$root/Saklolo/Services/Database/DatabaseValidator.swift" \
    "$root/Saklolo/Services/Database/DatabaseSignature.swift" 2>"$build/errors" \
    || { cat "$build/errors" >&2; exit 1; }

DBTOOL_REPO_ROOT="$root" "$build/dbtool" "$@"
