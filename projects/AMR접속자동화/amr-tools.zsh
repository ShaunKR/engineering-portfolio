# AMR connection helpers for zsh. Load explicitly with source.
# Public adaptation of personal field-operation helpers; no real hosts or keys.
: "${AMR_HOSTS_FILE:=$HOME/.config/amr/hosts.tsv}"
: "${AMR_SSH_USER:=amr}"
: "${AMR_IDENTITY_FILE:=$HOME/.ssh/id_ed25519_amr}"
: "${AMR_REMOTE_HOST:=remote.example.com}"

amr_ip() {
  if (( $# != 1 )) || [[ $1 != <-> ]] || (( ${#1} > 3 )); then
    print -u2 -- 'Usage: amr_ip <robot-number: 0..999>'
    return 2
  fi
  local robot_number=$((10#$1))
  local robot_id
  printf -v robot_id 'R_%03d' "$robot_number"
  if [[ ! -r "$AMR_HOSTS_FILE" ]]; then
    print -u2 -- 'Robot hosts file is not readable'
    return 1
  fi
  local robot_ip
  robot_ip=$(awk -v id="$robot_id" '
    { sub(/\r$/, "") }
    $1 == id { print $2; found = 1; exit }
    END { if (!found) exit 1 }
  ' "$AMR_HOSTS_FILE") || {
    print -u2 -- "Robot not found: $robot_id"
    return 1
  }
  if [[ -z "$robot_ip" || "$robot_ip" == *[^a-zA-Z0-9.-]* || "$robot_ip" == -* ]]; then
    print -u2 -- 'Invalid robot address'
    return 1
  fi
  print -r -- "$robot_ip"
}

amr_ssh() {
  if (( $# != 1 )) || [[ -z "$1" || "$1" == *[^a-zA-Z0-9.-]* || "$1" == -* ]]; then
    print -u2 -- 'Usage: amr_ssh <IPv4-or-hostname>'
    return 2
  fi
  if [[ ! -r "$AMR_IDENTITY_FILE" ]]; then
    print -u2 -- 'SSH identity file is not readable'
    return 1
  fi
  ssh -i "$AMR_IDENTITY_FILE" -- "${AMR_SSH_USER}@$1"
}

amr_go() {
  local robot_ip
  robot_ip=$(amr_ip "$@") || return $?
  amr_ssh "$robot_ip"
}

amr_remote() {
  if (( $# != 1 )) || [[ $1 != <-> ]] || (( ${#1} > 5 )); then
    print -u2 -- 'Usage: amr_remote <port: 1..65535>'
    return 2
  fi
  local remote_port=$((10#$1))
  if (( remote_port < 1 || remote_port > 65535 )); then
    print -u2 -- 'Port is outside 1..65535'
    return 2
  fi
  if [[ ! -r "$AMR_IDENTITY_FILE" ]]; then
    print -u2 -- 'SSH identity file is not readable'
    return 1
  fi
  ssh -i "$AMR_IDENTITY_FILE" -p "$remote_port" -- "${AMR_SSH_USER}@${AMR_REMOTE_HOST}"
}
