#!/bin/bash

# Make sure we're running as root
if [[ $EUID -ne 0 ]]; then
    echo "Run this script as root, fam. Exiting..."
    exit 1
fi

echo "Starting CIS Benchmark Hardening for RHEL 9..."
echo "==============================================="

#######################################
# 1. FILESYSTEM & MODULE HARDENING
#######################################

# 1.1.1 Disable mounting of certain filesystems (cramfs, squashfs, udf)
disable_module() {
    local module="$1"
    local file="/etc/modprobe.d/disable-${module}.conf"
    if [ ! -f "$file" ]; then
        echo "install ${module} /bin/true" > "$file"
        echo "Disabled module: ${module}"
    else
        echo "Module ${module} already disabled in $file"
    fi
    # Try to remove if currently loaded
    modprobe -r "${module}" 2>/dev/null && echo "Removed ${module} module" || echo "${module} module not loaded"
}

for mod in cramfs squashfs udf; do
    disable_module "$mod"
done

# 1.1.10 Disable USB storage (if not needed)
disable_module "usb-storage"

# 3.1.2 & 3.1.3 Disable SCTP and DCCP protocols
disable_module "sctp"
disable_module "dccp"

# 1.1.2 through 1.1.8 – Check mount options for various partitions
# Note: This function only checks and warns if expected mount options are missing.
check_mount_options() {
    local mount_point="$1"
    shift
    local required_opts=("$@")
    local fstab_line
    fstab_line=$(grep -E "^[^#].*\s${mount_point}(\s|$)" /etc/fstab)
    if [ -z "$fstab_line" ]; then
        echo "WARNING: ${mount_point} does not appear as a separate partition in /etc/fstab."
        return
    fi
    # Extract options (the 4th field in /etc/fstab)
    local opts
    opts=$(echo "$fstab_line" | awk '{print $4}')
    for opt in "${required_opts[@]}"; do
        if [[ "$opts" != *"$opt"* ]]; then
            echo "WARNING: ${mount_point} is missing mount option: ${opt}. Please update /etc/fstab accordingly."
        else
            echo "${mount_point} has option: ${opt}"
        fi
    done
}

# Check /tmp (should be separate and nodev,noexec,nosuid)
check_mount_options "/tmp" "nodev" "noexec" "nosuid"

# Check /var (if separate) for nodev,noexec,nosuid
check_mount_options "/var" "nodev" "noexec" "nosuid"

# Check /var/tmp for nodev,noexec,nosuid
check_mount_options "/var/tmp" "nodev" "noexec" "nosuid"

# Check /var/log for nodev,noexec,nosuid
check_mount_options "/var/log" "nodev" "noexec" "nosuid"

# Check /var/log/audit for nodev,noexec,nosuid
check_mount_options "/var/log/audit" "nodev" "noexec" "nosuid"

# Check /home for nodev,nosuid, and quota options (usrquota,grpquota)
check_mount_options "/home" "nodev" "nosuid" "usrquota" "grpquota"

# 1.1.8: Remount /dev/shm with nodev,noexec,nosuid
echo "Hardening /dev/shm mount..."
mountpoint -q /dev/shm && mount -o remount,nodev,noexec,nosuid /dev/shm && echo "/dev/shm remounted with secure options" || echo "/dev/shm not mounted separately."

# 1.1.9 Disable automounting (disable autofs if installed)
if rpm -q autofs &>/dev/null; then
    systemctl disable --now autofs
    echo "Disabled autofs service."
fi

#######################################
# 1.2 Package Management & Repositories
#######################################

# 1.2.3 Ensure gpgcheck is globally activated for DNF/YUM
for conf in /etc/yum.conf /etc/dnf/dnf.conf; do
    if [ -f "$conf" ]; then
        grep -q "^gpgcheck" "$conf" && sed -i 's/^gpgcheck.*/gpgcheck=1/' "$conf" || echo "gpgcheck=1" >> "$conf"
        echo "Set gpgcheck=1 in $conf"
    fi
done

# 1.2.2 and 1.2.4: These require manual repository review.
echo "NOTE: Please verify that GPG keys and package repositories are configured per your site policy."

