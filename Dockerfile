# OpenHost darkhttpd container.
#
# Smallest possible "serve a directory of HTML files" app on
# OpenHost.  darkhttpd is a single tiny C binary (~50 KiB)
# with one job: serve a directory tree as a static website.
# No CGI, no scripts, no auth, no .htaccess parsing — exactly
# the right primitive for "I have HTML and I want a URL."
#
# Authoring flow: operator SSHes into the OpenHost host and
# drops files into
#   .openhost/.../persistent_data/app_data/darkhttpd/www/
# darkhttpd picks them up on the next request without
# restart (it stats the file system per request, no caching
# layer to invalidate).
#
# Deploy flow: this image is rebuilt on `oh app deploy`.  The
# image itself carries no website content — the persistent
# data dir is the source of truth, so the same image can be
# rebuilt or moved between hosts without touching content.

# Alpine is the canonical base for this kind of tiny utility.
# Alpine 3.20 has darkhttpd in the main repo.
FROM docker.io/library/alpine:3.20

# Install darkhttpd and tini (init wrapper that reaps zombies
# and forwards signals correctly).  No other packages — the
# whole point is "minimal."
RUN apk add --no-cache darkhttpd tini

# Copy the entrypoint.  Committed at mode 0755 in git so the
# COPY preserves +x without needing a RUN chmod step.
COPY start.sh /opt/openhost-darkhttpd/start.sh

# Container port 8080.  We bind 0.0.0.0 because the OpenHost
# router connects to us via the container network, not via
# loopback.  No other ports are exposed.
EXPOSE 8080

# tini -- start.sh: tini reaps signals + zombies, start.sh
# does the actual launch.
ENTRYPOINT ["/sbin/tini", "--", "/opt/openhost-darkhttpd/start.sh"]
