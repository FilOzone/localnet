#!/bin/bash
set -e

cd "$( dirname -- "$BASH_SOURCE" )"

go run -tags 2k ./cmd/sector-notify
