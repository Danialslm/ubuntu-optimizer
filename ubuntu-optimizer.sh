#!/bin/bash
# https://github.com/hawshemi/Linux-Optimizer


clear


# Green, Yellow & Red Messages.
green_msg() {
    tput setaf 2
    echo "[*] ----- $1"
    tput sgr0
}

yellow_msg() {
    tput setaf 3
    echo "[*] ----- $1"
    tput sgr0
}

red_msg() {
    tput setaf 1
    echo "[*] ----- $1"
    tput sgr0
}


# Declare Paths & Settings.
SYS_PATH="/etc/sysctl.conf"
PROF_PATH="/etc/profile"
SSH_PORT=""
SSH_PATH="/etc/ssh/sshd_config"
SWAP_PATH="/swapfile"
SWAP_SIZE=2G
HOST_PATH="/etc/hosts"
DNS_PATH="/etc/resolv.conf"


# Intro
echo 
green_msg '================================================================='
green_msg 'This script will automatically Optimize your Ubuntu Server.'
green_msg 'Tested on: Ubuntu 20+'
green_msg 'Root access is required.' 
green_msg 'Source is @ https://github.com/hawshemi/linux-optimizer' 
green_msg '================================================================='
echo 


# Root
check_if_running_as_root() {
    ## If you want to run as another user, please modify $EUID to be owned by this user
    if [[ "$EUID" -ne '0' ]]; then
      echo 
      red_msg 'Error: You must run this script as root!'
      echo 
      sleep 0.5
      exit 1
    fi
}


# Check Root
check_if_running_as_root
sleep 0.5


# OS Detection. This script is for Ubuntu only.
check_os() {
    if [[ $(grep -oP '(?<=^NAME=").*(?=")' /etc/os-release) == "Ubuntu" ]]; then
        echo 
        sleep 0.5
        yellow_msg "OS: Ubuntu"
        echo 
        sleep 0.5
    else
        echo 
        sleep 0.5
        red_msg "This script only supports Ubuntu. Create an issue here: https://github.com/hawshemi/Linux-Optimizer"
        echo 
        sleep 2
        exit 1
    fi
}


# Check OS
check_os
sleep 0.5


# Install dependencies
install_dependencies() {
  echo 
  yellow_msg 'Installing Dependencies...'
  echo 
  sleep 0.5

  sudo apt update -q
  sudo apt install -yq wget curl sudo jq

  echo
  green_msg 'Dependencies Installed.'
  echo 
  sleep 0.5
}


# Fix Hosts file
fix_etc_hosts(){ 
  echo 
  yellow_msg "Fixing Hosts file."
  sleep 0.5

  cp $HOST_PATH /etc/hosts.bak
  yellow_msg "Default hosts file saved. Directory: /etc/hosts.bak"
  sleep 0.5

  if ! grep -q $(hostname) $HOST_PATH; then
    echo "127.0.1.1 $(hostname)" | sudo tee -a $HOST_PATH > /dev/null
    green_msg "Hosts Fixed."
    echo 
    sleep 0.5
  else
    green_msg "Hosts OK. No changes made."
    echo 
    sleep 0.5
  fi
}


# Fix DNS Temporarily
fix_dns(){
    echo 
    yellow_msg "Fixing DNS Temporarily."
    sleep 0.5

    cp $DNS_PATH /etc/resolv.conf.bak
    yellow_msg "Default resolv.conf file saved. Directory: /etc/resolv.conf.bak"
    sleep 0.5

    sed -i '/nameserver/d' $DNS_PATH

    echo "nameserver 1.1.1.2" >> $DNS_PATH
    echo "nameserver 1.0.0.2" >> $DNS_PATH
    echo "nameserver 127.0.0.53" >> $DNS_PATH

    green_msg "DNS Fixed Temporarily."
    echo 
    sleep 0.5
}


# Set the server TimeZone to the VPS IP address location.
set_timezone() {
    echo
    yellow_msg 'Setting TimeZone based on VPS IP address...'
    sleep 0.5

    get_location_info() {
        local ip_sources=("https://ipv4.icanhazip.com" "https://api.ipify.org" "https://ipv4.ident.me/")
        local location_info

        for source in "${ip_sources[@]}"; do
            local ip=$(curl -s "$source")
            if [ -n "$ip" ]; then
                location_info=$(curl -s "http://ip-api.com/json/$ip")
                if [ -n "$location_info" ]; then
                    echo "$location_info"
                    return 0
                fi
            fi
        done

        red_msg "Error: Failed to fetch location information from known sources. Setting timezone to UTC."
        sudo timedatectl set-timezone "UTC"
        return 1
    }

    # Fetch location information from three sources
    location_info_1=$(get_location_info)
    location_info_2=$(get_location_info)
    location_info_3=$(get_location_info)

    # Extract timezones from the location information
    timezones=($(echo "$location_info_1 $location_info_2 $location_info_3" | jq -r '.timezone'))

    # Check if at least two timezones are equal
    if [[ "${timezones[0]}" == "${timezones[1]}" || "${timezones[0]}" == "${timezones[2]}" || "${timezones[1]}" == "${timezones[2]}" ]]; then
        # Set the timezone based on the first matching pair
        timezone="${timezones[0]}"
        sudo timedatectl set-timezone "$timezone"
        green_msg "Timezone set to $timezone"
    else
        red_msg "Error: Failed to fetch consistent location information from known sources. Setting timezone to UTC."
        sudo timedatectl set-timezone "UTC"
    fi

    echo
    sleep 0.5
}


# Ask Reboot
ask_reboot() {
    yellow_msg 'Reboot now? (Recommended) (y/n)'
    echo 
    while true; do
        read choice
        echo 
        if [[ "$choice" == 'y' || "$choice" == 'Y' ]]; then
            sleep 0.5
            reboot
            exit 0
        fi
        if [[ "$choice" == 'n' || "$choice" == 'N' ]]; then
            break
        fi
    done
}


