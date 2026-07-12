# Privacy Policy — idle-intel

**Effective date: July 12, 2026**

## The short version

idle-intel collects no data, transmits no data, and has no server. Everything it does happens on your machine.

## What idle-intel does

idle-intel reads information that already exists in your local project — package manifests, git metadata, source files — and writes a small plain-text cache inside the project itself (`<project>/.claude/idle-intel/cache.txt`). It then displays one line of that cache at a time in Claude Code's status line.

## Data collection

None. idle-intel has no telemetry, no analytics, no account system, no identifiers, and no remote endpoint of its own. The authors receive nothing when you install, run, or uninstall it.

## Network access

idle-intel itself makes no network calls. The only network traffic that can occur is initiated by **your own package managers** when the collector invokes their standard commands:

- `npm audit` and `npm outdated` contact the npm registry to compare your dependencies against public advisory and version data — the same traffic these commands generate when you run them yourself.
- `pip list --outdated` contacts the Python Package Index for version data.

These commands run under your local configuration (including any private registries or proxies you have configured) and are subject to the respective registries' privacy policies. If a package manager is not installed, or the project has no manifest for it, no such call is made. Git checks are entirely local and never contact any remote.

## Data storage

The insight cache is a plain-text file stored inside your project directory. It never leaves your machine, is human-readable, and can be deleted at any time without consequence. No data is stored outside the project directory apart from the plugin's own script files.

## Third parties

There are none. idle-intel embeds no third-party SDKs, trackers, or services.

## Changes to this policy

Any change to this policy will be committed to this repository with a visible history. Given the architecture — local scripts, no server — material changes are not anticipated.

## Contact

Questions: open an issue at https://github.com/demartinogiuseppe/idle-intel/issues
