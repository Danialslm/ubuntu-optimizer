# Linux Optimizer

## This Bash script automates the optimization of your Linux server.
#### Notes:
 1. This script is designed for execution on Linux server environments, including VPS, VDS, Dedicated, and Bare Metal systems. It is not recommended for use on Linux desktop environments.
 2. Modifying the kernel (option 3) may result in removing or resetting some GPU drivers.
 3. Some VMs do not support kernel changes (option 3). Installing XanMod could cause the VM to break. Please be cautious and test beforehand.
 4. Every menu option does one task. Enter several of them at once, separated by commas: `1,3,5`

### It performs the following tasks:
       
0. Fix `hosts` file and DNS _(temporarily)_:
    - Check and add 127.0.1.1 and server hostname to `/etc/hosts`.
    
    *Original `hosts` file is backed up at `/etc/hosts.bak`.*
    - Add `Cloudflare-Security` DNS servers _`(1.1.1.2, 1.0.0.2)`_ nameservers to `/etc/resolv.conf`.
    
    *Original `dns` file is backed up at `/etc/resolv.conf.bak`.*


1. Update, Upgrade, and Clean the server:
    - _Update_
    - _Upgrade_
    - _Full-Upgrade_
    - _AutoRemove_
    - _AutoClean_
    - _Clean_


2. Disable Terminal Ads _(Only on Ubuntu)_.


3. Install XanMod Kernel _(Only on Ubuntu & Debian)_:
    - Enable BBRv3.
    - CloudFlare TCP Optimizations.
    - More Details: https://xanmod.org

4. Install Useful Packages:

    _`apt-transport-https`_ _`apt-utils`_ _`autoconf`_ _`automake`_ _`bash-completion`_ _`bc`_ _`binutils`_ _`binutils-common`_ _`binutils-x86-64-linux-gnu`_ _`build-essential`_ _`busybox`_ _`ca-certificates`_ _`cron`_ _`curl`_ _`dialog`_ _`epel-release`_ _`gnupg2`_ _`git`_ _`haveged`_ _`htop`_ _`jq`_ _`keyring`_ _`libssl-dev`_ _`libsqlite3-dev`_ _`libtool`_ _`locales`_ _`lsb-release`_ _`make`_ _`nano`_ _`net-tools`_ _`packagekit`_ _`preload`_ _`python3`_ _`python3-pip`_ _`qrencode`_ _`socat`_ _`screen`_ _`software-properties-common`_ _`ufw`_ _`unzip`_ _`vim`_ _`wget`_ _`zip`_


5. Enable Packages at Server Boot.

    
6. Set the server TimeZone to the VPS IP address location.

 
7. Create & Enable `SWAP` File:
    - Swap Path: `"/swapfile"`
    - Swap Size: `2Gb`


8. Optimize the [SYSCTL](https://github.com/hawshemi/Linux-Optimizer/blob/main/files/sysctl.conf) Configs:
    - Optimize File System Settings.
    - Optimize Network Core Settings.
    - Optimize `SWAP`.
    - Optimize `TCP` and `UDP` Settings.
    - Optimize `UNIX` Domain Sockets Settings.
    - Optimize `Virtual memory (VM)` Settings.
    - Optimize Network Configuration Settings.
    - Optimize the Kernel.
    - Activate `BBR` _(`BBRv3` with XanMod)_.

    *Original file is backed up at `/etc/sysctl.conf.bak`.*

    
9. Optimize [SSH](https://github.com/hawshemi/Linux-Optimizer/blob/main/files/sshd_config):
    - Disable DNS lookups for connecting clients.
    - Remove less efficient encryption ciphers.
    - Enable and Configure TCP keep-alive messages.
    - Allow TCP forwarding.
    - Enable gateway ports, Tunneling and compression.
    - Enable X11 Forwarding.

    *Original file is backed up at `/etc/ssh/sshd_config.bak`.*
   

10. Optimize the [System Limits](https://github.com/hawshemi/Linux-Optimizer/blob/main/files/profile):
    - Soft and Hard *ulimit* `-c -d -f -i -l -n -q -s -u -v -x` optimizations.
    
    
11. Optimize `UFW` and open Common Ports:
    - Open Ports `SSH`, `80`, `443`.
    - With `IPv6`, `TCP` & `UDP`.


12. Install the Latest `Nginx` from the official repository:
    - Adds the `nginx.org` repository and pins it over the distro packages.
    - More Details: https://nginx.org/en/linux_packages.html


13. Install `Docker` & `Docker Compose` from the official repository:
    - `docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-buildx-plugin`, `docker-compose-plugin`.
    - More Details: https://docs.docker.com/engine/install/ubuntu


14. Install `PasarGuard Node`:
    - Runs the official installer _(interactive)_.
    - Downloads the `Xray` assets to `/var/lib/pg-node/assets` and mounts them into the container.
    - Shows the Certificate & the API Key at the end.
    - More Details: https://github.com/PasarGuard/scripts

    
**Reboot at the end is recommended.**


## Prerequisites

### Ensure that the `sudo` and `wget` packages are installed on your system:

- Ubuntu & Debian:
```
sudo apt update -q && sudo apt install -y sudo wget
```
- CentOS & Fedora:
```
sudo dnf up -y && sudo dnf install -y sudo wget
```


## Run
#### **Tested on:** Ubuntu 20+

#### Root Access is Required. If the user is not root, first run:
```
sudo -i
```
#### Then:
```
wget "https://raw.githubusercontent.com/hawshemi/Linux-Optimizer/main/ubuntu-optimizer.sh" -O ubuntu-optimizer.sh && chmod +x ubuntu-optimizer.sh && bash ubuntu-optimizer.sh 
```

#### Choosing the options:
Each option runs a single task. Enter one option, or several separated by commas, and they run in the order given:
```
Enter Your Choice(s): 1,3,5
```
For a full optimization, enter:
```
Enter Your Choice(s): 1,2,3,4,5,6,7,8,9
```


## Menu Image
### Debian & Ubuntu:
![debian-based-menu](https://github.com/hawshemi/Linux-Optimizer/assets/16742123/3604470e-48ed-403d-a753-143dc934f6fd)

### CentOS, AlmaLinux & Fedora:
![rhel-based-menu](https://github.com/hawshemi/Linux-Optimizer/assets/16742123/07099e64-3864-425f-83e2-cda1e57d5b62)



## Disclaimer
This script is provided as-is, without any warranty or guarantee. Use it at your own risk.


## License
This script is licensed under the MIT License.

