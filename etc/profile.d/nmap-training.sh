# Fedora sources this for both desktop terminals and SSH login shells.
# s6 keeps Docker environment values here, including for SSH sessions.
SCAN_NETWORK=${SCAN_NETWORK:-$(cat /run/s6/container_environment/SCAN_NETWORK 2>/dev/null || true)}
SCAN_INTERFACE=${SCAN_INTERFACE:-$(cat /run/s6/container_environment/SCAN_INTERFACE 2>/dev/null || true)}
LAB_DNS=${LAB_DNS:-$(cat /run/s6/container_environment/LAB_DNS 2>/dev/null || true)}
LAB_DOMAIN=${LAB_DOMAIN:-$(cat /run/s6/container_environment/LAB_DOMAIN 2>/dev/null || true)}
export NMAP_SAGE_API_KEY=${NMAP_SAGE_API_KEY:-$(cat /run/s6/container_environment/NMAP_SAGE_API_KEY 2>/dev/null || true)}

export SCAN_NETWORK=${SCAN_NETWORK:-172.28.50.0/24}
export SCAN_INTERFACE=${SCAN_INTERFACE:-${LAB_IF:-$(ip -o -4 route show "$SCAN_NETWORK" 2>/dev/null | \
    awk -v network="$SCAN_NETWORK" '$1 == network && $2 == "dev" {print $3; exit}')}}
export LAB_IF=$SCAN_INTERFACE
export LAB_NET=$SCAN_NETWORK
export LAB_DNS=${LAB_DNS:-172.28.50.10}
export LAB_DOMAIN=${LAB_DOMAIN:-shop.test}
export NMAP_TRAINING=/opt/nmap-training
