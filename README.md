# Qvitr installers

This public repository distributes Qvitr installation packages and documentation.
Application source code, private signing certificates, certificate passwords, and
license-generation keys do not belong in this repository.

## Installation choices

- **Qvitr Enterprise** — the Windows installer with Qanvas standalone, Excel
  integration, and PowerPoint integration. The components can be selected during
  installation. Qanvas standalone does not require Microsoft Office.
- **QReports ClickOnce** — the existing per-user Excel installation and update
  channel.

A valid Qvitr license is required for Qanvas and the licensed Pro tools. The same
license key is shared by standalone Qanvas and the Office integrations. A Pro
license grants access to all tools.

## Which files should a single user download?

For a normal installation, download **`Qvitr-enterprise-setup.exe`** from the
latest GitHub release and run it. This is the recommended installer because it
checks for the required .NET 8 Desktop Runtime and installs it when necessary.

For the current internally signed releases on a new computer, also download
these two files from the same release:

- `Qvitr-Internal-Code-Signing.cer`
- `trust-qvitr-internal-certificate.ps1`

Keep the certificate and trust script in the same folder, then run the trust
script once before starting the installer:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\trust-qvitr-internal-certificate.ps1
```

If the Qvitr Internal Code Signing certificate is already trusted on the
computer, only **`Qvitr-enterprise-setup.exe`** is needed for a new installation
or update.

Individual users do **not** need to download `Qvitr-enterprise.msi`,
`SHA256SUMS.txt`, or the release-note files. The MSI is intended for managed IT
deployment on computers where the required runtime and prerequisites are
already installed.

The release also contains `qvitr-update.json`. Qanvas, Excel and PowerPoint read
this small manifest only when the user selects **Check for updates**. It records
the latest Qanvas file version, the independently incremented MSI version, the
setup download URL and its SHA-256 hash; it is not an installer users need to
open themselves.

## Maintainer release command

From the source repository, the recommended release command is:

```powershell
.\documentation\update_github_enterprise_release.bat 12.0.2
```

It builds and signs the package, stages and validates all release assets, then creates or updates release `v12.0.2`. Use `--validate-only` for a dry run, `--draft` for a draft release, or `--skip-build` only when the current artifacts were already built with that exact installer version.

## Repository layout

- `docs/` is the GitHub Pages site and existing ClickOnce payload.
- Machine-wide setup packages are GitHub Release assets, not normal Git files.
- `scripts/upload-enterprise-release.ps1` validates and uploads a locally prepared
  release when GitHub CLI is installed and authenticated.

Internal releases also contain the public `Qvitr-Internal-Code-Signing.cer` and
the one-time `trust-qvitr-internal-certificate.ps1` helper. These files do not
contain the private signing key. Remove this internal trust workflow when Qvitr
moves to a publicly trusted Authenticode signing service.

Never commit `.pfx` files, private keys, passwords, or customer license keys.
