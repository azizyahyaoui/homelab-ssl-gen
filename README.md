# Home Labs SSL Generator

> Lightweight local CA and certificate generator for homelabs

**Creator:** Yahyaoui Med Aziz

This repository provides a small Bash script to act as a local Certificate Authority (CA) and to issue signed SSL/TLS certificates for services in a home lab or internal network. It:

- Creates a self-signed Root CA (if one doesn't already exist)
- Issues service certificates signed by that Root CA
- Supports Subject Alternative Names (DNS and IP SANs)

This is intended for development, testing, and private homelab use — not for public-facing production sites.

**Repository layout**

- `script/generate-certs.sh` — main script that generates the CA and service certs
- `script/` — helper scripts (currently contains `generate-certs.sh`)
- `tuto/TLS_SSL.md` — tutorial and notes
- `certs/` — default output directory created by the script (gitignored by default)

**Quick links**

- Script: [script/generate-certs.sh](script/generate-certs.sh#L1)
- Tutorial: [tuto/TLS_SSL.md](tuto/TLS_SSL.md#L1)

---

**Contents**

- Prerequisites
- Usage
- Examples
- Security & best-practices
- Troubleshooting

---

**Prerequisites**

- A POSIX-compatible shell (bash) on Linux, macOS, or WSL on Windows
- `openssl` available in PATH (tested with OpenSSL 1.1+ / 3.x)
- Basic shell tools: `cat`, `rm`, `mkdir`

Environment variables used by the script:

- `CA_PASS` — optional; default fallback used if not provided. If set, the script uses this value as the Root CA password.

**Usage**

Run the script from the repository root (or provide a full path). Minimum required argument:

```bash
./script/generate-certs.sh -n SERVICE_NAME
```

Full help is available from the script:

```bash
./script/generate-certs.sh --help
```

Options summary

- `-n, --name NAME` (required): service identifier / filename prefix
- `-c, --cn CN`: Common Name / primary FQDN (defaults to `SERVICE_NAME`)
- `-d, --dns DOMAINS`: comma-separated DNS SANs (e.g. "pve.home,pve.local")
- `-i, --ip IPS`: comma-separated IP SANs (e.g. "192.168.1.50,127.0.0.1")
- `-e, --days DAYS`: certificate lifetime in days (default 825)
- `-o, --out DIR`: output directory (default `./certs`)
- `-p, --pass PASS`: Root CA password (overrides `CA_PASS` env)
- `-h, --help`: show help

Generated files (in the output dir):

- `ca-key.pem` — encrypted Root CA private key
- `ca.pem` — Root CA certificate (public)
- `${SERVICE_NAME}-key.pem` — service private key
- `${SERVICE_NAME}.pem` — service certificate signed by the Root CA
- `${SERVICE_NAME}-fullchain.pem` — service cert followed by the CA cert

**Examples**

- Create certificates for `proxmox` with DNS SANs and an IP SAN:

```bash
./script/generate-certs.sh -n proxmox -c pve.labs.home -d "pve.labs.home,pve" -i "192.168.1.50"
```

- Create a cert for `true-nas` and place output in a custom directory:

```bash
./script/generate-certs.sh -n true-nas -c nas.local -i "192.168.1.100,10.0.0.5" -o ./my-certs
```

**Security & best-practices**

- The generated Root CA key is encrypted with the provided password. Keep `ca-key.pem` secure and offline when not in use.
- Do NOT use these credentials for public-facing services — only for internal/homelab use.
- Consider creating a separate CA per environment and rotating keys periodically.
- Use a secure password for `CA_PASS` and avoid checking it into source control.

**Troubleshooting**

- Permission errors: ensure you have write access to the output directory.
- OpenSSL errors: confirm `openssl version` and update if necessary.
- If SANs are missing in the generated cert, ensure you provided `-d` and/or `-i` correctly (comma-separated, no spaces), or check the generated `.extfile.cnf` during script execution.

**Next steps / Integration**

- Import `ca.pem` into your clients' trust stores to trust generated service certificates.
- Use the `${SERVICE_NAME}-fullchain.pem` and `${SERVICE_NAME}-key.pem` in your web server or service TLS configuration.

---
Open an issue or request a follow-up change if you want any of these.
