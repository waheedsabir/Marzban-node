#!/usr/bin/env bash
set -e

# ==============================================================================
# 1. HARDCODED CONFIGURATION (No Questions Asked)
# ==============================================================================
# Your Certificate is hardcoded here so the script never pauses to ask for it.
HARDCODED_CERT="-----BEGIN CERTIFICATE-----
MIIEnDCCAoQCAQAwDQYJKoZIhvcNAQENBQAwEzERMA8GA1UEAwwIR296YXJnYWgw
IBcNMjUxMjIzMDYxNzU5WhgPMjEyNTExMjkwNjE3NTlaMBMxETAPBgNVBAMMCEdv
emFyZ2FoMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAqCCKu9OmHDtW
xmJXa2udbcBzG5BahKhFtUJCCDPbJJGZk65CSFYmA1m1CnI9g1+8HVopRFa+whLs
jL+neOzP1/oa1cbWNrFuaCf258xo1HzN9Zq7lwTiC4/wxyzNgM19tbU+pvfOWhQY
znmMnaJL0/Bin7S+MUKZ49GhVAqwtEUEBhk79DQieZHb0E5md3rk/34GPpshszSY
uYcL1DqTMRD2txrjsU3SH0rWeMpzgNfJRXgsOd+xO1nLRkY7XyrXwGrpteiOZNOH
j5Hvt9443CJVHBfFYYWhhbuuQRWiAGX9ZikTYRjodl2RUp9hhbEDxy5D+D4PKny6
GoHQsbgRDw4v3bIm0q5ZTOe4AM3fjqwasEjT2rfn50a7yzZCrj1bvJF6S9chYLYy
+7M1jYsWW/oxG5OQWfWP+u1xNSLt8/Vs+oXq3Ru0XCq5bq/jvPYSHRAajKOy2qyY
VkEfmXl2uVrglwSo/XiG1y/ExZCZepqS4/Cij+a4k8EZJDYrG2HCbxN97+lOOJoV
l9Qf0Zo5e34gzvf8GRnFhjs8xeJhK5/WONwuJmSONozpKLfMao23pRmmbzyarTQB
BLN5Hkf4Sr0llBkVIRueBB8cWVrm4ZURlAQF7BU/GyMluem8VlNfduH69hkFPrt2
LLcTDgXwa9zJj3CA09f8xWZahxw3zY0CAwEAATANBgkqhkiG9w0BAQ0FAAOCAgEA
NhtD18m026RdT1Uvy5LE/EBDD00WV1MoDYXJ9hvyLTxPiPAmxdu0Nq6yElN55Us2
evWINGe7OUQYRYfkTj9B5KOMfsPgCdRULIXxU6ezCwDc1/tmD6ub4atDKidWd7/O
QtCd/oPrU9EgCUeDI6LFsjmwRB3XJ3vkqTTFP24fHkZ6CduroixKY1PJ0YmzTZ69
aT2Fnlx/ib0S/w3u+dwpoJnKSTwUR8JLSgcl2FUp6nhigKBX/KGBiEm9lS586Q1w
JYZ3CRByG8SpkKNzRlHCFF7XhhTsakASN4g3yyMKBEhxrMuDXjwoNEokGJJmqazn
VSq4r5BD5vlWJZrmCjsgWGYHXpX7xi9VtIKdfHLY3aM/Cv/YzCC5QAfFyZjwt2fy
/yMzjnEy2hqYHmlRIeTd1dIBi7wHZrytqKW3bKT8sFwvKclG99rlMRQDv31ze7Im
Tz5aVvpFdrsegq00bwNGAIwCfkiLWhQ9xCqICn8MeG2IipQJjtK+THDiFexWsa1K
O5TXeTP+QtemDMIRUeGr2JtMyihgRpJpBEbJHuqG0LmXy1S11QDO88PUo6GohjQl
PePam2AIkcrcfZxCMa4OL0p5jyZ4rRdarzOUT1m3evkuuiy3mW1IyrXAIe7cj/iX
t6F3Cr7px6K93RndqGTw2Z+Vg9S3kq2z8lJpyYM5eu8=
-----END CERTIFICATE-----"