# Update & Upgrade & Remove & Clean
complete_update() {
    echo 
    yellow_msg 'Updating the System... (This can take a while.)'
    echo 
    sleep 0.5

    sudo apt -q update
    sudo apt -y upgrade
    sudo apt -y full-upgrade
    sudo apt -y autoremove
    sleep 0.5

    ## Again :D
    sudo apt -y -q autoclean
    sudo apt -y clean
    sudo apt -q update
    sudo apt -y upgrade
    sudo apt -y full-upgrade
    sudo apt -y autoremove --purge

    echo 
    green_msg 'System Updated & Cleaned Successfully.'
    echo 
    sleep 0.5
}


# Disable Terminal Ads
disable_terminal_ads() {
    echo 
    yellow_msg 'Disabling Terminal Ads...'
    echo 
    sleep 0.5

    sed -i 's/ENABLED=1/ENABLED=0/g' /etc/default/motd-news
    pro config set apt_news=false

    echo 
    green_msg 'Terminal Ads Disabled.'
    echo 
    sleep 0.5
}


# Install XanMod Kernel
# Follows the official instructions @ https://xanmod.org
install_xanmod() {
    echo 
    yellow_msg 'Checking XanMod...'
    echo 
    sleep 0.5

    if uname -r | grep -q 'xanmod'; then
        green_msg 'XanMod is already installed.'
        echo 
        sleep 0.5
        return 0
    fi

    echo 
    yellow_msg 'XanMod not found. Installing XanMod Kernel...'
    echo 
    sleep 0.5

    ## XanMod publishes 64-bit (amd64) builds only
    local arch
    arch=$(dpkg --print-architecture 2>/dev/null)
    if [ "$arch" != 'amd64' ]; then
        echo 
        red_msg "Unsupported architecture: ${arch:-unknown}. XanMod provides amd64 builds only."
        echo 
        sleep 2
        return 1
    fi

    ## Update, Upgrade & Install dependencies
    sudo apt update -q
    sudo apt upgrade -y
    sudo apt install wget curl gpg ca-certificates lsb-release -y

    ## Detect the distro codename. deb.xanmod.org is indexed by codename.
    local codename
    codename=$(lsb_release -sc 2>/dev/null)
    if [ -z "$codename" ]; then
        codename=$(. /etc/os-release 2>/dev/null && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
    fi

    ## Codenames currently published by XanMod
    local supported_codenames='bookworm trixie forky sid noble plucky questing resolute stonking faye gigi wilma xia zara zena'
    if ! echo " $supported_codenames " | grep -qF " $codename "; then
        echo 
        red_msg "XanMod has no repository for '${codename:-unknown}'."
        red_msg "Supported codenames: $supported_codenames"
        echo 
        sleep 2
        return 1
    fi

    ## Check the x86-64 psABI level (same logic as dl.xanmod.org/check_x86-64_psabi.sh)
    local cpu_level
    cpu_level=$(awk -f - <<'EOF'
BEGIN {
    while (!/flags/) if (getline < "/proc/cpuinfo" != 1) exit 1
    if (/lm/&&/cmov/&&/cx8/&&/fpu/&&/fxsr/&&/mmx/&&/syscall/&&/sse2/) level = 1
    if (level == 1 && /cx16/&&/lahf/&&/popcnt/&&/sse4_1/&&/sse4_2/&&/ssse3/) level = 2
    if (level == 2 && /avx/&&/avx2/&&/bmi1/&&/bmi2/&&/f16c/&&/fma/&&/abm/&&/movbe/&&/xsave/) level = 3
    if (level == 3 && /avx512f/&&/avx512bw/&&/avx512cd/&&/avx512dq/&&/avx512vl/) level = 4
    if (level > 0) { print level; exit level + 1 }
    exit 1
}
EOF
    )

    ## Map the CPU level to the packages to try, best build first.
    ## The main branch ships v2/v3 only, so v1 CPUs get the LTS build.
    ## v4 (AVX-512) has no kernel benefit, so it uses the v3 build.
    local pkgs
    case "$cpu_level" in
        4)
            pkgs='linux-xanmod-x64v3 linux-xanmod-lts-x64v3'
            yellow_msg "CPU Level: v4 (AVX-512, no kernel benefit). Using the x64v3 build."
            ;;
        3)
            pkgs='linux-xanmod-x64v3 linux-xanmod-lts-x64v3'
            yellow_msg "CPU Level: v3"
            ;;
        2)
            pkgs='linux-xanmod-x64v2 linux-xanmod-lts-x64v2'
            yellow_msg "CPU Level: v2"
            ;;
        1)
            pkgs='linux-xanmod-lts-x64v1'
            yellow_msg "CPU Level: v1. Only the LTS branch is built for this CPU."
            ;;
        *)
            echo 
            red_msg "Unsupported CPU. (Check the supported CPUs at xanmod.org)"
            echo 
            sleep 2
            return 1
            ;;
    esac
    echo 

    ## Register the XanMod PGP key
    local keyring='/etc/apt/keyrings/xanmod-archive-keyring.gpg'
    local key_fp='D38D7D1DA1349567ADED882D86F7D09EE734E623'
    local repo_list='/etc/apt/sources.list.d/xanmod-release.list'
    local tmp_key tmp_keyring
    tmp_key=$(mktemp)
    tmp_keyring=$(mktemp)

    sudo install -d -m 0755 /etc/apt/keyrings

    ## Alternative sources for the same key, tried in order.
    local key_urls=(
        'https://dl.xanmod.org/archive.key'
        'https://gitlab.com/afrd.gpg'
        "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x${key_fp}"
        "https://keys.openpgp.org/vks/v1/by-fingerprint/${key_fp}"
    )

    local key_ok=0 url
    for url in "${key_urls[@]}"; do
        yellow_msg "Fetching the XanMod key from ${url%%\?*} ..."

        ## 5 second timeout per request. wget first, curl as a fallback.
        if ! wget -q --timeout=5 --tries=1 -O "$tmp_key" "$url"; then
            curl -fsSL --connect-timeout 5 --max-time 5 -o "$tmp_key" "$url" || continue
        fi
        [ -s "$tmp_key" ] || continue

        ## Normalize to a binary keyring and verify it really is XanMod's key,
        ## so an error page or a truncated download can never reach APT.
        gpg --dearmor < "$tmp_key" > "$tmp_keyring" 2>/dev/null || continue
        if gpg --show-keys --with-colons "$tmp_keyring" 2>/dev/null | grep -q "^fpr:.*:${key_fp}:"; then
            key_ok=1
            break
        fi

        red_msg 'Downloaded key does not match the XanMod fingerprint. Trying the next source...'
    done

    rm -f "$tmp_key"

    if [ "$key_ok" -ne 1 ]; then
        rm -f "$tmp_keyring"
        echo 
        red_msg 'Failed to fetch the XanMod PGP key from every source. Skipping XanMod.'
        echo 
        sleep 2
        return 1
    fi

    sudo install -m 0644 "$tmp_keyring" "$keyring"
    rm -f "$tmp_keyring"

    ## Drop the keyring from the old location, if it is still around.
    sudo rm -f /usr/share/keyrings/xanmod-archive-keyring.gpg

    ## Add the XanMod repository
    echo "deb [signed-by=$keyring] http://deb.xanmod.org $codename main" | sudo tee "$repo_list" > /dev/null

    ## Install XanMod
    local pkg installed_pkg=''
    if sudo apt update -q; then
        for pkg in $pkgs; do
            if apt-cache policy "$pkg" 2>/dev/null | grep -q 'Candidate: [^(]'; then
                echo 
                yellow_msg "Installing $pkg ..."
                echo 
                if sudo apt install "$pkg" -y; then
                    installed_pkg="$pkg"
                    break
                fi
            fi
        done
    fi

    if [ -z "$installed_pkg" ]; then
        ## Leave no broken repository behind.
        sudo rm -f "$repo_list"
        sudo apt update -q
        echo 
        red_msg 'XanMod installation failed. The XanMod repository has been removed.'
        echo 
        sleep 2
        return 1
    fi

    ## Clean up
    sudo apt update -q
    sudo apt autoremove --purge -y

    echo 
    green_msg "XanMod Kernel ($installed_pkg) Installed. Reboot to Apply the new Kernel."
    echo 
    sleep 1
}


