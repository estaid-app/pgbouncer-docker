FROM alpine:3.19 as intermediate

# Setup arguments for the build
ARG REPO_URL=https://github.com/pgbouncer/pgbouncer.git
ARG TAG=1.21.0
ARG TAG_PREFIX=pgbouncer_

# Install build dependencies in a single RUN to reduce layers
RUN apk add -U --no-cache \
    autoconf \
    automake \
    libtool \
    pandoc \
    udns \
    udns-dev \
    curl \
    gcc \
    libc-dev \
    libevent \
    libevent-dev \
    make \
    openssl-dev \
    pkgconfig \
    postgresql-client \
    git \
    && rm -rf /var/cache/apk/*

# Clone the repository using the provided URL

RUN git clone ${REPO_URL} /workspace

WORKDIR /workspace

# Use the TAG_PREFIX+TARGET_TAG variable for checking out the correct tag
# Replace dots with underscores to match the tag naming convention
RUN git checkout ${TAG_PREFIX}${TAG//./_} && \
    git submodule update --init --recursive

# Combine compile commands to reduce layers
RUN ./autogen.sh && \
    ./configure --prefix=/usr/local --with-udns && \
    make && \
    make install

# Use the same base image as the final stage
FROM alpine:3.19 as final

# Install runtime dependencies in a single RUN to reduce layers
RUN apk add -U --no-cache \
    busybox \
    udns \
    libevent \
    postgresql-client \
    && rm -rf /var/cache/apk/*

# Copy the built binary from the intermediate stage
COPY --from=intermediate /usr/local/bin/pgbouncer /usr/local/bin/

# Prepare environment and data directory
RUN mkdir -p /app/data && \
    adduser -D -h /app runner && \
    chown -R runner:runner /app

# Switch to non-root user for better security
USER runner

# Expose default port in a variable form
ENV PGBOUNCER_PORT=5432
EXPOSE ${PGBOUNCER_PORT}

# Obscure the command as well
CMD ["/usr/local/bin/pgbouncer", "/app/data/pgbouncer.ini"]