# Hardcoded Ports
HARDCODED_SERVICE_PORT=62050
HARDCODED_XRAY_PORT=62051
HARDCODED_PROTOCOL="y" # 'y' for REST
# ==============================================================================

# [CLI ARGUMENT PARSING - PRESERVED]
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        install|update|uninstall|up|down|restart|status|logs|core-update|install-script|uninstall-script|edit)
            COMMAND="$1"
            shift 
        ;;
        --name)
            if [[ "$COMMAND" == "install" || "$COMMAND" == "install-script" ]]; then
                APP_NAME="$2"
                shift 
            else
                echo "Error: --name parameter is only allowed with 'install' or 'install-script' commands."
                exit 1
            fi
            shift 
        ;;
        *)
            shift 
        ;;
    esac
done

# [IP FETCHING LOGIC - PRESERVED]
NODE_IP=$(curl -s -4 ifconfig.io)
if [ -z "$NODE_IP" ]; then
    NODE_IP=$(curl -s -6 ifconfig.io)
fi

if [[ "$COMMAND" == "install" || "$COMMAND" == "install-script" ]] && [ -z "$APP_NAME" ]; then
    APP_NAME="marzban-node"
fi
if [ -z "$APP_NAME" ]; then
    SCRIPT_NAME=$(basename "$0")
    APP_NAME="${SCRIPT_NAME%.*}"
fi

INSTALL_DIR="/opt"
if [ -d "$INSTALL_DIR/$APP_NAME" ]; then
    APP_DIR="$INSTALL_DIR/$APP_NAME"
elif [ -d "$INSTALL_DIR/Marzban-node" ]; then
    APP_DIR="$INSTALL_DIR/Marzban-node"
else
    APP_DIR="$INSTALL_DIR/$APP_NAME"
fi

DATA_DIR="/var/lib/$APP_NAME"
DATA_MAIN_DIR="/var/lib/$APP_NAME"
COMPOSE_FILE="$APP_DIR/docker-compose.yml"
LAST_XRAY_CORES=5
CERT_FILE="$DATA_DIR/cert.pem"
FETCH_REPO="Gozargah/Marzban-scripts"
SCRIPT_URL="https://github.com/$FETCH_REPO/raw/master/marzban-node.sh"

# [HELPER FUNCTIONS - PRESERVED]
colorized_echo() {
    local color=$1
    local text=$2
    local style=${3:-0}
    case $color in
        "red") printf "\e[${style};91m${text}\e[0m\n" ;;
        "green") printf "\e[${style};92m${text}\e[0m\n" ;;
        "yellow") printf "\e[${style};93m${text}\e[0m\n" ;;
        "blue") printf "\e[${style};94m${text}\e[0m\n" ;;
        "magenta") printf "\e[${style};95m${text}\e[0m\n" ;;
        "cyan") printf "\e[${style};96m${text}\e[0m\n" ;;
        *) echo "${text}" ;;
    esac
}

check_running_as_root() {
    if [ "$(id -u)" != "0" ]; then
        colorized_echo red "This command must be run as root."
        exit 1
    fi
}

detect_os() {
    if [ -f /etc/lsb-release ]; then
        OS=$(lsb_release -si)
    elif [ -f /etc/os-release ]; then
        OS=$(awk -F= '/^NAME/{print $2}' /etc/os-release | tr -d '"')
    elif [ -f /etc/redhat-release ]; then
        OS=$(cat /etc/redhat-release | awk '{print $1}')
    elif [ -f /etc/arch-release ]; then
        OS="Arch"
    else
        colorized_echo red "Unsupported operating system"
        exit 1
    fi
}

