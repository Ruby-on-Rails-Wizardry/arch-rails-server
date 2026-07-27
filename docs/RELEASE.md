# Release process

## When to cut a release

- Meaningful bootstrap behavior change
- Install docs / archinstall sample updates that operators must notice
- Security-relevant defaults (sshd, firewall, packages)

## Checklist

1. **Verify** on a lab VM or host:
   ```bash
   sudo ./bin/bootstrap
   ./bin/doctor
   ./bin/verify
   ```
2. **Changelog**: move `[Unreleased]` notes into a new version section (`## [x.y.z] - YYYY-MM-DD`).
3. **Commit** on `master` with a complete-sentence message.
4. **Tag** annotated:
   ```bash
   git tag -a vX.Y.Z -m "arch-rails-server vX.Y.Z"
   ```
5. **Push**:
   ```bash
   git push github master --tags
   git push gitlab master --tags
   ```
6. **GitHub Release**:
   ```bash
   gh release create vX.Y.Z --title "vX.Y.Z" --notes-file CHANGELOG.md
   # or paste the version section as notes
   ```

## Versioning

Semantic versioning for operators:

- **MAJOR** — breaking bootstrap defaults (e.g. firewall behavior that can lock out hosts)
- **MINOR** — new modules, supported packages, docs that expand capability
- **PATCH** — fixes, sample JSON tweaks, clarifications

## Phrases

**send it** / **ship it** / **cut a release** → this checklist end-to-end.