# Install useful packages
installations() {
    echo 
    yellow_msg 'Installing Useful Packages...'
    echo 
    sleep 0.5

    ## System utilities
    sudo apt -y install curl ufw vim wget zip iptables iftop resolvconf nload htop iperf3 net-tools
    
    echo 
    green_msg 'Useful Packages Installed Succesfully.'
    echo 
    sleep 0.5
}


## Swap Maker
swap_maker() {
    echo 
    yellow_msg 'Making SWAP Space...'
    echo 
    sleep 0.5

    ## Make Swap
    sudo fallocate -l $SWAP_SIZE $SWAP_PATH  ## Allocate size
    sudo chmod 600 $SWAP_PATH                ## Set proper permission
    sudo mkswap $SWAP_PATH                   ## Setup swap         
    sudo swapon $SWAP_PATH                   ## Enable swap
    echo "$SWAP_PATH   none    swap    sw    0   0" >> /etc/fstab ## Add to fstab
    echo 
    green_msg 'SWAP Created Successfully.'
    echo
    sleep 0.5
}


# SYSCTL Optimization
sysctl_optimizations() {
    ## Make a backup of the original sysctl.conf file
    cp $SYS_PATH /etc/sysctl.conf.bak

    echo 
    yellow_msg 'Default sysctl.conf file Saved. Directory: /etc/sysctl.conf.bak'
    echo 
    sleep 1

    echo 
    yellow_msg 'Optimizing the Network...'
    echo 
    sleep 0.5

    sed -i -e '/fs.file-max/d' \
        -e '/net.core.default_qdisc/d' \
        -e '/net.core.netdev_max_backlog/d' \
        -e '/net.core.optmem_max/d' \
        -e '/net.core.somaxconn/d' \
        -e '/net.core.rmem_max/d' \
        -e '/net.core.wmem_max/d' \
        -e '/net.core.rmem_default/d' \
        -e '/net.core.wmem_default/d' \
        -e '/net.ipv4.tcp_rmem/d' \
        -e '/net.ipv4.tcp_wmem/d' \
        -e '/net.ipv4.tcp_congestion_control/d' \
        -e '/net.ipv4.tcp_fastopen/d' \
        -e '/net.ipv4.tcp_fin_timeout/d' \
        -e '/net.ipv4.tcp_keepalive_time/d' \
        -e '/net.ipv4.tcp_keepalive_probes/d' \
        -e '/net.ipv4.tcp_keepalive_intvl/d' \
        -e '/net.ipv4.tcp_max_orphans/d' \
        -e '/net.ipv4.tcp_max_syn_backlog/d' \
        -e '/net.ipv4.tcp_max_tw_buckets/d' \
        -e '/net.ipv4.tcp_mem/d' \
        -e '/net.ipv4.tcp_mtu_probing/d' \
        -e '/net.ipv4.tcp_notsent_lowat/d' \
        -e '/net.ipv4.tcp_retries2/d' \
        -e '/net.ipv4.tcp_sack/d' \
        -e '/net.ipv4.tcp_dsack/d' \
        -e '/net.ipv4.tcp_slow_start_after_idle/d' \
        -e '/net.ipv4.tcp_window_scaling/d' \
        -e '/net.ipv4.tcp_adv_win_scale/d' \
        -e '/net.ipv4.tcp_ecn/d' \
        -e '/net.ipv4.tcp_ecn_fallback/d' \
        -e '/net.ipv4.tcp_syncookies/d' \
        -e '/net.ipv4.udp_mem/d' \
        -e '/net.ipv6.conf.all.disable_ipv6/d' \
        -e '/net.ipv6.conf.default.disable_ipv6/d' \
        -e '/net.ipv6.conf.lo.disable_ipv6/d' \
        -e '/net.unix.max_dgram_qlen/d' \
        -e '/vm.min_free_kbytes/d' \
        -e '/vm.swappiness/d' \
        -e '/vm.vfs_cache_pressure/d' \
        -e '/net.ipv4.conf.default.rp_filter/d' \
        -e '/net.ipv4.conf.all.rp_filter/d' \
        -e '/net.ipv4.conf.all.accept_source_route/d' \
        -e '/net.ipv4.conf.default.accept_source_route/d' \
        -e '/net.ipv4.neigh.default.gc_thresh1/d' \
        -e '/net.ipv4.neigh.default.gc_thresh2/d' \
        -e '/net.ipv4.neigh.default.gc_thresh3/d' \
        -e '/net.ipv4.neigh.default.gc_stale_time/d' \
        -e '/net.ipv4.conf.default.arp_announce/d' \
        -e '/net.ipv4.conf.lo.arp_announce/d' \
        -e '/net.ipv4.conf.all.arp_announce/d' \
        -e '/kernel.panic/d' \
        -e '/vm.dirty_ratio/d' \
        -e '/vm.overcommit_memory/d' \
        -e '/vm.overcommit_ratio/d' \
        -e '/^#/d' \
        -e '/^$/d' \
        "$SYS_PATH"


    ## Add new parameters. Read More: https://github.com/hawshemi/Linux-Optimizer/blob/main/files/sysctl.conf

cat <<EOF >> "$SYS_PATH"


################################################################
################################################################


net.ipv4.tcp_rmem="4096 87380 134217728"
net.ipv4.tcp_wmem="4096 65536 134217728"
net.core.default_qdisc=fq_codel
net.netfilter.nf_conntrack_max=4048576
net.ipv4.ip_local_port_range="10240 65535"
net.core.somaxconn=65535
net.core.rmem_max=268435456
net.core.wmem_max=268435456
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_max_syn_backlog=65535
net.ipv4.tcp_mem="2097152 3145728 4194304"
net.ipv4.tcp_slow_start_after_idle=0
fs.file-max=2048576

################################################################
################################################################


EOF

    sudo sysctl -p
    
    echo 
    green_msg 'Network is Optimized.'
    echo 
    sleep 0.5
}