detect_and_update_package_manager() {
    colorized_echo blue "Updating package manager"
    if [[ "$OS" == "Ubuntu"* ]] || [[ "$OS" == "Debian"* ]]; then
        PKG_MANAGER="apt-get"
        $PKG_MANAGER update -qq >/dev/null 2>&1
    elif [[ "$OS" == "CentOS"* ]] || [[ "$OS" == "AlmaLinux"* ]]; then
        PKG_MANAGER="yum"
        $PKG_MANAGER update -y -q >/dev/null 2>&1
        $PKG_MANAGER install -y -q epel-release >/dev/null 2>&1
    elif [[ "$OS" == "Fedora"* ]]; then
        PKG_MANAGER="dnf"
        $PKG_MANAGER update -q -y >/dev/null 2>&1
    elif [[ "$OS" == "Arch"* ]]; then
        PKG_MANAGER="pacman"
        $PKG_MANAGER -Sy --noconfirm --quiet >/dev/null 2>&1
    elif [[ "$OS" == "openSUSE"* ]]; then
        PKG_MANAGER="zypper"
        $PKG_MANAGER refresh --quiet >/dev/null 2>&1
    else
        colorized_echo red "Unsupported operating system"
        exit 1
    fi
}

detect_compose() {
    if docker compose >/dev/null 2>&1; then
        COMPOSE='docker compose'
    elif docker-compose >/dev/null 2>&1; then
        COMPOSE='docker-compose'
    else
        colorized_echo red "docker compose not found"
        exit 1
    fi
}

install_package () {
    if [ -z "$PKG_MANAGER" ]; then
        detect_and_update_package_manager
    fi
    PACKAGE=$1
    colorized_echo blue "Installing $PACKAGE"
    if [[ "$OS" == "Ubuntu"* ]] || [[ "$OS" == "Debian"* ]]; then
        $PKG_MANAGER -y -qq install "$PACKAGE" >/dev/null 2>&1
    elif [[ "$OS" == "CentOS"* ]] || [[ "$OS" == "AlmaLinux"* ]]; then
        $PKG_MANAGER install -y -q "$PACKAGE" >/dev/null 2>&1
    elif [[ "$OS" == "Fedora"* ]]; then
        $PKG_MANAGER install -y -q "$PACKAGE" >/dev/null 2>&1
    elif [[ "$OS" == "Arch"* ]]; then
        $PKG_MANAGER -S --noconfirm --quiet "$PACKAGE" >/dev/null 2>&1
    elif [[ "$OS" == "openSUSE"* ]]; then
        PKG_MANAGER="zypper"
        $PKG_MANAGER --quiet install -y "$PACKAGE" >/dev/null 2>&1
    else
        colorized_echo red "Unsupported operating system"
        exit 1
    fi
}

install_docker() {
    colorized_echo blue "Installing Docker"
    curl -fsSL https://get.docker.com | sh
    colorized_echo green "Docker installed successfully"
}

install_marzban_node_script() {
    colorized_echo blue "Installing marzban script"
    # Fix: Download explicitly to handle both curl pipe and local execution
    curl -sSL "https://raw.githubusercontent.com/waheedsabir/Marzban-node/refs/heads/master/auto_node.sh" > "/usr/local/bin/$APP_NAME"
    chmod 755 "/usr/local/bin/$APP_NAME"
    colorized_echo green "Marzban-node script installed successfully at /usr/local/bin/$APP_NAME"
}