#######################################
# 1.3 Filesystem Integrity (AIDE)
#######################################

if ! rpm -q aide &>/dev/null; then
    echo "Installing AIDE..."
    dnf install -y aide
    aide --init
    cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db
else
    echo "AIDE is already installed."
fi

# Set up a daily cron job for AIDE (if not already present)
AIDE_CRON="/etc/cron.daily/aide-check"
if [ ! -f "$AIDE_CRON" ]; then
    cat << 'EOF' > "$AIDE_CRON"
#!/bin/bash
/usr/sbin/aide --check
EOF
    chmod +x "$AIDE_CRON"
    echo "AIDE daily check cron job created."
fi

#######################################
# 1.4 Bootloader & Rescue Mode (Manual Steps)
#######################################
echo "NOTE: Bootloader hardening (password, config permissions, rescue mode auth) requires manual configuration."

#######################################
# 1.5 ASLR
#######################################
echo "Enabling Address Space Layout Randomization (ASLR)..."
sysctl -w kernel.randomize_va_space=2
grep -q "^kernel.randomize_va_space" /etc/sysctl.d/99-cis.conf 2>/dev/null || {
    echo "kernel.randomize_va_space = 2" >> /etc/sysctl.d/99-cis.conf
}
echo "ASLR enabled."

#######################################
# 1.6 SELinux Configuration
#######################################
echo "Configuring SELinux..."
if [ -f /etc/selinux/config ]; then
    sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config
    setenforce 1 && echo "SELinux set to enforcing." || echo "Failed to set SELinux enforcing mode."
else
    echo "SELinux config not found. Please ensure SELinux is installed."
fi
# Remove unconfined services and unwanted packages
dnf remove -y setroubleshoot mcstrans

#######################################
# 1.7 Banner and Message of the Day
#######################################
echo "Setting login banners..."
cat << 'EOF' > /etc/motd
Authorized access only. Any unauthorized use is prohibited and may be subject to criminal and/or civil penalties.
EOF
chmod 644 /etc/motd

cat << 'EOF' > /etc/issue
Authorized access only. All activity on this system may be monitored.
EOF
chmod 644 /etc/issue

cat << 'EOF' > /etc/issue.net
Authorized access only. All activity on this system may be monitored.
EOF
chmod 644 /etc/issue.net

#######################################
# 1.8 Graphical Interface and Removable Media
#######################################
# 1.8.1 Remove GNOME Display Manager (if not needed)
if rpm -q gdm &>/dev/null; then
    echo "Removing GDM (Graphical login)..."
    dnf remove -y gdm
fi
# 1.8.5 Disable automatic mounting of removable media via dconf (for GNOME)
echo "If using a GUI, please verify removable media auto-mount is disabled per your policy."

#######################################
# 1.9 System Updates & Crypto Policy
#######################################
echo "Updating system packages..."
dnf -y update
echo "Setting system-wide crypto policy to 'DEFAULT' (modify if needed)..."
update-crypto-policies --set DEFAULT

#######################################
# 2. TIME SYNCHRONIZATION
#######################################
if ! rpm -q chrony &>/dev/null; then
    echo "Installing chrony for time synchronization..."
    dnf install -y chrony
fi
systemctl enable --now chronyd
echo "Chrony is enabled and running."

#######################################
# 2.2 & 2.3 DISABLE UNNECESSARY NETWORK SERVICES
#######################################
# List of unwanted packages per CIS (modify as needed)
unwanted_packages=(
    xinetd
    xorg-x11-server-common
    avahi
    cups
    dhcp-server
    vsftpd
    tftp-server
    # Note: Web servers, mail agents, etc. may be required on some systems.
    samba
    net-snmp
    telnet-server
    nis
    rsh
    talk
    telnet
    openldap-clients
    tftp
)

for pkg in "${unwanted_packages[@]}"; do
    if rpm -q "$pkg" &>/dev/null; then
        echo "Removing unwanted package: $pkg"
        dnf remove -y "$pkg"
    fi
done

#######################################
# 3. NETWORK HARDENING (sysctl settings)
#######################################
echo "Applying network hardening sysctl settings..."
cat << 'EOF' >> /etc/sysctl.d/99-cis.conf
# Disable IP forwarding
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0