# Function to find the SSH port and set it in the SSH_PORT variable
find_ssh_port() {
    echo 
    yellow_msg "Finding SSH port..."
    echo 
    
    ## Check if the SSH configuration file exists
    if [ -e "$SSH_PATH" ]; then
        ## Use grep to search for the 'Port' directive in the SSH configuration file
        SSH_PORT=$(grep -oP '^Port\s+\K\d+' "$SSH_PATH" 2>/dev/null)

        if [ -n "$SSH_PORT" ]; then
            echo 
            green_msg "SSH port found: $SSH_PORT"
            echo 
            sleep 0.5
        else
            echo 
            green_msg "SSH port is default 22."
            echo 
            SSH_PORT=22
            sleep 0.5
        fi
    else
        red_msg "SSH configuration file not found at $SSH_PATH"
    fi
}


# Remove old SSH config to prevent duplicates.
remove_old_ssh_conf() {
    ## Make a backup of the original sshd_config file
    cp $SSH_PATH /etc/ssh/sshd_config.bak

    echo 
    yellow_msg 'Default SSH Config file Saved. Directory: /etc/ssh/sshd_config.bak'
    echo 
    sleep 1

    ## Remove these lines
    sed -i -e 's/#UseDNS yes/UseDNS no/' \
        -e 's/#Compression no/Compression yes/' \
        -e 's/Ciphers .*/Ciphers aes256-ctr,chacha20-poly1305@openssh.com/' \
        -e '/MaxAuthTries/d' \
        -e '/MaxSessions/d' \
        -e '/TCPKeepAlive/d' \
        -e '/ClientAliveInterval/d' \
        -e '/ClientAliveCountMax/d' \
        -e '/AllowAgentForwarding/d' \
        -e '/AllowTcpForwarding/d' \
        -e '/GatewayPorts/d' \
        -e '/PermitTunnel/d' \
        -e '/X11Forwarding/d' "$SSH_PATH"

}
# Update SSH config
update_sshd_conf() {
    echo 
    yellow_msg 'Optimizing SSH...'
    echo 
    sleep 0.5

    ## Enable TCP keep-alive messages
    echo "TCPKeepAlive yes" | tee -a "$SSH_PATH"

    ## Configure client keep-alive messages
    echo "ClientAliveInterval 3000" | tee -a "$SSH_PATH"
    echo "ClientAliveCountMax 100" | tee -a "$SSH_PATH"

    ## Allow TCP forwarding
    echo "AllowTcpForwarding yes" | tee -a "$SSH_PATH"

    ## Enable gateway ports
    echo "GatewayPorts yes" | tee -a "$SSH_PATH"

    ## Enable tunneling
    echo "PermitTunnel yes" | tee -a "$SSH_PATH"

    ## Enable X11 graphical interface forwarding
    echo "X11Forwarding yes" | tee -a "$SSH_PATH"

    ## Restart the SSH service to apply the changes
    sudo systemctl restart ssh

    echo 
    green_msg 'SSH is Optimized.'
    echo 
    sleep 0.5
}


