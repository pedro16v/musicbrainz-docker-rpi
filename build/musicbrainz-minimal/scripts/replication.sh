#!/bin/bash

# Simple replication script that calls the actual MusicBrainz replication
cd /musicbrainz-server

# Call the actual replication script from MusicBrainz
exec ./admin/replication/LoadReplicationChanges --verbose
