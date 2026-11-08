# couchpotato-for-tos

> TerraMaster TOS 7 App Center — **Docker application** package for
> [CouchPotato](https://github.com/CouchPotato/CouchPotatoServer), built for
> **x86_64 and aarch64**.

## What this is

A four-file TOS Docker application archive that installs CouchPotato on TOS 7
through the App Center. Because a TOS Docker application cannot declare more
than one architecture, the release carries **one archive per architecture**:

| Architecture | Archive |
|---|---|
| `x86_64` | `couchpotatodocker_x86_64.tar.gz` |
| `aarch64` | `couchpotatodocker_aarch64.tar.gz` |

Each archive contains exactly:

- `config.ini` — TOS application metadata (`application_type: docker`, id `couchpotatodocker`, `platform` = the archive's architecture)
- `couchpotatodocker.lang` — 23-language superset (TOS requires 14)
- `couchpotatodocker.svg` — application icon (1.4 KB, 19 SVG elements)
- `docker-compose.yml` — one service, image `linuxserver/couchpotato:7260c12f-ls82`

The two archives differ only in `config.ini.platform`; the container image is
multi-architecture on Docker Hub and resolves to the host's architecture.

## How it works

| | |
|---|---|
| Container image | `linuxserver/couchpotato:7260c12f-ls82` (Docker Hub, used unmodified) |
| Open | `http://<NAS-IP>:8005/` (container port 5050) |
| Runs as | non-root, `user: "1000:1000"` |
| Persistent data | `/config` → `/Volume1/DockerAppData/couchpotatodocker/config`, `/downloads` → `/Volume1/DockerAppData/couchpotatodocker/downloads` |
| Logs | `docker logs couchpotatodocker` (stdout/stderr), plus `config/data/logs/` |

Two volumes hold everything CouchPotato writes: `config/` with `config.ini` (all
settings, the API key and the indexer/downloader configuration) and `data/`
(SQLite database, logs, artwork cache, custom plugins), plus `downloads/` for
the files CouchPotato fetches. Copying the `couchpotatodocker` folder is
therefore a complete backup.

## Design highlights

- **Non-root.** `user: "1000:1000"`; verified on real hardware (the container
  reports uid 1000).
- **Entrypoint wrapper** (not a privilege shim): the image's s6 init cannot run
  without root, so `src/entrypoint.sh` skips it and starts the bundled
  CouchPotato Python 2 application directly as the unprivileged container user.
- **Fixed image tag `7260c12f-ls82`**, Docker Hub only, no `privileged`, no
  `network_mode: host`, no `cap_add`, no Docker socket.
- **Two explicit volumes**: `/config` (settings and database) and `/downloads`
  (fetched files), both below `/Volume1/DockerAppData/couchpotatodocker/`.
- **Health check** on the UI itself (`GET /` on port 5050) with a 90 s start
  period for the first database initialisation.
- **Deterministic build**: GNU tar with uid/gid 0 and zeroed timestamps, gzip
  without a timestamp, plus the review-standards self-check below.

## Runtime file manifest

Everything the application writes on the NAS lives inside its own data
directory; the container-internal `/tmp` is discarded with the container. The
table lists what is created and how it behaves. Nothing else is written.

| Path | Purpose | Created when | Growth bound | Lifecycle |
|---|---|---|---|---|
| `config/config.ini` | all settings - core options, API key, indexers, downloaders, renamer rules | first start | static, rewritten on every settings change | never overwritten by the app; keep it, it is the whole configuration |
| `config/data/database` | SQLite database with the wanted list, movie metadata and release history | first start | grows with the size of the wanted list | managed by CouchPotato; back it up before uninstalling with data removal |
| `config/data/logs` | CouchPotato log files | first start | one file per day; CouchPotato rotates them | safe to delete |
| `config/data/cache` | cached artwork and indexer responses | first start | bounded by the cache settings of the app | safe to delete; it is rebuilt on demand |
| `config/data/custom_plugins` | optional third-party plugins dropped in by the user | first start (empty) | only what the user adds | never touched by the app |
| `downloads` | files fetched by CouchPotato before renaming | on the first download | grows with every movie | managed by CouchPotato; move finished files out to free space |

## Build

```bash
scripts/build-all.sh              # -> out/couchpotatodocker_{x86_64,aarch64}.tar.gz
scripts/build-all.sh 3.0.1-2     # packaging iteration bump, both architectures
```

`scripts/build-all.sh` runs the single-architecture `scripts/build.sh` once per
architecture declared in `tosapp.json` (`platforms`), keeps the architecture
suffix in the file name, and runs the official `TOSAppSelfTestingTool -c` check
on every archive before writing it to `out/`.

Each build stages the four files, substitutes the version/platform placeholders,
embeds `src/entrypoint.sh` into the compose file (escaping every `$` as `$$`),
removes CRLF/BOM/AppleDouble, then runs `tools/verify.py`, a review-standards
self-check (archive layout, JSON validity, required fields, 14+ language
coverage, version consistency, Docker-Hub-only images, fixed tag,
reserved/recommended host ports, non-root user, per-service healthcheck/TZ/restart,
data path below the application data root, never the `/Volume*` wildcard,
comment-free sequence blocks, `x-app-meta` position, no literal secrets and the
SVG size/element limits).

## Local verification

```bash
./TOSAppSelfTestingTool -c out/couchpotatodocker_x86_64.tar.gz    # official spec check
bash test/install-and-verify.sh out/couchpotatodocker_x86_64.tar.gz  # on-device E2E (root)
```

The x86_64 archive was installed on a real TOS 7 NAS with the official testing
tool and passed the 21 end-to-end assertions (health, non-root, single published
port, volume ownership, container write access, HTTP, restart, uninstall/reinstall
data retention). The aarch64 archive is byte-identical apart from
`config.ini.platform` and was validated with the official `-c` check; it needs an
ARM TOS device for an on-device run.

> Docker applications cannot be side-loaded through the App Center's manual
> install page (it accepts `.deb` only); the official self-testing tool's `-i`
> mode or `docker compose` are the only ways to install one for testing.

## Store submission checklist

1. Public GitHub repo (code + README only).
2. Release **tag `v3.0.1-1`** with four assets:
   `couchpotatodocker_x86_64.tar.gz`, `couchpotatodocker_x86_64.tar.gz.sha256`,
   `couchpotatodocker_aarch64.tar.gz`, `couchpotatodocker_aarch64.tar.gz.sha256`.
3. Developer platform → Add Application **twice**, same ID `couchpotatodocker`:
   architecture `x86_64` and architecture `aarch64`, package type Docker,
   repository URL `https://github.com/Moechz/couchpotato`.
4. In each application: Version Management → Add Version `3.0.1-1`, pointing at
   the archive of that architecture → automated validation → review.

## License / branding

CouchPotato is distributed by its upstream authors under **GPL-3.0**. The
container image is the LinuxServer.io image from Docker Hub
(`linuxserver/couchpotato:7260c12f-ls82`) and is used unmodified; no upstream
source code is redistributed here. This packaging is an independent community
submission by Moechz and is not affiliated with the upstream project, LinuxServer.io
or TerraMaster. The icon is a generic film/play mark drawn for this package; it
does not use the CouchPotato logo.

## Limitations

- CouchPotato is legacy software: upstream stopped in 2021 and the image was last
  built in March 2022. It receives no security updates - run it on a trusted LAN only.
- TOS Docker applications cannot mount shared folders: downloads, the renamed
  library, the database and the logs all stay in
  `/Volume1/DockerAppData/couchpotatodocker/`. Move finished movies to your media
  share with File Manager.
- NZB/torrent indexers and the download client are configured in the web UI;
  some indexers need an account or API key.
- The UI is served over plain HTTP on the LAN. Do not expose the published port
  to the internet without a TLS reverse proxy.

---

Packaged for TOS 7 by Moechz. Upstream image used unmodified from Docker Hub.
