ARG UNLIGHT_HOME=/opt/unlight
ARG RUBY_VERSION=3.2.2

# Pre-compile Gems
FROM ruby:${RUBY_VERSION}-alpine AS gem

RUN apk --update \
        add --no-cache \
        build-base \
        ca-certificates \
        zlib-dev \
        openssl-dev \
        mariadb-dev \
        mariadb-client

# Setup Application
ARG UNLIGHT_HOME
ENV UNLIGHT_HOME=${UNLIGHT_HOME}

RUN mkdir -p $UNLIGHT_HOME
WORKDIR $UNLIGHT_HOME

COPY Gemfile* $UNLIGHT_HOME/
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]
RUN gem install bundler:2.2.28 \
    && bundle config --local deployment 'true' \
    && bundle config --local frozen 'true' \
    && bundle config --local no-cache 'true' \
    && bundle config --local system 'true' \
    && bundle config --local without 'build development test' \
    && bundle install -j "$(getconf _NPROCESSORS_ONLN)" \
    && find /${UNLIGHT_HOME}/vendor/bundle -type f -name '*.c' -delete \
    && find /${UNLIGHT_HOME}/vendor/bundle -type f -name '*.o' -delete \
    && find /${UNLIGHT_HOME}/vendor/bundle -type d -name 'spec' -print0 | xargs -0 rm -rf \
    && find /${UNLIGHT_HOME}/vendor/bundle -type d -name 'tests' -print0 | xargs -0 rm -rf \
    # Remove unnecessary asc files in mysql gem
    && find /${UNLIGHT_HOME}/vendor/bundle -type f -name '*.asc' -delete \
    && find /${UNLIGHT_HOME}/vendor/bundle -type f -name 'Dockerfile*' -delete \
    && find /usr/local/bundle -type f -name '*.c' -delete \
    && find /usr/local/bundle -type f -name '*.o' -delete \
    && rm -rf /usr/local/bundle/cache/*.gem

# Server
FROM ruby:${RUBY_VERSION}-alpine

RUN apk --update \
        add --no-cache \
        gcc \
        libc-dev \
        ca-certificates \
        zlib \
        mariadb-connector-c

ARG UNLIGHT_HOME
ENV UNLIGHT_HOME=${UNLIGHT_HOME}
ENV RUBY_INLINE_DIR=${UNLIGHT_HOME}/lib/ruby_inline

# Setup Application
RUN mkdir -p $UNLIGHT_HOME \
    && mkdir -p $UNLIGHT_HOME/tmp/pids \
    && mkdir -p $UNLIGHT_HOME/backup

COPY --from=gem /usr/local/bundle/config /usr/local/bundle/config
COPY --from=gem /usr/local/bundle /usr/local/bundle
COPY --from=gem /${UNLIGHT_HOME}/vendor/bundle /${UNLIGHT_HOME}/vendor/bundle

# Add Source Files
COPY . $UNLIGHT_HOME

# Apply Execute Permission
RUN adduser -h ${UNLIGHT_HOME} -D -s /bin/nologin unlight unlight && \
    mkdir -p $RUBY_INLINE_DIR && \
    chown unlight:unlight $UNLIGHT_HOME && \
    chown -R unlight:unlight $RUBY_INLINE_DIR && \
    chmod -R +rw $RUBY_INLINE_DIR && \
    chmod -R +r $UNLIGHT_HOME && \
    chmod -R +rx $UNLIGHT_HOME/bin

ENV DAWN_LOG_TO_STDOUT=true
ENV PATH $UNLIGHT_HOME/bin:$PATH

USER unlight
WORKDIR $UNLIGHT_HOME

ENTRYPOINT ["abyss"]