# System Limits Optimizations
limits_optimizations() {
    echo
    yellow_msg 'Optimizing System Limits...'
    echo 
    sleep 0.5

    ## Clear old ulimits
    sed -i '/ulimit -c/d' $PROF_PATH
    sed -i '/ulimit -d/d' $PROF_PATH
    sed -i '/ulimit -f/d' $PROF_PATH
    sed -i '/ulimit -i/d' $PROF_PATH
    sed -i '/ulimit -l/d' $PROF_PATH
    sed -i '/ulimit -m/d' $PROF_PATH
    sed -i '/ulimit -n/d' $PROF_PATH
    sed -i '/ulimit -q/d' $PROF_PATH
    sed -i '/ulimit -s/d' $PROF_PATH
    sed -i '/ulimit -t/d' $PROF_PATH
    sed -i '/ulimit -u/d' $PROF_PATH
    sed -i '/ulimit -v/d' $PROF_PATH
    sed -i '/ulimit -x/d' $PROF_PATH
    sed -i '/ulimit -s/d' $PROF_PATH


    ## Add new ulimits
    ## The maximum size of core files created.
    echo "ulimit -c unlimited" | tee -a $PROF_PATH

    ## The maximum size of a process's data segment
    echo "ulimit -d unlimited" | tee -a $PROF_PATH

    ## The maximum size of files created by the shell (default option)
    echo "ulimit -f unlimited" | tee -a $PROF_PATH

    ## The maximum number of pending signals
    echo "ulimit -i unlimited" | tee -a $PROF_PATH

    ## The maximum size that may be locked into memory
    echo "ulimit -l unlimited" | tee -a $PROF_PATH

    ## The maximum memory size
    echo "ulimit -m unlimited" | tee -a $PROF_PATH

    ## The maximum number of open file descriptors
    echo "ulimit -n 1048576" | tee -a $PROF_PATH

    ## The maximum POSIX message queue size
    echo "ulimit -q unlimited" | tee -a $PROF_PATH

    ## The maximum stack size
    echo "ulimit -s -H 65536" | tee -a $PROF_PATH
    echo "ulimit -s 32768" | tee -a $PROF_PATH

    ## The maximum number of seconds to be used by each process.
    echo "ulimit -t unlimited" | tee -a $PROF_PATH

    ## The maximum number of processes available to a single user
    echo "ulimit -u unlimited" | tee -a $PROF_PATH

    ## The maximum amount of virtual memory available to the process
    echo "ulimit -v unlimited" | tee -a $PROF_PATH

    ## The maximum number of file locks
    echo "ulimit -x unlimited" | tee -a $PROF_PATH


    echo 
    green_msg 'System Limits are Optimized.'
    echo 
    sleep 0.5
}


# UFW Optimizations
ufw_optimizations() {
    echo
    yellow_msg 'Installing & Optimizing UFW...'
    echo 
    sleep 0.5

    ## Purge firewalld to install UFW.
    sudo apt -y purge firewalld
    
    ## Install UFW if it isn't installed.
    sudo apt update -q
    sudo apt install -y ufw

    ## Disable UFW
    sudo ufw disable

    ## Open default ports.
    sudo ufw allow $SSH_PORT
    sudo ufw allow 80/tcp
    sudo ufw allow 80/udp
    sudo ufw allow 443/tcp
    sudo ufw allow 443/udp
    sleep 0.5

    ## Change the UFW config to use System config.
    sed -i 's+/etc/ufw/sysctl.conf+/etc/sysctl.conf+gI' /etc/default/ufw

    ## Enable & Reload
    echo "y" | sudo ufw enable
    sudo ufw reload
    echo 
    green_msg 'UFW is Installed & Optimized. (Open your custom ports manually.)'
    echo 
    sleep 0.5
}


# Install the latest Nginx from the official repository
# Follows the official instructions @ https://nginx.org/en/linux_packages.html
install_nginx() {
    echo 
    yellow_msg 'Installing the latest Nginx...'
    echo 
    sleep 0.5

    if command -v nginx > /dev/null 2>&1; then
        yellow_msg "Current version: $(nginx -v 2>&1 | sed 's|.*/||')"
        echo 
        sleep 0.5
    fi

    ## Install the dependencies documented by nginx.org
    sudo apt update -q
    sudo apt install curl gnupg2 ca-certificates lsb-release ubuntu-keyring wget -y

    ## Detect the distro codename. nginx.org is indexed by codename.
    local codename
    codename=$(lsb_release -cs 2>/dev/null)
    if [ -z "$codename" ]; then
        codename=$(. /etc/os-release 2>/dev/null && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
    fi

    if [ -z "$codename" ]; then
        echo 
        red_msg 'Could not detect the distro codename. Skipping Nginx.'
        echo 
        sleep 2
        return 1
    fi

    ## Fetch the Nginx signing key
    local keyring='/usr/share/keyrings/nginx-archive-keyring.gpg'
    local repo_list='/etc/apt/sources.list.d/nginx.list'
    local repo_pref='/etc/apt/preferences.d/99nginx'

    ## Nginx signing keys. The first one signs the current repositories,
    ## the others are kept so older suites keep verifying.
    local key_fp='8540A6F18833A80E9C1653A42FD21310B49F6B46'
    local old_key_fps='573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62 9E9BE90EACBCDE69FE9B204CBCDCD8A38D88A2B3'

    local tmp_key tmp_keyring
    tmp_key=$(mktemp)
    tmp_keyring=$(mktemp)

    ## Alternative sources for the same keys, tried in order.
    local key_urls=(
        'https://nginx.org/keys/nginx_signing.key'
        'https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x'
        'https://keys.openpgp.org/vks/v1/by-fingerprint/'
    )

    local key_ok=0 url fp
    for url in "${key_urls[@]}"; do
        yellow_msg "Fetching the Nginx key from ${url%%\?*} ..."
        : > "$tmp_key"

        case "$url" in
            *keys/nginx_signing.key)
                ## 5 second timeout per request. wget first, curl as a fallback.
                if ! wget -q --timeout=5 --tries=1 -O "$tmp_key" "$url"; then
                    curl -fsSL --connect-timeout 5 --max-time 5 -o "$tmp_key" "$url" || continue
                fi
                ;;
            *)
                ## Keyservers hand out one key at a time, so collect them all.
                for fp in $key_fp $old_key_fps; do
                    if ! wget -q --timeout=5 --tries=1 -O - "${url}${fp}" >> "$tmp_key"; then
                        curl -fsSL --connect-timeout 5 --max-time 5 "${url}${fp}" >> "$tmp_key"
                    fi
                done
                ;;
        esac
        [ -s "$tmp_key" ] || continue

        ## Normalize to a binary keyring and verify it really is Nginx's key,
        ## so an error page or a truncated download can never reach APT.
        gpg --dearmor < "$tmp_key" > "$tmp_keyring" 2>/dev/null || continue
        if gpg --show-keys --with-colons "$tmp_keyring" 2>/dev/null | grep -q "^fpr:.*:${key_fp}:"; then
            key_ok=1
            break
        fi

        red_msg 'Downloaded key does not match the Nginx fingerprint. Trying the next source...'
    done

    rm -f "$tmp_key"

    if [ "$key_ok" -ne 1 ]; then
        rm -f "$tmp_keyring"
        echo 
        red_msg 'Failed to fetch the Nginx signing key from every source. Skipping Nginx.'
        echo 
        sleep 2
        return 1
    fi

    sudo install -m 0644 "$tmp_keyring" "$keyring"
    rm -f "$tmp_keyring"

    ## Show what was imported
    echo 
    gpg --dry-run --quiet --no-keyring --import --import-options import-show "$keyring"
    echo 

    ## Add the Nginx repository
    echo "deb [signed-by=$keyring] http://nginx.org/packages/ubuntu $codename nginx" | sudo tee "$repo_list" > /dev/null

    ## Prefer the nginx.org packages over the ones shipped by the distro
    printf 'Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n' | sudo tee "$repo_pref" > /dev/null

    ## Install Nginx
    local installed=0
    if sudo apt update -q; then
        if apt-cache policy nginx 2>/dev/null | grep -q 'Candidate: [^(]'; then
            if ! apt-cache policy nginx 2>/dev/null | grep -q 'nginx.org'; then
                yellow_msg 'The nginx.org packages are not the candidate. Installing the available one.'
            fi
            sudo apt install nginx -y && installed=1
        fi
    fi

    if [ "$installed" -ne 1 ]; then
        ## Leave no broken repository behind.
        sudo rm -f "$repo_list" "$repo_pref"
        sudo apt update -q
        echo 
        red_msg "Nginx installation failed. (nginx.org may not publish packages for '$codename'.)"
        red_msg 'The Nginx repository has been removed.'
        echo 
        sleep 2
        return 1
    fi

    ## Enable & Start
    sudo systemctl enable nginx > /dev/null 2>&1
    sudo systemctl restart nginx

    echo 
    if systemctl is-active --quiet nginx; then
        green_msg "Nginx $(nginx -v 2>&1 | sed 's|.*/||') Installed & Running."
    else
        red_msg "Nginx $(nginx -v 2>&1 | sed 's|.*/||') Installed, but the service is not running. Check: systemctl status nginx"
    fi
    echo 
    sleep 1
}


