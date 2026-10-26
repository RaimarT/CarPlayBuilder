# Releasing CarPlayBuilder

## Prepared release: 1.0.0

The README contains versioned installation instructions and the changelog contains
release notes. The tag and GitHub release have not been published.

Use the `1.0.0` changelog section as the GitHub release description. Publish this
as the latest stable release, with the title **CarPlayBuilder 1.0.0**; do not mark
it as a prerelease. Swift Package Manager resolves the Git tag, so no binary
attachment is required.

## Before publishing

- Confirm the working tree is clean and the release preparation is committed.
- Confirm GitHub Actions passes for that exact commit, including formatting,
  simulator tests, and DocC generation.
- Verify a consuming app on an iOS simulator and, when available, a CarPlay
  simulator or vehicle. Package unit tests do not replace host-app integration.
- Review the public API and requirements. Version 1.x commits to source
  compatibility; incompatible public API changes require version 2.0.0.

## Publish after approving the release commit

Create the tag from the validated release commit, not an unreviewed later HEAD:

```sh
git tag -a 1.0.0 <release-commit> -m "CarPlayBuilder 1.0.0"
git push origin 1.0.0
```

On GitHub, create a release using the existing `1.0.0` tag and the changelog notes.
Check that a fresh consuming package resolves version 1.0.0 from the public URL.
Once published, keep the tag immutable; publish fixes as new patch versions.

For subsequent releases, move completed changes from `Unreleased` into a new
version section and update the comparison links and installation examples.