# ==============================================================================
# MAIN MODIFICATION: Silent Install Function
# ==============================================================================
install_marzban_node() {
    mkdir -p "$DATA_DIR"
    mkdir -p "$APP_DIR"
    mkdir -p "$DATA_MAIN_DIR"
    
    if [ -f "$CERT_FILE" ]; then
        >"$CERT_FILE"
    fi
    
    # --- AUTO-INJECT CERTIFICATE ---
    echo "$HARDCODED_CERT" > "$CERT_FILE"
    echo "✅ Certificate saved (Auto-injected)"
    
    # --- AUTO-SELECT PROTOCOL ---
    # We use the hardcoded variable instead of prompting
    if [[ -z "$HARDCODED_PROTOCOL" || "$HARDCODED_PROTOCOL" =~ ^[Yy]$ ]]; then
        USE_REST=true
    else
        USE_REST=false
    fi
    
    # --- AUTO-SELECT PORTS ---
    SERVICE_PORT=$HARDCODED_SERVICE_PORT
    XRAY_API_PORT=$HARDCODED_XRAY_PORT

    colorized_echo blue "Generating compose file with Ports: $SERVICE_PORT / $XRAY_API_PORT"
    
    cat > "$COMPOSE_FILE" <<EOL
services:
  marzban-node:
    container_name: $APP_NAME
    image: gozargah/marzban-node:latest
    restart: always
    network_mode: host
    environment:
      SSL_CLIENT_CERT_FILE: "/var/lib/marzban-node/cert.pem"
      SERVICE_PORT: "$SERVICE_PORT"
      XRAY_API_PORT: "$XRAY_API_PORT"
EOL
    
    if [[ "$USE_REST" = true ]]; then
        cat >> "$COMPOSE_FILE" <<EOL
      SERVICE_PROTOCOL: "rest"
EOL
    fi
    
    cat >> "$COMPOSE_FILE" <<EOL

    volumes:
      - $DATA_MAIN_DIR:/var/lib/marzban
      - $DATA_DIR:/var/lib/marzban-node
EOL
    colorized_echo green "File saved in $APP_DIR/docker-compose.yml"
}

# [OTHER FUNCTIONS - PRESERVED AS IS]
uninstall_marzban_node_script() {
    if [ -f "/usr/local/bin/$APP_NAME" ]; then
        colorized_echo yellow "Removing marzban-node script"
        rm "/usr/local/bin/$APP_NAME"
    fi
}
uninstall_marzban_node() {
    if [ -d "$APP_DIR" ]; then
        colorized_echo yellow "Removing directory: $APP_DIR"
        rm -r "$APP_DIR"
    fi
}
uninstall_marzban_node_docker_images() {
    images=$(docker images | grep marzban-node | awk '{print $3}')
    if [ -n "$images" ]; then
        colorized_echo yellow "Removing Docker images of Marzban-node"
        for image in $images; do
            if docker rmi "$image" >/dev/null 2>&1; then
                colorized_echo yellow "Image $image removed"
            fi
        done
    fi
}
uninstall_marzban_node_data_files() {
    if [ -d "$DATA_DIR" ]; then
        colorized_echo yellow "Removing directory: $DATA_DIR"
        rm -r "$DATA_DIR"
    fi
}
up_marzban_node() {
    $COMPOSE -f $COMPOSE_FILE -p "$APP_NAME" up -d --remove-orphans
}
down_marzban_node() {
    $COMPOSE -f $COMPOSE_FILE -p "$APP_NAME" down
}
show_marzban_node_logs() {
    $COMPOSE -f $COMPOSE_FILE -p "$APP_NAME" logs
}
follow_marzban_node_logs() {
    $COMPOSE -f $COMPOSE_FILE -p "$APP_NAME" logs -f
}
update_marzban_node_script() {
    colorized_echo blue "Updating marzban-node script"
    curl -sSL $SCRIPT_URL | install -m 755 /dev/stdin /usr/local/bin/$APP_NAME
    colorized_echo green "marzban-node script updated successfully"
}
update_marzban_node() {
    $COMPOSE -f $COMPOSE_FILE -p "$APP_NAME" pull
}
is_marzban_node_installed() {
    if [ -d $APP_DIR ]; then return 0; else return 1; fi
}
is_marzban_node_up() {
    if [ -z "$($COMPOSE -f $COMPOSE_FILE ps -q -a)" ]; then return 1; else return 0; fi
}

