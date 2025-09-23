# Minimal MusicBrainz container for replication scripts only - ARM64 compatible
FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive

# Install basic dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    postgresql-client \
    python3 \
    python3-pip \
    git \
    perl \
    libdbd-pg-perl \
    && rm -rf /var/lib/apt/lists/*

# Clone MusicBrainz server for replication scripts only
ARG MUSICBRAINZ_SERVER_VERSION=v-2025-08-11.0
RUN git clone --depth=1 --branch $MUSICBRAINZ_SERVER_VERSION https://github.com/metabrainz/musicbrainz-server.git /musicbrainz-server

WORKDIR /musicbrainz-server

# Copy minimal scripts
COPY scripts/* /usr/local/bin/
RUN chmod +x /usr/local/bin/*

# Environment variables for replication
ENV MUSICBRAINZ_POSTGRES_SERVER=db \
    MUSICBRAINZ_POSTGRES_READONLY_SERVER=db \
    POSTGRES_USER=musicbrainz \
    POSTGRES_PASSWORD=musicbrainz \
    MUSICBRAINZ_BASE_DOWNLOAD_URL=https://data.metabrainz.org/pub/musicbrainz

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["sleep", "infinity"]
