# Start by building the application.
FROM maven:3-eclipse-temurin-17 as build
WORKDIR /app

COPY  pom.xml pom.xml
RUN mvn dependency:resolve

COPY src ./src
RUN mvn verify -Dmaven.test.skip

FROM eclipse-temurin:17 as final
WORKDIR /app

# supervisor
RUN apt-get -qqy update \
  && apt-get -qqy --no-install-recommends install \
  supervisor \
  && rm -rf /var/lib/apt/lists/* /var/cache/apt/*

# Postgresql
RUN set -eux; \
  groupadd -r postgres --gid=999; \
  # https://salsa.debian.org/postgresql/postgresql-common/blob/997d842ee744687d99a2b2d95c1083a2615c79e8/debian/postgresql-common.postinst#L32-35
  useradd -r -g postgres --uid=999 --home-dir=/var/lib/postgresql --shell=/bin/bash postgres; \
  # also create the postgres user's home directory with appropriate permissions
  # see https://github.com/docker-library/postgres/issues/274
  mkdir -p /var/lib/postgresql; \
  chown -R postgres:postgres /var/lib/postgresql
RUN set -ex; \
  apt-get update; \
  apt-get install -y --no-install-recommends \
  gnupg \
  ; \
  rm -rf /var/lib/apt/lists/*

# grab gosu for easy step-down from root
# https://github.com/tianon/gosu/releases
ENV GOSU_VERSION 1.16
RUN set -eux; \
  savedAptMark="$(apt-mark showmanual)"; \
  apt-get update; \
  apt-get install -y --no-install-recommends ca-certificates wget; \
  rm -rf /var/lib/apt/lists/*; \
  dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
  wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"; \
  wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc"; \
  export GNUPGHOME="$(mktemp -d)"; \
  gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4; \
  gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu; \
  gpgconf --kill all; \
  rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc; \
  apt-mark auto '.*' > /dev/null; \
  [ -z "$savedAptMark" ] || apt-mark manual $savedAptMark > /dev/null; \
  apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
  chmod +x /usr/local/bin/gosu; \
  gosu --version; \
  gosu nobody true

# make the "en_US.UTF-8" locale so postgres will be utf-8 enabled by default
RUN set -eux; \
  if [ -f /etc/dpkg/dpkg.cfg.d/docker ]; then \
  # if this file exists, we're likely in "debian:xxx-slim", and locales are thus being excluded so we need to remove that exclusion (since we need locales)
  grep -q '/usr/share/locale' /etc/dpkg/dpkg.cfg.d/docker; \
  sed -ri '/\/usr\/share\/locale/d' /etc/dpkg/dpkg.cfg.d/docker; \
  ! grep -q '/usr/share/locale' /etc/dpkg/dpkg.cfg.d/docker; \
  fi; \
  apt-get update; apt-get install -y --no-install-recommends locales; rm -rf /var/lib/apt/lists/*; \
  localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.utf8

RUN set -eux; \
  apt-get update; \
  apt-get install -y --no-install-recommends \
  libnss-wrapper \
  xz-utils \
  zstd \
  ; \
  rm -rf /var/lib/apt/lists/*

RUN mkdir /docker-entrypoint-initdb.d

RUN set -ex; \
  # pub   4096R/ACCC4CF8 2011-10-13 [expires: 2019-07-02]
  #       Key fingerprint = B97B 0AFC AA1A 47F0 44F2  44A0 7FCC 7D46 ACCC 4CF8
  # uid                  PostgreSQL Debian Repository
  key='B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8'; \
  export GNUPGHOME="$(mktemp -d)"; \
  mkdir -p /usr/local/share/keyrings/; \
  gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "$key"; \
  gpg --batch --export --armor "$key" > /usr/local/share/keyrings/postgres.gpg.asc; \
  gpgconf --kill all; \
  rm -rf "$GNUPGHOME"

ENV PG_MAJOR 14
ENV PATH $PATH:/usr/lib/postgresql/$PG_MAJOR/bin

ENV PG_VERSION 14.8-1.pgdg22.04+1

RUN set -ex; \
  \
  # see note below about "*.pyc" files
  export PYTHONDONTWRITEBYTECODE=1; \
  \
  dpkgArch="$(dpkg --print-architecture)"; \
  aptRepo="[ signed-by=/usr/local/share/keyrings/postgres.gpg.asc ] http://apt.postgresql.org/pub/repos/apt/ jammy-pgdg main $PG_MAJOR"; \
  case "$dpkgArch" in \
  amd64 | arm64 | ppc64el | s390x) \
  # arches officialy built by upstream
  echo "deb $aptRepo" > /etc/apt/sources.list.d/pgdg.list; \
  apt-get update; \
  ;; \
  *) \
  # we're on an architecture upstream doesn't officially build for
  # let's build binaries from their published source packages
  echo "deb-src $aptRepo" > /etc/apt/sources.list.d/pgdg.list; \
  \
  savedAptMark="$(apt-mark showmanual)"; \
  \
  tempDir="$(mktemp -d)"; \
  cd "$tempDir"; \
  \
  # create a temporary local APT repo to install from (so that dependency resolution can be handled by APT, as it should be)
  apt-get update; \
  apt-get install -y --no-install-recommends dpkg-dev; \
  echo "deb [ trusted=yes ] file://$tempDir ./" > /etc/apt/sources.list.d/temp.list; \
  _update_repo() { \
  dpkg-scanpackages . > Packages; \
  # work around the following APT issue by using "Acquire::GzipIndexes=false" (overriding "/etc/apt/apt.conf.d/docker-gzip-indexes")
  #   Could not open file /var/lib/apt/lists/partial/_tmp_tmp.ODWljpQfkE_._Packages - open (13: Permission denied)
  #   ...
  #   E: Failed to fetch store:/var/lib/apt/lists/partial/_tmp_tmp.ODWljpQfkE_._Packages  Could not open file /var/lib/apt/lists/partial/_tmp_tmp.ODWljpQfkE_._Packages - open (13: Permission denied)
  apt-get -o Acquire::GzipIndexes=false update; \
  }; \
  _update_repo; \
  \
  # build .deb files from upstream's source packages (which are verified by apt-get)
  nproc="$(nproc)"; \
  export DEB_BUILD_OPTIONS="nocheck parallel=$nproc"; \
  # we have to build postgresql-common first because postgresql-$PG_MAJOR shares "debian/rules" logic with it: https://salsa.debian.org/postgresql/postgresql/-/commit/99f44476e258cae6bf9e919219fa2c5414fa2876
  # (and it "Depends: pgdg-keyring")
  apt-get build-dep -y postgresql-common pgdg-keyring; \
  apt-get source --compile postgresql-common pgdg-keyring; \
  _update_repo; \
  apt-get build-dep -y "postgresql-$PG_MAJOR=$PG_VERSION"; \
  apt-get source --compile "postgresql-$PG_MAJOR=$PG_VERSION"; \
  \
  # we don't remove APT lists here because they get re-downloaded and removed later
  \
  # reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
  # (which is done after we install the built packages so we don't have to redownload any overlapping dependencies)
  apt-mark showmanual | xargs apt-mark auto > /dev/null; \
  apt-mark manual $savedAptMark; \
  \
  ls -lAFh; \
  _update_repo; \
  grep '^Package: ' Packages; \
  cd /; \
  ;; \
  esac; \
  \
  apt-get install -y --no-install-recommends postgresql-common; \
  sed -ri 's/#(create_main_cluster) .*$/\1 = false/' /etc/postgresql-common/createcluster.conf; \
  apt-get install -y --no-install-recommends \
  "postgresql-$PG_MAJOR=$PG_VERSION" \
  ; \
  \
  rm -rf /var/lib/apt/lists/*; \
  \
  if [ -n "$tempDir" ]; then \
  # if we have leftovers from building, let's purge them (including extra, unnecessary build deps)
  apt-get purge -y --auto-remove; \
  rm -rf "$tempDir" /etc/apt/sources.list.d/temp.list; \
  fi; \
  \
  # some of the steps above generate a lot of "*.pyc" files (and setting "PYTHONDONTWRITEBYTECODE" beforehand doesn't propagate properly for some reason), so we clean them up manually (as long as they aren't owned by a package)
  find /usr -name '*.pyc' -type f -exec bash -c 'for pyc; do dpkg -S "$pyc" &> /dev/null || rm -vf "$pyc"; done' -- '{}' +; \
  \
  postgres --version

# make the sample config easier to munge (and "correct by default")
RUN set -eux; \
  dpkg-divert --add --rename --divert "/usr/share/postgresql/postgresql.conf.sample.dpkg" "/usr/share/postgresql/$PG_MAJOR/postgresql.conf.sample"; \
  cp -v /usr/share/postgresql/postgresql.conf.sample.dpkg /usr/share/postgresql/postgresql.conf.sample; \
  ln -sv ../postgresql.conf.sample "/usr/share/postgresql/$PG_MAJOR/"; \
  sed -ri "s!^#?(listen_addresses)\s*=\s*\S+.*!\1 = '*'!" /usr/share/postgresql/postgresql.conf.sample; \
  grep -F "listen_addresses = '*'" /usr/share/postgresql/postgresql.conf.sample

RUN mkdir -p /var/run/postgresql && chown -R postgres:postgres /var/run/postgresql && chmod 2777 /var/run/postgresql

ENV PGDATA /var/lib/postgresql/data
# this 777 will be replaced by 700 at runtime (allows semi-arbitrary "--user" values)
RUN mkdir -p "$PGDATA" && chown -R postgres:postgres "$PGDATA" && chmod 777 "$PGDATA"
VOLUME /var/lib/postgresql/data


COPY conf/entry_point.sh conf/start-app.sh conf/docker-entrypoint.sh /opt/bin/
COPY conf/supervisord.conf /etc
COPY conf/app.conf /etc/supervisor/conf.d/
COPY --from=build /app/target/app.jar /app/app.jar
COPY docker-entrypoint-initdb.d /docker-entrypoint-initdb.d

ENV POSTGRES_PASSWORD=pass
ENV POSTGRES_USER=app
ENV POSTGRES_DB=db
ENV JDBC_URL=jdbc:postgresql://localhost:5432/db?user=app&password=pass

EXPOSE 8080
EXPOSE 5432

CMD ["/opt/bin/entry_point.sh"]
HEALTHCHECK --interval=5m --timeout=3s \
  CMD curl -f localhost:8080/actuator/health || exit 1