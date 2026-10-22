#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ${EUID} -ne 0 ]]; then
  exec sudo bash "$0" "$@"
fi

command -v netplan >/dev/null 2>&1 || {
  echo "[ERROR] The netplan command was not found." >&2
  exit 1
}

valid_ipv4() {
  local ip=$1 part
  IFS=. read -r -a parts <<< "$ip"
  [[ ${#parts[@]} -eq 4 ]] || return 1
  for part in "${parts[@]}"; do
    [[ $part =~ ^[0-9]+$ ]] || return 1
    (( part >= 0 && part <= 255 )) || return 1
  done
}

prefix_from_subnet() {
  case "$1" in
    /8|8|255.0.0.0) echo 8 ;;
    /9|9|255.128.0.0) echo 9 ;;
    /10|10|255.192.0.0) echo 10 ;;
    /11|11|255.224.0.0) echo 11 ;;
    /12|12|255.240.0.0) echo 12 ;;
    /13|13|255.248.0.0) echo 13 ;;
    /14|14|255.252.0.0) echo 14 ;;
    /15|15|255.254.0.0) echo 15 ;;
    /16|16|255.255.0.0) echo 16 ;;
    /17|17|255.255.128.0) echo 17 ;;
    /18|18|255.255.192.0) echo 18 ;;
    /19|19|255.255.224.0) echo 19 ;;
    /20|20|255.255.240.0) echo 20 ;;
    /21|21|255.255.248.0) echo 21 ;;
    /22|22|255.255.252.0) echo 22 ;;
    /23|23|255.255.254.0) echo 23 ;;
    /24|24|255.255.255.0) echo 24 ;;
    /25|25|255.255.255.128) echo 25 ;;
    /26|26|255.255.255.192) echo 26 ;;
    /27|27|255.255.255.224) echo 27 ;;
    /28|28|255.255.255.240) echo 28 ;;
    /29|29|255.255.255.248) echo 29 ;;
    /30|30|255.255.255.252) echo 30 ;;
    /31|31|255.255.255.254) echo 31 ;;
    /32|32|255.255.255.255) echo 32 ;;
    *) return 1 ;;
  esac
}

