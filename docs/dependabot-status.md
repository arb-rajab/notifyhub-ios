# Dependabot status

_Last updated: 2026-10-08. Maintained during the Dependabot clean-up pass; update when the state changes._

## Configuration

- Ecosystems covered: github-actions (`/`).
- Grouping: none (one PR per update).
- Schedule: weekly.
- Ignore rules: none.

## State at last update

- Open Dependabot PRs: 0 (each merged or closed only after reading its checks).
- Default-branch CI: green at last check.

## Time-limited exemptions

- None.

## Notes

- No Dependabot PRs were open at the start of the pass; there is no osv-scanner config in this repo.
- The `swift` entry was removed on 2026-10-08. The app has no `Package.swift` and no Swift package dependencies, so the swift update job failed every week (`dependency_file_not_found`, "No files found in /"). Add it back with the first Swift package dependency.

## Deferred (not re-raised each pass)

- Ignored major versions are listed in `.github/dependabot.yml` with the reason for each.
- Re-check exemptions before their `effectiveUntil` date (2026-11-15) and drop them once upstream fixes ship.
