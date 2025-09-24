#!/usr/bin/env bash

set -e -o pipefail -u

DB_DUMP_DIR=/media/dbdump
BASE_FTP_URL=''
BASE_DOWNLOAD_URL="$MUSICBRAINZ_BASE_DOWNLOAD_URL"
TARGET=''
WGET_CMD=(wget)

SCRIPT_NAME=$(basename "$0")
HELP=$(cat <<EOH
Usage: $SCRIPT_NAME [<options>] <target>

Fetch dump files of the MusicBrainz Postgres database.
SAFE VERSION: Does not delete existing dump files.

Targets:
  replica       Fetch latest database's replicated tables only.
  sample        Fetch latest database's sample only.

Options:
  --base-download-url <url>     Specify URL of a MetaBrainz/MusicBrainz download server.
                                (Default: '$BASE_DOWNLOAD_URL')
  --base-ftp-url <url>          Specify URL of a MetaBrainz/MusicBrainz FTP server.
                                (Note: this option is deprecated and will be removed in a future release)
  --wget-options <wget options> Specify additional options to be passed to wget,
                                these should be separated with whitespace,
                                the list should be a single argument
                                (escape whitespaces if needed).

  -h, --help                    Print this help message and exit.
EOH
)

# Parse arguments

while [[ $# -gt 0 ]]
do
	case "$1" in
		--base-download-url )
			shift
			BASE_DOWNLOAD_URL="$1"
			;;
		--base-ftp-url )
			shift
			BASE_FTP_URL="$1"
			;;
		--wget-options )
			shift
			WGET_CMD+=($1)
			;;
		-h | --help )
			echo "$HELP"
			exit 0
			;;
		replica | sample )
			TARGET="$1"
			;;
		* )
			echo >&2 "$SCRIPT_NAME: unrecognized argument '$1'"
			echo >&2 "$HELP"
			exit 1
			;;
	esac
	shift
done

if [[ -z "$TARGET" ]]
then
	echo >&2 "$SCRIPT_NAME: missing target"
	echo >&2 "$HELP"
	exit 1
fi

if [[ -n "$BASE_FTP_URL" ]]
then
	echo >&2 "$SCRIPT_NAME: --base-ftp-url is deprecated, use --base-download-url instead"
	BASE_DOWNLOAD_URL="$BASE_FTP_URL"
fi

# Create directory if it doesn't exist
mkdir -p "$DB_DUMP_DIR"

# Check if dump files already exist
case "$TARGET" in
	replica )
		DB_DUMP_FILES=(
			mbdump.tar.bz2
			mbdump-cdstubs.tar.bz2
			mbdump-cover-art-archive.tar.bz2
			mbdump-event-art-archive.tar.bz2
			mbdump-derived.tar.bz2
			mbdump-stats.tar.bz2
			mbdump-wikidocs.tar.bz2
		)
		;;
	sample )
		DB_DUMP_FILES=(
			mbdump-sample.tar.xz
		)
		;;
esac

# Check if all required files exist
ALL_EXIST=true
for F in "${DB_DUMP_FILES[@]}"; do
	if [[ ! -f "$DB_DUMP_DIR/$F" ]]; then
		ALL_EXIST=false
		break
	fi
done

if [[ "$ALL_EXIST" == "true" ]]; then
	echo "$(date): All required dump files already exist, skipping download."
	echo "Existing files:"
	for F in "${DB_DUMP_FILES[@]}"; do
		echo "  - $F ($(du -h "$DB_DUMP_DIR/$F" | cut -f1))"
	done
	exit 0
fi

echo "$(date): Some dump files are missing, downloading..."

# Find latest database dump
"${WGET_CMD[@]}" -nd -nH -P "$DB_DUMP_DIR" \
	"${BASE_DOWNLOAD_URL}/$DB_DUMP_REMOTE_DIR/LATEST"
DUMP_TIMESTAMP=$(<"$DB_DUMP_DIR/LATEST")

echo "$(date): Latest dump timestamp: $DUMP_TIMESTAMP"

# Actually fetch database dump
if [[ $TARGET == replica ]]
then
	DB_DUMP_REMOTE_DIR=data/fullexport
	for F in MD5SUMS "${DB_DUMP_FILES[@]}"
	do
		if [[ ! -f "$DB_DUMP_DIR/$F" ]]; then
			echo "$(date): Downloading $F..."
			"${WGET_CMD[@]}" -c -P "$DB_DUMP_DIR" \
				"${BASE_DOWNLOAD_URL}/$DB_DUMP_REMOTE_DIR/$DUMP_TIMESTAMP/$F"
		else
			echo "$(date): $F already exists, skipping download."
		fi
	done
	
	echo "$(date): Checking MD5 sums..."
	cd "$DB_DUMP_DIR"
	for F in "${DB_DUMP_FILES[@]}"
	do
		echo -n "$F: "
		MD5SUM=$(md5sum -b "$F")
		if grep -Fqx "$MD5SUM" MD5SUMS
		then
			echo OK
		else
			echo FAILED
			echo >&2 "$0: unmatched MD5 checksum: $MD5SUM *$F"
			exit 70 # EX_SOFTWARE
		fi
	done
	cd - >/dev/null
elif [[ $TARGET == sample ]]
then
	DB_DUMP_REMOTE_DIR=data/sample
	for F in "${DB_DUMP_FILES[@]}"
	do
		if [[ ! -f "$DB_DUMP_DIR/$F" ]]; then
			echo "$(date): Downloading $F..."
			"${WGET_CMD[@]}" -c -P "$DB_DUMP_DIR" \
				"${BASE_DOWNLOAD_URL}/$DB_DUMP_REMOTE_DIR/$DUMP_TIMESTAMP/$F"
		else
			echo "$(date): $F already exists, skipping download."
		fi
	done
fi

echo "$(date): Done fetching dump files."
