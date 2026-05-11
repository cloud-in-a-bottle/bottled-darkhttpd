#!/bin/sh
# Launch darkhttpd on OpenHost.
#
# darkhttpd is a single-process static file server.  We point it
# at $OPENHOST_APP_DATA_DIR/www and bind 0.0.0.0:8080.  No
# auth-proxy, no sidecar, no supervision needed — if darkhttpd
# dies, the container exits and OpenHost restarts it.
#
# We use /bin/sh (alpine's busybox ash) deliberately: this start
# script is short enough that we don't need bash, and avoiding
# bash keeps the image small.

set -eu

PERSIST="${OPENHOST_APP_DATA_DIR:-/data/app_data/darkhttpd}"
WWW_DIR="$PERSIST/www"

mkdir -p "$WWW_DIR"

# Drop a placeholder index.html on first boot so anyone hitting
# the public URL before the operator uploads content gets a
# friendly hint instead of an opaque 404.  We only write it if
# the dir is empty — never clobber existing content.
if [ -z "$(ls -A "$WWW_DIR" 2>/dev/null)" ]; then
    cat > "$WWW_DIR/index.html" <<'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>openhost-darkhttpd</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 640px; margin: 4rem auto; padding: 0 1rem; color: #333; }
    code { background: #f4f4f4; padding: 2px 6px; border-radius: 3px; }
    pre  { background: #f4f4f4; padding: 1rem; border-radius: 4px; overflow-x: auto; }
  </style>
</head>
<body>
  <h1>Hello from darkhttpd</h1>
  <p>This is the placeholder page.  Replace it with your own content by SSHing into the OpenHost host and dropping files into the persistent data dir:</p>
  <pre>cd ~/.openhost/local_compute_space/persistent_data/app_data/darkhttpd/www/
rm index.html
cp -r /path/to/your/site/* .</pre>
  <p>Changes are picked up on the next request — no restart needed.</p>
</body>
</html>
HTML
    echo "[start.sh] First boot: wrote placeholder index.html"
fi

# darkhttpd flags:
#   --port 8080          listen port
#   --addr 0.0.0.0       bind on all interfaces (the container
#                        network; not exposed off-host)
#   --no-listing         do NOT show a directory listing when a
#                        directory has no index.html.  Without
#                        this flag darkhttpd would auto-list any
#                        sub-directory of /www, which leaks the
#                        file layout to anonymous visitors.
#   --chroot             chroot into /www after binding — defense
#                        in depth so a path-traversal bug in
#                        darkhttpd can't reach /etc/passwd or the
#                        container filesystem.
#   --uid + --gid        drop privilege after the bind+chroot.
#                        The 'nobody' user/group exists in alpine
#                        by default (UID 65534).  Both --uid and
#                        --gid take *names* (not numeric IDs) on
#                        most darkhttpd builds.
#   --log /dev/stderr    log access lines to container logs so
#                        operators can see traffic via
#                        `oh app logs darkhttpd`.
#
# We pass /www (post-chroot) as the document root.  After --chroot
# darkhttpd treats /www as the new filesystem root, so URL paths
# like /index.html resolve to <real $WWW_DIR>/index.html.

echo "[start.sh] Starting darkhttpd on 0.0.0.0:8080 -> $WWW_DIR"
exec darkhttpd "$WWW_DIR" \
    --port 8080 \
    --addr 0.0.0.0 \
    --no-listing \
    --chroot \
    --uid nobody \
    --gid nobody \
    --log /dev/stderr
