# openhost-darkhttpd

[darkhttpd](https://unix4lyfe.org/darkhttpd/) — a tiny single-binary HTTP
server for static files — packaged as the lightest possible "I have HTML,
give me a URL" app on OpenHost.

## What you get

- darkhttpd running on `https://darkhttpd.<zone>/`.
- Public: anyone on the internet who knows the URL can view the site.
- Content lives in `$OPENHOST_APP_DATA_DIR/www/` on the host filesystem.
  SSH in, drop files there, and they're live on the next request — no
  restart, no build step.
- ~64 MiB RAM footprint. ~50 KiB darkhttpd binary on top of Alpine.

## Authoring

```bash
ssh host@<zone>
cd ~/.openhost/local_compute_space/persistent_data/app_data/darkhttpd/www/

# Replace the placeholder:
rm index.html
cp -r /local/path/to/your/site/* .

# Or write directly:
cat > index.html <<'HTML'
<!DOCTYPE html>
<html><body><h1>Hi</h1></body></html>
HTML
```

Changes are visible on the very next HTTP request. darkhttpd stats the
filesystem per request; no in-memory cache to invalidate.

## Architecture

```
browser
   │
   ▼
OpenHost outer Caddy (TLS)
   │
   ▼
OpenHost router (public_paths = ["/"], no JWT check)
   │
   ▼
container :8080  darkhttpd (chroot'd to /www, --no-listing)
   │
   ▼
$OPENHOST_APP_DATA_DIR/www/...
```

## Security

- darkhttpd runs as `nobody` (UID 65534) after `--chroot $WWW_DIR`.
  A path traversal bug in darkhttpd cannot escape `/www`.
- `--no-listing` prevents directory enumeration. If you put a file in
  `/www/secret-folder/notes.txt` and there's no `/www/secret-folder/index.html`,
  visitors will get 404 for `/secret-folder/`, not a listing.
  Anyone who guesses the exact path can still read it though — this
  is a public webserver. Don't put real secrets in `/www`.
- The site IS public-by-default. To make it private (zone-owner only),
  edit `openhost.toml`, change `public_paths = ["/"]` to
  `public_paths = []`, and redeploy. The OpenHost router will then 302
  anonymous visitors to `/login`.

## When to use this

- Quick static landing page or marketing site.
- Hosted static documentation (built elsewhere and copied in).
- Old-school personal homepage / link-in-bio page.
- Quick proof of concept where you just need an HTML file at a URL.

## When NOT to use this

- You want a CMS where non-technical authors edit in a browser → look
  at openhost-outline (wiki) or similar.
- You want markdown source + a build step → look at openhost-hugo or
  openhost-mkdocs.
- You want server-side dynamic behaviour → wrong tool entirely; this
  serves static files only.