# Install Docker & Docker Compose from the official repository
# Follows the official instructions @ https://docs.docker.com/engine/install/ubuntu
install_docker() {
    echo 
    yellow_msg 'Installing Docker & Docker Compose...'
    echo 
    sleep 0.5

    if command -v docker > /dev/null 2>&1; then
        yellow_msg "Current version: $(docker --version 2>/dev/null)"
        echo 
        sleep 0.5
    fi

    ## Install the dependencies documented by Docker
    sudo apt update -q
    sudo apt install ca-certificates curl gnupg wget -y

    ## Detect the distro codename. download.docker.com is indexed by codename.
    local codename
    codename=$(. /etc/os-release 2>/dev/null && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
    if [ -z "$codename" ]; then
        codename=$(lsb_release -cs 2>/dev/null)
    fi

    if [ -z "$codename" ]; then
        echo 
        red_msg 'Could not detect the distro codename. Skipping Docker.'
        echo 
        sleep 2
        return 1
    fi

    ## Fetch the Docker signing key
    local keyring='/etc/apt/keyrings/docker.gpg'
    local repo_list='/etc/apt/sources.list.d/docker.list'
    local key_fp='9DC858229FC7DD38854AE2D88D81803C0EBFCD88'

    local tmp_key tmp_keyring
    tmp_key=$(mktemp)
    tmp_keyring=$(mktemp)

    sudo install -m 0755 -d /etc/apt/keyrings

    ## Alternative sources for the same key, tried in order.
    local key_urls=(
        'https://download.docker.com/linux/ubuntu/gpg'
        "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x${key_fp}"
        "https://keys.openpgp.org/vks/v1/by-fingerprint/${key_fp}"
    )

    local key_ok=0 url
    for url in "${key_urls[@]}"; do
        yellow_msg "Fetching the Docker key from ${url%%\?*} ..."

        ## 5 second timeout per request. wget first, curl as a fallback.
        if ! wget -q --timeout=5 --tries=1 -O "$tmp_key" "$url"; then
            curl -fsSL --connect-timeout 5 --max-time 5 -o "$tmp_key" "$url" || continue
        fi
        [ -s "$tmp_key" ] || continue

        ## Normalize to a binary keyring and verify it really is Docker's key,
        ## so an error page or a truncated download can never reach APT.
        gpg --dearmor < "$tmp_key" > "$tmp_keyring" 2>/dev/null || continue
        if gpg --show-keys --with-colons "$tmp_keyring" 2>/dev/null | grep -q "^fpr:.*:${key_fp}:"; then
            key_ok=1
            break
        fi

        red_msg 'Downloaded key does not match the Docker fingerprint. Trying the next source...'
    done

    rm -f "$tmp_key"

    if [ "$key_ok" -ne 1 ]; then
        rm -f "$tmp_keyring"
        echo 
        red_msg 'Failed to fetch the Docker signing key from every source. Skipping Docker.'
        echo 
        sleep 2
        return 1
    fi

    sudo install -m 0644 "$tmp_keyring" "$keyring"
    sudo chmod a+r "$keyring"
    rm -f "$tmp_keyring"

    ## Add the Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=$keyring] https://download.docker.com/linux/ubuntu $codename stable" | sudo tee "$repo_list" > /dev/null

    ## Install Docker Engine, CLI, containerd, Buildx & Compose
    local installed=0
    if sudo apt update -q; then
        if apt-cache policy docker-ce 2>/dev/null | grep -q 'Candidate: [^(]'; then
            sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y && installed=1
        fi
    fi

    if [ "$installed" -ne 1 ]; then
        ## Leave no broken repository behind.
        sudo rm -f "$repo_list"
        sudo apt update -q
        echo 
        red_msg "Docker installation failed. (Docker may not publish packages for '$codename'.)"
        red_msg 'The Docker repository has been removed.'
        echo 
        sleep 2
        return 1
    fi

    ## Enable & Start
    sudo systemctl enable docker > /dev/null 2>&1
    sudo systemctl restart docker

    echo 
    if systemctl is-active --quiet docker; then
        green_msg "$(docker --version 2>/dev/null) Installed & Running."
    else
        red_msg "$(docker --version 2>/dev/null) Installed, but the service is not running. Check: systemctl status docker"
    fi
    green_msg "$(docker compose version 2>/dev/null) Installed."
    echo 
    sleep 1
}


# Install PasarGuard Node
# Follows the official installer @ https://github.com/PasarGuard/scripts
install_pasarguard_node() {
    echo 
    yellow_msg 'Installing PasarGuard Node...'
    echo 
    sleep 0.5

    local app_dir='/opt/pg-node'
    local data_dir='/var/lib/pg-node'
    local assets_dir="$data_dir/assets"
    local compose_file="$app_dir/docker-compose.yml"
    local env_file="$app_dir/.env"
    local cert_file="$data_dir/certs/ssl_cert.pem"
    local installer_url='https://github.com/PasarGuard/scripts/raw/main/pg-node.sh'

    sudo apt update -q
    sudo apt install curl wget ca-certificates -y

    ## Fetch the official installer. (It pulls in Docker itself when missing.)
    local installer
    installer=$(mktemp)

    yellow_msg 'Downloading the PasarGuard Node installer...'
    if ! wget -q --timeout=5 --tries=2 -O "$installer" "$installer_url"; then
        curl -fsSL --connect-timeout 5 -o "$installer" "$installer_url"
    fi

    if [ ! -s "$installer" ]; then
        rm -f "$installer"
        echo 
        red_msg 'Failed to download the PasarGuard Node installer. Skipping.'
        echo 
        sleep 2
        return 1
    fi

    ## Run it. The installer is interactive: it asks for the service port,
    ## the certificate type and the API key.
    echo 
    sudo bash "$installer" install
    rm -f "$installer"

    if [ ! -f "$compose_file" ]; then
        echo 
        red_msg 'PasarGuard Node was not installed. Skipping the assets setup.'
        echo 
        sleep 2
        return 1
    fi

    ## Download the Xray assets
    echo 
    yellow_msg 'Downloading Xray assets...'
    echo 
    sleep 0.5

    sudo mkdir -p "$assets_dir"

    ## "filename|url|alternative url"
    local assets=(
        "dlc.dat|https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat|https://cdn.jsdelivr.net/gh/v2fly/domain-list-community@release/dlc.dat"
        "geosite.dat|https://cdn.jsdelivr.net/gh/chocolate4u/Iran-v2ray-rules@release/geosite.dat|https://github.com/chocolate4u/Iran-v2ray-rules/releases/latest/download/geosite.dat"
        "geoip.dat|https://cdn.jsdelivr.net/gh/chocolate4u/Iran-v2ray-rules@release/geoip.dat|https://github.com/chocolate4u/Iran-v2ray-rules/releases/latest/download/geoip.dat"
        "security-ip.dat|https://cdn.jsdelivr.net/gh/chocolate4u/Iran-v2ray-rules@release/security-ip.dat|https://github.com/chocolate4u/Iran-v2ray-rules/releases/latest/download/security-ip.dat"
        "security.dat|https://cdn.jsdelivr.net/gh/chocolate4u/Iran-v2ray-rules@release/security.dat|https://github.com/chocolate4u/Iran-v2ray-rules/releases/latest/download/security.dat"
        "iran.dat|https://github.com/bootmortis/iran-hosted-domains/releases/latest/download/iran.dat|"
    )

    local asset name url alt_url tmp_asset failed=0
    for asset in "${assets[@]}"; do
        name="${asset%%|*}"
        url="${asset#*|}"
        alt_url="${url#*|}"
        url="${url%%|*}"

        tmp_asset=$(mktemp)

        ## 5 second connect timeout per request, with a mirror as a fallback.
        if ! wget -q --timeout=5 --tries=2 -O "$tmp_asset" "$url" || [ ! -s "$tmp_asset" ]; then
            if [ -n "$alt_url" ]; then
                yellow_msg "$name: primary source failed, trying the mirror..."
                wget -q --timeout=5 --tries=2 -O "$tmp_asset" "$alt_url" > /dev/null 2>&1
            fi
        fi

        if [ -s "$tmp_asset" ]; then
            ## Only replace the file once the download is complete.
            sudo install -m 0644 "$tmp_asset" "$assets_dir/$name"
            green_msg "$name downloaded."
        else
            red_msg "Failed to download $name."
            failed=$((failed + 1))
        fi

        rm -f "$tmp_asset"
    done

    ## Mount the assets into the container. The mount shadows the image's own
    ## asset directory, so it is only added when Xray's two required files are
    ## in place.
    echo 
    if [ ! -s "$assets_dir/geoip.dat" ] || [ ! -s "$assets_dir/geosite.dat" ]; then
        red_msg 'geoip.dat / geosite.dat are missing. Skipping the assets volume to keep Xray working.'
        red_msg "Download them into $assets_dir and re-run this option."
    elif grep -q "$assets_dir:/usr/local/share/xray" "$compose_file"; then
        yellow_msg 'Assets volume is already mounted.'
    else
        local tmp_compose
        tmp_compose=$(mktemp)
        awk -v line="      - $assets_dir:/usr/local/share/xray" '
            { print }
            /^[[:space:]]*volumes:[[:space:]]*$/ && !inserted { print line; inserted = 1 }
        ' "$compose_file" > "$tmp_compose"

        if grep -q "$assets_dir:/usr/local/share/xray" "$tmp_compose"; then
            sudo install -m 0644 "$tmp_compose" "$compose_file"
            green_msg 'Assets volume added to docker-compose.yml.'
        else
            red_msg "No 'volumes:' section found in $compose_file. Add the mount manually."
        fi

        rm -f "$tmp_compose"
    fi

    if [ "$failed" -ne 0 ]; then
        echo 
        red_msg "$failed asset(s) could not be downloaded."
    fi

    ## Restart to apply
    echo 
    yellow_msg 'Restarting PasarGuard Node...'
    echo 
    sudo pg-node restart

    ## Show the Certificate & the API Key
    echo 
    green_msg '================================================================='
    green_msg 'Certificate: (Use it in the PasarGuard Panel.)'
    green_msg '================================================================='
    echo 
    if [ -f "$cert_file" ]; then
        sudo cat "$cert_file"
    else
        red_msg "Certificate not found at $cert_file"
    fi

    local api_key=''
    if [ -f "$env_file" ]; then
        api_key=$(sudo grep -E '^[[:space:]]*API_KEY[[:space:]]*=' "$env_file" | head -n1 | sed 's/^[[:space:]]*API_KEY[[:space:]]*=[[:space:]]*//;s/[[:space:]]*$//')
    fi

    echo 
    green_msg '================================================================='
    green_msg 'API Key (UUID): (Use it in the PasarGuard Panel.)'
    green_msg '================================================================='
    echo 
    if [ -n "$api_key" ]; then
        yellow_msg "$api_key"
    else
        red_msg "API Key not found in $env_file"
    fi
    echo 
    sleep 1
}


# Menu Options
LAST_OPTION=12

# Options that need a reboot afterwards
REBOOT_OPTIONS=' 1 3 4 5 8 '


# Title of an Option
option_title() {
    case "$1" in
        1)  echo 'Complete Update & Clean the OS.' ;;
        2)  echo 'Disable Terminal Ads.' ;;
        3)  echo 'Install XanMod Kernel.' ;;
        4)  echo 'Install Useful Packages.' ;;
        5)  echo 'Make SWAP (2Gb).' ;;
        6)  echo 'Optimize the Network settings.' ;;
        7)  echo 'Optimize the SSH settings.' ;;
        8)  echo 'Optimize the System Limits.' ;;
        9)  echo 'Install & Optimize UFW.' ;;
        10) echo 'Install the Latest Nginx.' ;;
        11) echo 'Install Docker & Docker Compose.' ;;
        12) echo 'Install PasarGuard Node.' ;;
    esac
}


