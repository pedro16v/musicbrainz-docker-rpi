#!/bin/bash
# Verification script to check if REPLICATION_ACCESS_TOKEN is properly configured

echo "=== Verifying REPLICATION_ACCESS_TOKEN Configuration ==="
echo ""

# Check environment variable
echo "1. Environment variable check:"
if [ -n "$REPLICATION_ACCESS_TOKEN" ]; then
    token_len=${#REPLICATION_ACCESS_TOKEN}
    echo "   ✓ REPLICATION_ACCESS_TOKEN is set (length: $token_len)"
    echo "   Preview: ${REPLICATION_ACCESS_TOKEN:0:10}...${REPLICATION_ACCESS_TOKEN: -10}"
else
    echo "   ✗ REPLICATION_ACCESS_TOKEN is NOT set in environment"
fi
echo ""

# Check DBDefs.pm file exists
echo "2. DBDefs.pm file check:"
if [ -f "/musicbrainz-server/lib/DBDefs.pm" ]; then
    echo "   ✓ /musicbrainz-server/lib/DBDefs.pm exists"
else
    echo "   ✗ /musicbrainz-server/lib/DBDefs.pm NOT found"
    exit 1
fi
echo ""

# Check if token is in DBDefs.pm
echo "3. Token in DBDefs.pm check:"
if grep -q "sub REPLICATION_ACCESS_TOKEN" /musicbrainz-server/lib/DBDefs.pm; then
    echo "   ✓ REPLICATION_ACCESS_TOKEN subroutine found"
    echo ""
    echo "   Content:"
    grep -A 2 "sub REPLICATION_ACCESS_TOKEN" /musicbrainz-server/lib/DBDefs.pm | sed 's/^/   /'
else
    echo "   ✗ REPLICATION_ACCESS_TOKEN subroutine NOT found"
fi
echo ""

# Try to load and check the value using Perl
echo "4. Perl verification:"
perl -I/musicbrainz-server/lib -MDBDefs -e '
use strict;
use warnings;

my $token = eval { DBDefs->REPLICATION_ACCESS_TOKEN };
if ($@) {
    print "   ✗ Error loading token: $@\n";
    exit 1;
}

if (defined $token && $token ne "" && $token ne "YOUR_TOKEN_HERE") {
    my $len = length($token);
    my $preview = substr($token, 0, 10) . "..." . substr($token, -10);
    print "   ✓ Token loaded successfully (length: $len)\n";
    print "   Preview: $preview\n";
} else {
    print "   ✗ Token is empty or placeholder\n";
    print "   Value: " . (defined $token ? "\"$token\"" : "undefined") . "\n";
    exit 1;
}
'

if [ $? -eq 0 ]; then
    echo ""
    echo "=== All checks passed! Token is properly configured ==="
else
    echo ""
    echo "=== Configuration issue detected ==="
    exit 1
fi