# Disable packet redirect sending
net.ipv4.conf.all.send_redirects = 0
net.ipv6.conf.all.send_redirects = 0

# Disable source routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0

# Disable ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0

# Log suspicious packets
net.ipv4.conf.all.log_martians = 1

# Enable TCP SYN Cookies
net.ipv4.tcp_syncookies = 1

# Enable Reverse Path Filtering
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
EOF
sysctl --system

#######################################
# 3.4 FIREWALL CONFIGURATION
#######################################
echo "Ensuring firewalld is installed and configured..."
if ! rpm -q firewalld &>/dev/null; then
    dnf install -y firewalld
fi
systemctl enable --now firewalld
# Set default zone to drop (modify per your needs)
firewall-cmd --set-default-zone=drop
echo "Firewalld is enabled."

#######################################
# 4. AUDIT & LOGGING
#######################################
# 4.1 Auditd
echo "Configuring auditd..."
if ! rpm -q audit &>/dev/null; then
    dnf install -y audit
fi
systemctl enable --now auditd

# (Additional auditd configuration—such as log storage limits and immutable audit config—should be manually reviewed.)

# 4.2 Rsyslog
if ! rpm -q rsyslog &>/dev/null; then
    dnf install -y rsyslog
fi
systemctl enable --now rsyslog

# 4.3 logrotate is typically installed by default; verify your site policy.
echo "Ensure logrotate is configured per your site policy."

#######################################
# 5. CRON, SSH, SUDO, AND AUTHENTICATION
#######################################

# 5.1 Cron daemon and file permissions
echo "Securing cron configuration..."
chmod 600 /etc/crontab
chmod 700 /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly
# Optionally restrict cron/at to authorized users by configuring /etc/cron.allow and /etc/at.allow

# 5.2 SSH hardening
echo "Hardening SSH configuration..."
SSH_CONFIG="/etc/ssh/sshd_config"
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' "$SSH_CONFIG"
sed -i 's/^#\?X11Forwarding.*/X11Forwarding no/' "$SSH_CONFIG"
sed -i 's/^#\?PermitEmptyPasswords.*/PermitEmptyPasswords no/' "$SSH_CONFIG"
sed -i 's/^#\?MaxAuthTries.*/MaxAuthTries 4/' "$SSH_CONFIG"
sed -i 's/^#\?PermitUserEnvironment.*/PermitUserEnvironment no/' "$SSH_CONFIG"
# You can add additional SSH hardening parameters here as needed.
systemctl restart sshd
echo "SSH configuration updated."

# 5.3 Sudo configuration
echo "Ensuring sudo is installed and secured..."
if ! rpm -q sudo &>/dev/null; then
    dnf install -y sudo
fi
chmod 440 /etc/sudoers
# Ensure sudoers logging and use of pty is configured per your site policy.

# 5.5 & 5.6 Password Policies
echo "Configuring password policies..."
sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS   90/' /etc/login.defs
sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS   7/' /etc/login.defs
sed -i 's/^PASS_WARN_AGE.*/PASS_WARN_AGE   7/' /etc/login.defs

cat << 'EOF' > /etc/security/pwquality.conf
minlen = 14
dcredit = -1
ucredit = -1
ocredit = -1
lcredit = -1
EOF
echo "Password policies updated."

#######################################
# 6. FILE AND ACCOUNT PERMISSIONS
#######################################
echo "Securing file permissions for critical files..."
chmod 644 /etc/passwd
chmod 000 /etc/shadow
chmod 644 /etc/group
chmod 000 /etc/gshadow

# (Additional checks for world-writable files, unowned files, and SUID/SGID executables should be done manually or via separate auditing scripts.)

#######################################
# FINAL NOTES
#######################################
echo "=================================================================="
echo "Hardening script complete. Review warnings above and verify all"
echo "settings. Some items require manual remediation (e.g., bootloader,"
echo "authselect, and partitioning changes). A reboot may be necessary."
echo "Stay safe and keep it 100!"
echo "=================================================================="

exit 0