choose_interface() {
  local prompt=$1 selection
  while true; do
    read -r -p "$prompt [1-${#INTERFACES[@]}]: " selection
    [[ $selection =~ ^[0-9]+$ ]] || { echo "Please enter a number." >&2; continue; }
    (( selection >= 1 && selection <= ${#INTERFACES[@]} )) || {
      echo "Please choose a number within the displayed range." >&2
      continue
    }
    printf '%s' "${INTERFACES[$((selection - 1))]}"
    return
  done
}

rollback() {
  echo "[ROLLBACK] Restoring the previous Netplan configuration." >&2
  rm -f /etc/netplan/*.yaml /etc/netplan/*.yml
  find "$BACKUP_DIR" -maxdepth 1 -type f \( -name '*.yaml' -o -name '*.yml' \) \
    -exec cp -a {} /etc/netplan/ \;
  netplan generate || true
  netplan apply || true
}

# Documentation-only networks: replace with the management networks to preserve.
PROTECTED_IP_REGEX='^(192\.0\.2|198\.51\.100)\.[0-9]+/'
PROTECTED_INTERFACES=()
INTERFACES=()
declare -A PROTECTED_IPV4S=()

for path in /sys/class/net/*; do
  name=${path##*/}
  [[ $name == lo ]] && continue
  [[ -e "$path/device" ]] || continue

  mapfile -t current_ipv4 < <(
    ip -o -4 address show dev "$name" scope global | awk '{print $4}'
  )

  protected=false
  for cidr in "${current_ipv4[@]}"; do
    if [[ $cidr =~ $PROTECTED_IP_REGEX ]]; then
      protected=true
      break
    fi
  done

  if [[ $protected == true ]]; then
    PROTECTED_INTERFACES+=("$name")
    PROTECTED_IPV4S["$name"]=$(printf '%s\n' "${current_ipv4[@]}")
  else
    INTERFACES+=("$name")
  fi
done

mapfile -t INTERFACES < <(
  printf '%s\n' "${INTERFACES[@]}" | sed '/^$/d' | sort
)
mapfile -t PROTECTED_INTERFACES < <(
  printf '%s\n' "${PROTECTED_INTERFACES[@]}" | sed '/^$/d' | sort
)

if (( ${#PROTECTED_INTERFACES[@]} > 0 )); then
  echo "============================================================"
  echo " Protected Network Interfaces"
  echo "============================================================"
  for nic in "${PROTECTED_INTERFACES[@]}"; do
    protected_addresses=$(ip -o -4 address show dev "$nic" scope global | awk '{print $4}' | paste -sd, -)
    printf ' %-15s IPv4=%s\n' "$nic" "${protected_addresses:--}"
  done
  echo "These interfaces will not be available for bonding."
  echo
fi

if (( ${#INTERFACES[@]} < 2 )); then
  echo "[ERROR] At least two unprotected physical network interfaces are required for bonding." >&2
  ip -br address
  exit 1
fi

mapfile -t INTERFACES < <(
  for path in /sys/class/net/*; do
    name=${path##*/}
    [[ $name == lo ]] && continue
    [[ -e "$path/device" ]] || continue
    for protected_nic in "${PROTECTED_INTERFACES[@]}"; do
      [[ $name == "$protected_nic" ]] && continue 2
    done
    printf '%s\n' "$name"
  done | sort
)

echo "============================================================"
echo " Physical Network Interfaces"
echo "============================================================"
for i in "${!INTERFACES[@]}"; do
  nic=${INTERFACES[$i]}
  state=$(cat "/sys/class/net/$nic/operstate" 2>/dev/null || echo unknown)
  mac=$(cat "/sys/class/net/$nic/address" 2>/dev/null || echo unknown)
  current=$(ip -4 -br address show dev "$nic" | awk '{print $3}')
  printf '%2d) %-15s State=%-8s MAC=%-17s Current IP=%s\n' \
    "$((i + 1))" "$nic" "$state" "$mac" "${current:--}"
done

PRIMARY_NIC=$(choose_interface "Select the primary NIC")
while true; do
  SECONDARY_NIC=$(choose_interface "Select the secondary NIC")
  [[ $SECONDARY_NIC != "$PRIMARY_NIC" ]] && break
  echo "Please select an interface different from the primary NIC." >&2
done

while true; do
  read -r -p "Enter the static IP address [e.g., 203.0.113.10]: " IP_ADDRESS
  IP_ADDRESS=${IP_ADDRESS%%/*}
  valid_ipv4 "$IP_ADDRESS" && break
  echo "Please enter a valid IPv4 address." >&2
done

while true; do
  read -r -p "Enter the subnet [e.g., 255.255.255.224 or /27]: " SUBNET
  if PREFIX=$(prefix_from_subnet "$SUBNET"); then
    break
  fi
  echo "Please enter a supported subnet mask or CIDR prefix." >&2
done

while true; do
  read -r -p "Enter the gateway [e.g., 203.0.113.1]: " GATEWAY
  valid_ipv4 "$GATEWAY" && break
  echo "Please enter a valid gateway IPv4 address." >&2
done

read -r -p "Enter DNS servers (comma-separated, optional) [e.g., 203.0.113.1,8.8.8.8]: " DNS_INPUT
DNS_YAML=""
if [[ -n ${DNS_INPUT//[[:space:]]/} ]]; then
  IFS=',' read -r -a DNS_LIST <<< "$DNS_INPUT"
  CLEAN_DNS=()
  for dns in "${DNS_LIST[@]}"; do
    dns=${dns//[[:space:]]/}
    valid_ipv4 "$dns" || { echo "[ERROR] Invalid DNS address: $dns" >&2; exit 1; }
    CLEAN_DNS+=("$dns")
  done
  DNS_JOINED=$(IFS=', '; echo "${CLEAN_DNS[*]}")
  DNS_YAML=$(printf '      nameservers:\n        addresses: [%s]\n' "$DNS_JOINED")
fi

echo
echo "============================================================"
echo " Configuration to Apply"
echo "============================================================"
echo "Bond          : bond0"
echo "Mode          : active-backup"
echo "Primary NIC   : $PRIMARY_NIC"
echo "Secondary NIC : $SECONDARY_NIC"
echo "IP            : $IP_ADDRESS/$PREFIX"
echo "Gateway       : $GATEWAY"
echo "DNS           : ${DNS_INPUT:-Not configured}"
echo "============================================================"
read -r -p "Back up and replace the existing Netplan configuration? [y/N]: " CONFIRM
[[ $CONFIRM =~ ^([yY]|[yY][eE][sS])$ ]] || { echo "Operation canceled."; exit 0; }

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="/etc/netplan/backup-$TIMESTAMP"
NEW_FILE="/etc/netplan/99-bond0.yaml"
mkdir -p "$BACKUP_DIR"

PRESERVED_ETERNETS_YAML=""
for nic in "${PROTECTED_INTERFACES[@]}"; do
  existing_netplan=""
  if existing_netplan=$(netplan get "ethernets.${nic}" 2>/dev/null) && \
     [[ -n ${existing_netplan//[[:space:]]/} && $existing_netplan != "null" ]]; then
    printf -v PRESERVED_ETERNETS_YAML '%s    %s:\n' \
      "$PRESERVED_ETERNETS_YAML" "$nic"
    while IFS= read -r config_line; do
      printf -v PRESERVED_ETERNETS_YAML '%s      %s\n' \
        "$PRESERVED_ETERNETS_YAML" "$config_line"
    done <<< "$existing_netplan"
    continue
  fi

  echo "[WARN] Netplan settings for $nic could not be read; preserving its live IPv4 addresses only." >&2
  mapfile -t preserved_addresses < <(
    ip -o -4 address show dev "$nic" scope global | awk '{print $4}'
  )

  (( ${#preserved_addresses[@]} > 0 )) || continue
  printf -v PRESERVED_ETERNETS_YAML '%s    %s:\n      dhcp4: false\n      dhcp6: false\n      optional: true\n      addresses:\n' \
    "$PRESERVED_ETERNETS_YAML" "$nic"
  for cidr in "${preserved_addresses[@]}"; do
    printf -v PRESERVED_ETERNETS_YAML '%s        - %s\n' \
      "$PRESERVED_ETERNETS_YAML" "$cidr"
  done
done

find /etc/netplan -maxdepth 1 -type f \( -name '*.yaml' -o -name '*.yml' \) \
  -exec mv -t "$BACKUP_DIR" -- {} +

cat > "$NEW_FILE" <<EOF
network:
  version: 2
  renderer: NetworkManager
  ethernets:
${PRESERVED_ETERNETS_YAML}    ${PRIMARY_NIC}:
      dhcp4: false
      dhcp6: false
      optional: true
    ${SECONDARY_NIC}:
      dhcp4: false
      dhcp6: false
      optional: true
  bonds:
    bond0:
      interfaces:
        - ${PRIMARY_NIC}
        - ${SECONDARY_NIC}
      addresses:
        - ${IP_ADDRESS}/${PREFIX}
      routes:
        - to: default
          via: ${GATEWAY}
${DNS_YAML}
      parameters:
        mode: active-backup
        primary: ${PRIMARY_NIC}
        primary-reselect-policy: failure
        mii-monitor-interval: 100
        up-delay: 200
        down-delay: 200
EOF

chmod 600 "$NEW_FILE"

echo "[1/4] Validating Netplan syntax"
if ! netplan generate; then
  rollback
  exit 1
fi

echo "[2/4] Applying the new network configuration"
if ! netplan apply; then
  rollback
  exit 1
fi

sleep 3

echo "[3/4] Verifying the applied configuration"
if ! ip link show bond0 >/dev/null 2>&1 || \
   ! ip -4 address show dev bond0 | grep -q "inet ${IP_ADDRESS}/${PREFIX}" || \
   ! ip route show default | grep -q "via ${GATEWAY}.*bond0"; then
  echo "[ERROR] Failed to verify bond0, its IP address, or the default route." >&2
  rollback
  exit 1
fi

for nic in "${PROTECTED_INTERFACES[@]}"; do
  if ! ip link show "$nic" >/dev/null 2>&1; then
    echo "[ERROR] Protected interface $nic is missing after applying Netplan." >&2
    rollback
    exit 1
  fi

  while IFS= read -r expected_cidr; do
    [[ -n $expected_cidr ]] || continue
    if ! ip -o -4 address show dev "$nic" scope global | awk '{print $4}' | \
         grep -Fxq "$expected_cidr"; then
      echo "[ERROR] Protected address $expected_cidr is missing from $nic after applying Netplan." >&2
      rollback
      exit 1
    fi
  done <<< "${PROTECTED_IPV4S[$nic]}"
done

echo "[4/4] Final status"
ip -br address show bond0
for nic in "${PROTECTED_INTERFACES[@]}"; do
  ip -br address show "$nic"
done
ip route
cat /proc/net/bonding/bond0

if ping -c 3 -W 2 "$GATEWAY" >/dev/null 2>&1; then
  echo "[OK] Gateway is reachable: $GATEWAY"
else
  echo "[WARN] The gateway did not respond to ping. Check the firewall or switch configuration." >&2
fi

echo
echo "Bond configuration completed"
echo "Current configuration: $NEW_FILE"
echo "Previous configuration backup: $BACKUP_DIR"