# Run a Single Option
run_option() {
    case "$1" in
        1)  complete_update ;;
        2)  disable_terminal_ads ;;
        3)  install_xanmod ;;
        4)  installations ;;
        5)  swap_maker ;;
        6)  sysctl_optimizations ;;
        7)  remove_old_ssh_conf
            sleep 0.5
            update_sshd_conf ;;
        8)  limits_optimizations ;;
        9)  find_ssh_port
            ufw_optimizations ;;
        10) install_nginx ;;
        11) install_docker ;;
        12) install_pasarguard_node ;;
    esac
}


# Show the Menu
show_menu() {
    echo 
    yellow_msg 'Choose One or More Options: '
    echo 
    green_msg "1  - $(option_title 1)"
    green_msg "2  - $(option_title 2)"
    green_msg "3  - $(option_title 3)"
    green_msg "4  - $(option_title 4)"
    green_msg "5  - $(option_title 5)"
    echo 
    green_msg "6  - $(option_title 6)"
    green_msg "7  - $(option_title 7)"
    green_msg "8  - $(option_title 8)"
    green_msg "9  - $(option_title 9)"
    echo 
    green_msg "10 - $(option_title 10)"
    green_msg "11 - $(option_title 11)"
    green_msg "12 - $(option_title 12)"
    echo 
    red_msg 'q - Exit.'
    echo 
    yellow_msg 'Enter one or more options, separated by commas. e.g. 1,3,5'
    yellow_msg 'For a full optimization, enter: 1,2,3,4,5,6,7,8,9'
    echo 
}


