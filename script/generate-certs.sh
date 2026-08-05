#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
#  DEFAULTS & HELP
# ==============================================================================

OUT_DIR="./certs"
CA_CN="Homelab-Root-CA"
CA_DAYS=3650
CA_KEY_SIZE=4096
CA_PASS="${CA_PASS:-ChangeMeSuperSecret123!}"

SERVICE_NAME=""
SERVER_CN=""
DAYS=825
KEY_SIZE=4096

DNS_INPUT=""
IP_INPUT=""

usage() {
    cat <<EOF
Usage: $(basename "$0") -n SERVICE_NAME [OPTIONS]

Required Arguments:
  -n, --name NAME       Service identifier/prefix for files (e.g., proxmox, pihole)

Optional Arguments:
  -c, --cn CN           Common Name / Primary FQDN (Defaults to SERVICE_NAME if omitted)
  -d, --dns DOMAINS     Comma-separated list of DNS SANs (e.g., "pve.home,pve.local")
  -i, --ip IPS          Comma-separated list of IP SANs (e.g., "192.168.1.50,127.0.0.1")
  -e, --days DAYS       Certificate validity period in days (Default: 825)
  -o, --out DIR         Output directory path (Default: ./certs)
  -p, --pass PASS       Root CA password (Default: uses \$CA_PASS env or script fallback)
  -h, --help            Show this help message

Examples:
  $(basename "$0") -n proxmox -c pve.labs.home -d "pve.labs.home,pve" -i "192.168.1.50"
  $(basename "$0") -n true-nas -c nas.local -i "192.168.1.100,10.0.0.5"
EOF
    exit 1
}

# ==============================================================================
#  CLI ARGUMENT PARSING
# ==============================================================================

while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--name)
            SERVICE_NAME="$2"; shift 2 ;;
        -c|--cn)
            SERVER_CN="$2"; shift 2 ;;
        -d|--dns)
            DNS_INPUT="$2"; shift 2 ;;
        -i|--ip)
            IP_INPUT="$2"; shift 2 ;;
        -e|--days)
            DAYS="$2"; shift 2 ;;
        -o|--out)
            OUT_DIR="$2"; shift 2 ;;
        -p|--pass)
            CA_PASS="$2"; shift 2 ;;
        -h|--help)
            usage ;;
        *)
            echo "Error: Unknown argument '$1'"
            usage ;;
    esac
done

if [[ -z "$SERVICE_NAME" ]]; then
    echo "Error: Service name (-n | --name) is required."
    usage
fi

# Fallback CN to SERVICE_NAME if not explicitly set
if [[ -z "$SERVER_CN" ]]; then
    SERVER_CN="$SERVICE_NAME"
fi

# ==============================================================================
#  SCRIPT EXECUTION
# ==============================================================================

mkdir -p "$OUT_DIR"

CA_KEY_FILE="${OUT_DIR}/ca-key.pem"
CA_CERT_FILE="${OUT_DIR}/ca.pem"
SERVER_KEY_FILE="${OUT_DIR}/${SERVICE_NAME}-key.pem"
SERVER_CSR_FILE="${OUT_DIR}/${SERVICE_NAME}.csr"
SERVER_CERT_FILE="${OUT_DIR}/${SERVICE_NAME}.pem"
SERVER_FULLCHAIN_FILE="${OUT_DIR}/${SERVICE_NAME}-fullchain.pem"
EXT_FILE="${OUT_DIR}/${SERVICE_NAME}.extfile.cnf"

echo "==> Step 1: Checking Root Certificate Authority..."
if [[ ! -f "$CA_KEY_FILE" || ! -f "$CA_CERT_FILE" ]]; then
    echo "Creating Root CA key ($CA_KEY_FILE)..."
    openssl genrsa -aes256 -passout pass:"$CA_PASS" -out "$CA_KEY_FILE" "$CA_KEY_SIZE"

    echo "Creating Root CA cert ($CA_CERT_FILE)..."
    openssl req -new -x509 -sha256 -days "$CA_DAYS" \
        -subj "/CN=$CA_CN" \
        -key "$CA_KEY_FILE" -passin pass:"$CA_PASS" \
        -out "$CA_CERT_FILE"
else
    echo "Existing Root CA found in $OUT_DIR. Reusing existing CA."
fi

echo "==> Step 2: Generating Private Key for '$SERVICE_NAME'..."
openssl genrsa -out "$SERVER_KEY_FILE" "$KEY_SIZE"

echo "==> Step 3: Generating Certificate Signing Request (CSR)..."
openssl req -new -sha256 \
    -subj "/CN=$SERVER_CN" \
    -key "$SERVER_KEY_FILE" \
    -out "$SERVER_CSR_FILE"

echo "==> Step 4: Constructing SAN Extensions..."
SAN_ENTRIES=()

if [[ -n "$DNS_INPUT" ]]; then
    IFS=',' read -r -a DNS_LIST <<< "$DNS_INPUT"
    for dns in "${DNS_LIST[@]}"; do
        clean_dns="$(echo "$dns" | xargs)"
        [[ -n "$clean_dns" ]] && SAN_ENTRIES+=("DNS:${clean_dns}")
    done
fi

if [[ -n "$IP_INPUT" ]]; then
    IFS=',' read -r -a IP_LIST <<< "$IP_INPUT"
    for ip in "${IP_LIST[@]}"; do
        clean_ip="$(echo "$ip" | xargs)"
        [[ -n "$clean_ip" ]] && SAN_ENTRIES+=("IP:${clean_ip}")
    done
fi

# Fallback SAN to CN if no SAN inputs provided
if [[ ${#SAN_ENTRIES[@]} -eq 0 ]]; then
    SAN_ENTRIES+=("DNS:${SERVER_CN}")
fi

SAN_STRING=$(IFS=,; echo "${SAN_ENTRIES[*]}")

cat <<EOF > "$EXT_FILE"
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = ${SAN_STRING}
EOF

echo "==> Step 5: Signing Certificate with Root CA..."
openssl x509 -req -sha256 -days "$DAYS" \
    -in "$SERVER_CSR_FILE" \
    -CA "$CA_CERT_FILE" \
    -CAkey "$CA_KEY_FILE" -passin pass:"$CA_PASS" \
    -out "$SERVER_CERT_FILE" \
    -extfile "$EXT_FILE" \
    -CAcreateserial

echo "==> Step 6: Generating Fullchain Bundle..."
cat "$SERVER_CERT_FILE" "$CA_CERT_FILE" > "$SERVER_FULLCHAIN_FILE"

echo "==> Step 7: Cleaning up build artifacts..."
rm -f "$SERVER_CSR_FILE" "$EXT_FILE" "${OUT_DIR}/ca.srl"

echo ""
echo "========================================================================="
echo " Success! Generated certificates for '$SERVICE_NAME':"
echo "  - Public Cert:     $SERVER_CERT_FILE"
echo "  - Fullchain Cert:  $SERVER_FULLCHAIN_FILE"
echo "  - Private Key:     $SERVER_KEY_FILE"
echo "  - CA Cert:          $CA_CERT_FILE"
echo "========================================================================="