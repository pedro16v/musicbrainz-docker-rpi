#!/bin/bash

echo "=== MusicBrainz Replication Token Setup for ARM64 ==="
echo
echo "To enable replication on your Raspberry Pi, you need a MetaBrainz access token."
echo
echo "Steps to get your token:"
echo "1. Go to: https://metabrainz.org/account/applications"
echo "2. Log in with your MetaBrainz account (create one if needed)"
echo "3. Create a new application or use an existing one"
echo "4. Copy the 40-character access token"
echo
echo "Then run this on your Raspberry Pi:"
echo "  cd /mnt/storage/mbz-docker-rpi"
echo "  ./admin/set-replication-token"
echo
echo "Or manually create the token file:"
echo "  echo 'YOUR_40_CHAR_TOKEN_HERE' > local/secrets/metabrainz_access_token"
echo "  chmod 600 local/secrets/metabrainz_access_token"
echo
echo "After setting the token, you can start replication with:"
echo "  docker compose up -d"
echo "  docker compose exec musicbrainz replication.sh"
echo
