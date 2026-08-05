# Home Labs SSL Generator

> **Creator:** Yahyaoui Med Aziz | 030826
> **Editor:** Antigravity

---

## 🚀 Quick Start

### 1. Requirements

Ensure the following are available on your system:

* Bash
* OpenSSL

### 2. Set Permissions

Make the script executable:

```bash
chmod +x script/generate-certs.sh

```

### 3. Secure Your Root CA

Never use the hardcoded fallback password in production or in homelabs exposed to untrusted networks. Pass it through an environment variable before running the script:

```bash
export CA_PASS="YourSuperSecretCustomPasswordHere"

```

### 4. Generate Certificates

**Basic usage (single domain):**

```bash
./script/generate-certs.sh -n proxmox -c pve.home.arpa

```

**Advanced usage (multiple domains and IP addresses):**

```bash
./script/generate-certs.sh -n pihole \
  -c pihole.home.arpa \
  -d "pihole.home.arpa,dns.local" \
  -i "192.168.1.5,127.0.0.1" \
  -o ./my-certs

```

---

## 🛠️ CLI Options

| Option | Description |
| --- | --- |
| `-n, --name` | **(Required)** Service identifier used for output filenames. |
| `-c, --cn` | Common name / primary hostname. |
| `-d, --dns` | Comma-separated DNS SAN values. |
| `-i, --ip` | Comma-separated IP SAN values. |
| `-e, --days` | Certificate validity in days (Default: 825). |
| `-o, --out` | Output directory (Default: `./certs`). |
| `-p, --pass` | Root CA password override. |
| `-h, --help` | Show the help menu. |

---

## 🔒 Trusting the Root CA

To eliminate SSL warnings across your network, copy the generated `ca.pem` from the output folder to your client devices and import it into their trust stores.

**Debian & Ubuntu Derivatives**
Move the CA certificate into `/usr/local/share/ca-certificates/ca.crt` and run `sudo update-ca-certificates`.

**Fedora & RHEL**
Move the CA certificate to `/etc/pki/ca-trust/source/anchors/ca.pem` and run `sudo update-ca-trust`.

**Arch Linux**
Run `sudo trust anchor --store ca.pem`. If that fails, copy the certificate to `/etc/ca-certificates/trust-source/anchors/` and run `sudo update-ca-trust`.

**Windows**
Open PowerShell as Administrator and run:
`Import-Certificate -FilePath "C:\path\to\ca.pem" -CertStoreLocation Cert:\LocalMachine\Root`

---

## 📚 Appendix: Educational Reference Guide

### What are TLS and SSL?

TLS (Transport Layer Security) and SSL (Secure Sockets Layer) are cryptographic protocols designed to provide secure, encrypted communication over a network.

* **SSL:** The predecessor developed in the mid-1990s, operating on the Application Layer (Layer 7).
* **TLS:** The modern, standardized successor based on SSL v3.0, operating on the Transport Layer (Layer 4). It offers stronger cryptographic algorithms and enhanced security features.

### Certificate Formats

X.509 Certificates exist in several encoding formats. You can use OpenSSL to convert between them:

| Conversion | Command |
| --- | --- |
| **PEM to DER** | `openssl x509 -outform der -in cert.pem -out cert.der` |
| **DER to PEM** | `openssl x509 -inform der -in cert.der -out cert.pem` |
| **PFX to PEM** | `openssl pkcs12 -in cert.pfx -out cert.pem -nodes` |

### Manual OpenSSL Generation (Alternative to Script)

If you prefer to generate certificates manually for learning purposes, follow these core steps:

**Step 1: Generate CA Key and Cert**

```bash
openssl genrsa -aes256 -out ca-key.pem 4096
openssl req -new -x509 -sha256 -days 3650 -key ca-key.pem -out ca.pem

```

**Step 2: Generate Service Key and CSR**

```bash
openssl genrsa -out cert-key.pem 4096
openssl req -new -sha256 -subj "/CN=yourdomain.com" -key cert-key.pem -out cert.csr

```

**Step 3: Sign the Certificate**
Create an `extfile.cnf` containing `subjectAltName=DNS:yourdomain.com,IP:192.168.1.10`, then run:

```bash
openssl x509 -req -sha256 -days 365 -in cert.csr -CA ca.pem -CAkey ca-key.pem -out cert.pem -extfile extfile.cnf -CAcreateserial

```

### DevStack (OpenStack) Configuration

To enable SSL for a DevStack environment using your generated certificates, place the files in `/etc/ssl/certs/` and update your `local.conf` file:

```text
[[DEFAULT]]
enable_ssl = True
certfile = /etc/ssl/certs/server.crt
keyfile = /etc/ssl/private/server.key
cafile = /etc/ssl/certs/ca.crt

```

---