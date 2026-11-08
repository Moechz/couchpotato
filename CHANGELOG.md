# Changelog

All notable user-visible changes to the CouchPotato TOS application package.

## 3.0.1-1 — 2026-11-08

### Added
- First release. CouchPotato (`linuxserver/couchpotato:7260c12f-ls82`, Docker Hub
  image, unmodified) packaged as a TOS 7 Docker application, published on port
  8005 and running as a non-root user (1000:1000).
- **Both architectures in one release**: `couchpotatodocker_x86_64.tar.gz` and
  `couchpotatodocker_aarch64.tar.gz` (each with a `.sha256`), because a TOS
  Docker application can only declare a single architecture.
- Entrypoint wrapper that skips the image's root-only s6 init and runs the
  bundled Python 2 application directly as the unprivileged container user.
- Persistent data is kept under `/Volume1/DockerAppData/couchpotatodocker/`
  (`config/` for settings and database, `downloads/` for fetched files).
