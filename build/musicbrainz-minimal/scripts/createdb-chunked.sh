#!/bin/bash

set -e -o pipefail -u

BASE_DOWNLOAD_URL="${MUSICBRAINZ_BASE_FTP_URL:-$MUSICBRAINZ_BASE_DOWNLOAD_URL}"
IMPORT="fullexport"
FETCH_DUMPS=""
WGET_OPTIONS=""
CHUNK_SIZE="${MUSICBRAINZ_IMPORT_CHUNK_SIZE:-1000}"

HELP=$(cat <<EOH
Usage: $0 [-wget-opts <options list>] [-sample] [-fetch] [-chunk-size <size>] [MUSICBRAINZ_BASE_DOWNLOAD_URL]

Options:
  -fetch      Fetch latest dump from MusicBrainz download server
  -sample     Load sample data instead of full data
  -chunk-size Set chunk size for import (default: 1000)
  -wget-opts  Pass additional space-separated options list (should be
              a single argument, escape spaces if necessary) to wget

Default MusicBrainz base download URL: $BASE_DOWNLOAD_URL
EOH
)

if [ $# -gt 6 ]; then
    echo "$0: too many arguments"
    echo "$HELP"
    exit 1
fi

while [ $# -gt 0 ]; do
    case "$1" in
        -wget-opts )
            shift
            WGET_OPTIONS=$1
            ;;
        -sample )
            IMPORT="sample"
            ;;
        -fetch  )
            FETCH_DUMPS="$1"
            ;;
        -chunk-size )
            shift
            CHUNK_SIZE=$1
            ;;
        -*      )
            echo "$0: unrecognized option '$1'"
            echo "$HELP"
            exit 1
            ;;
        *       )
            BASE_DOWNLOAD_URL="$1"
            ;;
    esac
    shift
done

TMP_DIR=/media/dbdump/tmp

case "$IMPORT" in
    fullexport  )
        DUMP_FILES=(
            mbdump.tar.bz2
            mbdump-cdstubs.tar.bz2
            mbdump-cover-art-archive.tar.bz2
            mbdump-event-art-archive.tar.bz2
            mbdump-derived.tar.bz2
            mbdump-stats.tar.bz2
            mbdump-wikidocs.tar.bz2
        );;
    sample      )
        DUMP_FILES=(
            mbdump-sample.tar.xz
        );;
esac

if [[ $FETCH_DUMPS == "-fetch" ]]; then
    FETCH_OPTIONS=("${IMPORT/fullexport/replica}" --base-download-url "$BASE_DOWNLOAD_URL")
    if [[ -n "$WGET_OPTIONS" ]]; then
        FETCH_OPTIONS+=(--wget-options "$WGET_OPTIONS")
    fi
    fetch-dump.sh "${FETCH_OPTIONS[@]}"
fi

for F in "${DUMP_FILES[@]}"; do
    if ! [[ -a "/media/dbdump/$F" ]]; then
        echo "$0: The dump '$F' is missing"
        exit 1
    fi
done

echo "Found existing dumps"

# Wait for database to be ready
until pg_isready -h ${MUSICBRAINZ_POSTGRES_SERVER:-db} -p ${MUSICBRAINZ_POSTGRES_PORT:-5432} -U ${POSTGRES_USER:-musicbrainz}; do
    echo "Waiting for database to be ready..."
    sleep 2
done

mkdir -p $TMP_DIR
cd /media/dbdump

INITDB_OPTIONS='--echo --import'
if ! psql -h ${MUSICBRAINZ_POSTGRES_SERVER:-db} -p ${MUSICBRAINZ_POSTGRES_PORT:-5432} -U ${POSTGRES_USER:-musicbrainz} -d postgres -c "SELECT 1 FROM pg_database WHERE datname='musicbrainz_db';" | grep -q 1; then
    INITDB_OPTIONS="--createdb $INITDB_OPTIONS"
fi

# Set up environment for InitDb.pl
export MUSICBRAINZ_POSTGRES_SERVER=${MUSICBRAINZ_POSTGRES_SERVER:-db}
export MUSICBRAINZ_POSTGRES_PORT=${MUSICBRAINZ_POSTGRES_PORT:-5432}
export MUSICBRAINZ_POSTGRES_DATABASE=${MUSICBRAINZ_POSTGRES_DATABASE:-musicbrainz_db}
export MUSICBRAINZ_POSTGRES_USERNAME=${POSTGRES_USER:-musicbrainz}
export MUSICBRAINZ_POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-musicbrainz}

# Monitor memory usage during import
monitor_memory() {
    while true; do
        echo "$(date): Memory usage: $(free -h | grep '^Mem:' | awk '{print $3 "/" $2 " (" $3*100/$2 "%)"}')"
        echo "$(date): Swap usage: $(free -h | grep '^Swap:' | awk '{print $3 "/" $2 " (" $3*100/$2 "%)"}')"
        sleep 30
    done
}

# Start memory monitoring in background
monitor_memory &
MONITOR_PID=$!

# Function to cleanup monitor on exit
cleanup() {
    kill $MONITOR_PID 2>/dev/null || true
}
trap cleanup EXIT

echo "Starting chunked import with chunk size: $CHUNK_SIZE"
echo "Memory monitoring started (PID: $MONITOR_PID)"

# Run InitDb.pl with chunked import
cd /media/dbdump
perl /musicbrainz-server/admin/InitDb.pl $INITDB_OPTIONS -- --skip-editor --tmp-dir $TMP_DIR --chunk-size $CHUNK_SIZE "${DUMP_FILES[@]}"

echo "Import completed successfully"