# Choosing Program
main() {
    local input choice choices invalid reboot_needed

    while true; do
        show_menu
        read -p 'Enter Your Choice(s): ' input

        ## Exit
        if [[ "$input" =~ ^[[:space:]]*[qQ][[:space:]]*$ ]]; then
            exit 0
        fi

        ## Accept commas and/or spaces as separators. e.g. 1,3,5 or 1 3 5
        ## Every option is validated before anything runs, so a typo in the
        ## list never leaves the server half-done.
        choices=''
        invalid=0
        for choice in $(echo "$input" | tr ',' ' '); do
            if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "$LAST_OPTION" ]; then
                echo 
                red_msg "Wrong input: $choice"
                choices=''
                invalid=1
                break
            fi

            ## Skip the duplicates, keep the given order.
            case " $choices " in
                *" $choice "*) ;;
                *) choices="$choices $choice" ;;
            esac
        done

        if [ -z "$choices" ]; then
            if [ "$invalid" -eq 0 ]; then
                echo 
                red_msg 'Wrong input!'
            fi
            continue
        fi

        reboot_needed=0

        for choice in $choices; do
            echo 
            green_msg '================================================================='
            green_msg "Option $choice - $(option_title "$choice")"
            green_msg '================================================================='
            sleep 0.5

            run_option "$choice"
            sleep 0.5

            case "$REBOOT_OPTIONS" in
                *" $choice "*) reboot_needed=1 ;;
            esac
        done

        echo 
        green_msg '========================='
        green_msg  'Done.'
        green_msg '========================='

        if [ "$reboot_needed" -eq 1 ]; then
            ask_reboot
        fi
    done
}


## Run

# Install dependencies
install_dependencies
sleep 0.5

# Fix Hosts file
fix_etc_hosts
sleep 0.5

# Fix DNS
fix_dns
sleep 0.5

# Timezone
set_timezone
sleep 0.5


main
