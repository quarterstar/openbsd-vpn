#! /usr/bin/env nix-shell
#! nix-shell -i bash -p bash python3 openssh sshpass wireguard-tools

# openbsd-vpn
# by quarterstar
# https://github.com/quarterstar/openbsd-vpn
# MIT License

wait_for_ssh() {
    local ip=$1
    local max_attempts=100
    local attempt=0
    local timeout=10

    echo "Waiting for SSH to be ready on $ip..."

    while [ $attempt -lt $max_attempts ]; do
        nc -z -w $timeout $ip 22
        if [ $? -eq 0 ]; then
            echo "SSH is ready on $ip."
            return 0
        fi
        attempt=$((attempt + 1))
        echo "Attempt $attempt/$max_attempts: SSH not ready yet, retrying in $timeout seconds..."
        sleep $timeout
    done

    echo "SSH did not become ready on $ip after $max_attempts attempts."
    return 1
}

# Start of script

# In case of failure
trap "rm -f {./public.key.tmp,./instance.txt}" EXIT

# Default values
listen_address="10.1.0.1"
hosts="10.1.0.2/32"
port=51820
locations=""
mtu=""

# Required options
provider=""
wg_pub_key=""
api_key=""
plan=""
label=""

# Function to display usage
usage() {
  echo "Usage: $0 --provider <provider> --wg-pub-key <wg-pub-key> --api-key <api-key> --plan <plan> --label <label> [--listen-address <address>] [--hosts <hosts>] [--locations <locations>] [--port <port>] [--mtu <mtu>]"
  exit 1
}

# Parse long options
while [[ $# -gt 0 ]]; do
  case "$1" in
    --provider)
      if [[ -n $2 ]]; then
        provider="$2"
        shift 2
      else
        echo "Error: --provider requires a value."
        usage
      fi
      ;;
    --wg-pub-key)
      if [[ -n $2 ]]; then
        wg_pub_key="$2"
        shift 2
      else
        echo "Error: --wg-pub-key requires a value."
        usage
      fi
      ;;
    --api-key)
      if [[ -n $2 ]]; then
        api_key="$2"
        shift 2
      else
        echo "Error: --api-key requires a value."
        usage
      fi
      ;;
    --plan)
      if [[ -n $2 ]]; then
        plan="$2"
        shift 2
      else
        echo "Error: --plan requires a value."
        usage
      fi
      ;;
    --label)
      if [[ -n $2 ]]; then
        label="$2"
        shift 2
      else
        echo "Error: --label requires a value."
        usage
      fi
      ;;
    --listen-address)
      if [[ -n $2 ]]; then
        listen_address="$2"
        shift 2
      else
        echo "Error: --listen-address requires a value."
        usage
      fi
      ;;
    --hosts)
      if [[ -n $2 ]]; then
        hosts="$2"
        shift 2
      else
        echo "Error: --hosts requires a value."
        usage
      fi
      ;;
    --locations)
      if [[ -n $2 ]]; then
        locations="$2"
        shift 2
      else
        echo "Error: --locations requires a value."
        usage
      fi
      ;;
    --mtu)
      if [[ -n $2 ]]; then
        mtu="$2"
        shift 2
      else
        echo "Error: --mtu requires a valid number."
        usage
      fi
      ;;
    --port)
      if [[ -n $2 && $2 =~ ^[0-9]+$ ]]; then
        port="$2"
        shift 2
      else
        echo "Error: --port requires a valid number."
        usage
      fi
      ;;
    --help)
      usage
      ;;
    *)
      echo "Unknown option: $1"
      usage
      ;;
  esac
done

# Check if all required options are provided
if [[ -z $provider || -z $wg_pub_key || -z $api_key || -z $plan || -z $label ]]; then
  echo "Error: Missing required options."
  usage
fi

if [[ -n ".venv" ]]; then
    python -m venv ./.venv
fi

# Path to the virtual environment
VENV_DIR=".venv"

# Activate the virtual environment
if [ -f "$VENV_DIR/bin/activate" ]; then
    source "$VENV_DIR/bin/activate"
else
    echo "Virtual environment not found at $VENV_DIR"
    exit 1
fi

pip install -r requirements.txt

python3 ./backend/${provider}/create.py $api_key $plan $label $locations

source ./instance.txt

key_ip="IP"
ip="${!key_ip}"

# Wait for SSH to be ready
if ! wait_for_ssh $ip; then
    echo "Failed to connect to SSH on $ip. Exiting."
    exit 1
fi

key_password="PASSWORD"
password="${!key_password}"

sshpass -p "$password" scp -o StrictHostKeyChecking=no ./openbsd/setup.sh root@${ip}:/root
sshpass -p "$password" ssh -o StrictHostKeyChecking=no root@${ip} "chmod +x /root/setup.sh && /root/setup.sh ${wg_pub_key} ${port} ${hosts} ${mtu}"

echo "Finished deployment of new server."

echo "Obtaining server's public key..."
sshpass -p "$password" scp -o StrictHostKeyChecking=no root@${ip}:/etc/wireguard/public.key ./public.key.tmp

#if [ ! -f "public.key.tmp" ]; then
#    echo "OpenBSD setup script did not run successfully"
#    exit 1
#fi

echo "Obtained server's public key"

echo "IP=${ip}" > server.env
echo "PUBLIC_KEY=\"$(cat public.key.tmp)\"" >> server.env
rm ./public.key.tmp

# Cleanup

rm -f ./instance.txt
sshpass -p "$password" ssh -o StrictHostKeyChecking=no root@${ip} "rm /root/setup.sh"

key_old_id="OLD_ID"
old_id="${!key_old_id}"

if [ -f "./backend/${provider}/delete.py" ]; then
    echo "Deleting old instance..."
    python3 ./backend/${provider}/delete.py $api_key $old_id
    echo "Finished old instance deletion."
fi