# [COMMAND HANDLERS]
install_command() {
    check_running_as_root
    detect_os
    if ! command -v jq >/dev/null 2>&1; then install_package jq; fi
    if ! command -v curl >/dev/null 2>&1; then install_package curl; fi
    if ! command -v docker >/dev/null 2>&1; then install_docker; fi
    detect_compose
    install_marzban_node_script
    install_marzban_node
    
    # Apply Firewall Rules (Auto-Added)
    if command -v ufw >/dev/null 2>&1; then
        ufw allow 22/tcp
        ufw allow $SERVICE_PORT/tcp
        ufw allow $XRAY_API_PORT/tcp
        ufw allow 80,443,1080,2082,2083,2086,2087,8080,8443/tcp
        ufw allow 80,443,1080,2082,2083,2086,2087,8080,8443/udp
        ufw --force enable
    fi

    up_marzban_node
    echo "✅ Auto-Install Complete. Logs follow (Press Ctrl+C to exit logs):"
    follow_marzban_node_logs
}

uninstall_command() {
    check_running_as_root
    if ! is_marzban_node_installed; then colorized_echo red "Marzban-node not installed!"; exit 1; fi
    detect_compose
    if is_marzban_node_up; then down_marzban_node; fi
    uninstall_marzban_node_script
    uninstall_marzban_node
    uninstall_marzban_node_docker_images
    uninstall_marzban_node_data_files
}

up_command() {
    local no_logs=false
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -n|--no-logs) no_logs=true ;;
            *) shift ;;
        esac
        shift
    done
    if ! is_marzban_node_installed; then colorized_echo red "Marzban-node's not installed!"; exit 1; fi
    detect_compose
    up_marzban_node
    if [ "$no_logs" = false ]; then follow_marzban_node_logs; fi
}

down_command() {
    if ! is_marzban_node_installed; then colorized_echo red "Marzban-node not installed!"; exit 1; fi
    detect_compose
    down_marzban_node
}

restart_command() {
    local no_logs=false
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -n|--no-logs) no_logs=true ;;
            *) shift ;;
        esac
        shift
    done
    if ! is_marzban_node_installed; then colorized_echo red "Marzban-node not installed!"; exit 1; fi
    detect_compose
    down_marzban_node
    up_marzban_node
}

status_command() {
    if ! is_marzban_node_installed; then echo -n "Status: "; colorized_echo red "Not Installed"; exit 1; fi
    detect_compose
    if ! is_marzban_node_up; then echo -n "Status: "; colorized_echo blue "Down"; exit 1; fi
    echo -n "Status: "; colorized_echo green "Up"
    $COMPOSE -f $COMPOSE_FILE ps
}

logs_command() {
    local no_follow=false
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -n|--no-follow) no_follow=true ;;
            *) shift ;;
        esac
        shift
    done
    if ! is_marzban_node_installed; then colorized_echo red "Marzban-node's not installed!"; exit 1; fi
    detect_compose
    if ! is_marzban_node_up; then colorized_echo red "Marzban-node is not up."; exit 1; fi
    if [ "$no_follow" = true ]; then show_marzban_node_logs; else follow_marzban_node_logs; fi
}

# ==============================================================================
# MAIN EXECUTION
# If no command is provided, default to 'install' for the Bot.
# ==============================================================================

if [ -z "$COMMAND" ]; then
    COMMAND="install"
fi

case "$COMMAND" in
    install) install_command ;;
    update) update_marzban_node ;;
    uninstall) uninstall_command ;;
    up) up_command ;;
    down) down_command ;;
    restart) restart_command ;;
    status) status_command ;;
    logs) logs_command ;;
    install-script) install_marzban_node_script ;;
    uninstall-script) uninstall_marzban_node_script ;;
    *) usage ;;
esac
