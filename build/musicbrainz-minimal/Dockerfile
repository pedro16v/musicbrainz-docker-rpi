# Minimal MusicBrainz container for replication scripts only - ARM64 compatible
FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive

# Install basic dependencies and Perl modules for replication
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    postgresql-client-14 \
    postgresql-client-common \
    libpq-dev \
    python3 \
    python3-pip \
    git \
    perl \
    libdbd-pg-perl \
    # Perl modules needed for MusicBrainz replication
    libstring-shellquote-perl \
    libhttp-message-perl \
    libwww-perl \
    liburi-perl \
    libjson-perl \
    libxml-libxml-perl \
    libxml-parser-perl \
    libgetopt-long-descriptive-perl \
    libmoose-perl \
    libnamespace-autoclean-perl \
    liblist-moreutils-perl \
    libdata-compare-perl \
    libdata-dumper-concise-perl \
    libtry-tiny-perl \
    libclass-load-perl \
    libfile-slurp-perl \
    libaliased-perl \
    libdatetime-perl \
    \
    libdatetime-timezone-perl \
     
    cpanminus \
    && rm -rf /var/lib/apt/lists/*

# Install additional Perl modules via CPAN that aren't in Ubuntu packages
RUN cpanm --notest --quiet \
    MusicBrainz::Server::Replication \
    Readonly \
    Cache::Memcached::Fast \
    JSON::XS \
    List::AllUtils \
    Throwable \
    DBIx::Connector \
    || echo "Some CPAN modules may not be available, will try with git clone"

# Clone MusicBrainz server for replication scripts only
ARG MUSICBRAINZ_SERVER_VERSION=v-2025-08-11.0
RUN git clone --depth=1 --branch $MUSICBRAINZ_SERVER_VERSION https://github.com/metabrainz/musicbrainz-server.git /musicbrainz-server

WORKDIR /musicbrainz-server

# Copy minimal scripts
# Copy a minimal DBDefs.pm for replication

# Copy minimal scripts
COPY scripts/* /usr/local/bin/
# Copy a minimal DBDefs.pm for replication
RUN cp /usr/local/bin/DBDefs.pm lib/DBDefs.pm
RUN chmod +x /usr/local/bin/*

# Environment variables for replication
ENV MUSICBRAINZ_POSTGRES_SERVER=db \
    MUSICBRAINZ_POSTGRES_READONLY_SERVER=db \
    POSTGRES_USER=musicbrainz \
    POSTGRES_PASSWORD=musicbrainz \
    MUSICBRAINZ_BASE_DOWNLOAD_URL=https://data.metabrainz.org/pub/musicbrainz

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["sleep", "infinity"]
