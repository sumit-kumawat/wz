#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

# Define Colors
GREEN="\e[1;32m"
BLUE="\e[1;34m"
RED="\e[1;31m"
YELLOW="\e[1;33m"
BOLD="\e[1m"
RESET="\e[0m"

# Ensure script is running as root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}✖ This script must be run as root!${RESET}"
    exit 1
fi

echo -e "${BLUE}${BOLD}🚀 Starting DefendX Setup...${RESET}"

# Step 1: Creating user 'admin' with sudo privileges
echo -e "${BLUE}🔹 Creating user 'admin' with sudo privileges...${RESET}"
useradd -m -s /bin/bash admin || true
echo "admin:Adm1n@123" | chpasswd
usermod -aG wheel admin  # 'wheel' group for sudo on Amazon Linux
echo "admin ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/admin
echo -e "${GREEN}✅ User 'admin' created successfully!${RESET}"

# Step 2: Set Hostname and Update Hosts File
echo -e "${BLUE}🔹 Setting hostname to: DefendX...${RESET}"
hostnamectl set-hostname defendx
echo -e "127.0.0.1   defendx\n::1         defendx" >> /etc/hosts
echo -e "${GREEN}✅ Hostname and Hosts file updated!${RESET}"

# Step 3: Transfer ownership of 'wazuh-user' files to 'admin' if it exists
if id "wazuh-user" &>/dev/null; then
    echo -e "${BLUE}🔹 Transferring ownership of 'wazuh-user' files to 'admin'...${RESET}"
    
    # Define target directories to scan instead of full system scan
    for dir in /home /var /opt /usr/local; do
        find "$dir" -user wazuh-user -exec chown admin:admin {} + 2>/dev/null
    done

    echo -e "${GREEN}✅ Ownership transferred!${RESET}"
else
    echo -e "${YELLOW}⚠ 'wazuh-user' does not exist, skipping ownership transfer.${RESET}"
fi

# Step 5: Replace Logos
echo -e "${BLUE}🔹 Downloading and replacing Wazuh logos with DefendX logos...${RESET}"

# Define variables
LOGO_URL="https://cdn.conzex.com/uploads/Defendx-Assets/Wazuh-assets/30e500f584235c2912f16c790345f966.svg"
LOGO_PATH="/usr/share/wazuh-dashboard/plugins/securityDashboards/target/public/30e500f584235c2912f16c790345f966.svg"

# Ensure target directory exists
TARGET_DIR=$(dirname "$LOGO_PATH")
if [[ ! -d "$TARGET_DIR" ]]; then
    echo -e "${RED}✖ Target directory does not exist: $TARGET_DIR${RESET}"
    exit 1
fi

# Download the new logo
if curl -o "$LOGO_PATH" -L "$LOGO_URL" --silent --fail; then
    echo -e "${GREEN}✅ Successfully replaced: $LOGO_PATH${RESET}"
else
    echo -e "${RED}✖ Failed to download logo from $LOGO_URL${RESET}"
    exit 1
fi

echo -e "${GREEN}✅ Logo replacement completed!${RESET}"

# Step 6: Update Branding Files
echo -e "${BLUE}🔹 Updating get_logos.js for DefendX Branding...${RESET}"
LOGO_JS_PATH="/usr/share/wazuh-dashboard/src/core/common/logos/get_logos.js"
sudo bash -c "cat > $LOGO_JS_PATH << 'EOL'
const OPENSEARCH_DASHBOARDS_THEMED = exports.OPENSEARCH_DASHBOARDS_THEMED = 'ui/logos/defendx_dashboards.svg';
const OPENSEARCH_DASHBOARDS_ON_LIGHT = exports.OPENSEARCH_DASHBOARDS_ON_LIGHT = 'ui/logos/defendx_dashboards_on_light.svg';
const OPENSEARCH_DASHBOARDS_ON_DARK = exports.OPENSEARCH_DASHBOARDS_ON_DARK = 'ui/logos/defendx_dashboards_on_dark.svg';
const OPENSEARCH_THEMED = exports.OPENSEARCH_THEMED = 'ui/logos/defendx.svg';
const OPENSEARCH_ON_LIGHT = exports.OPENSEARCH_ON_LIGHT = 'ui/logos/defendx_on_light.svg';
const OPENSEARCH_ON_DARK = exports.OPENSEARCH_ON_DARK = 'ui/logos/defendx_on_dark.svg';
const MARK_THEMED = exports.MARK_THEMED = 'ui/logos/defendx_mark.svg';
const MARK_ON_LIGHT = exports.MARK_ON_LIGHT = 'ui/logos/defendx_mark_on_light.svg';
const MARK_ON_DARK = exports.MARK_ON_DARK = 'ui/logos/defendx_mark_on_dark.svg';
const CENTER_MARK_THEMED = exports.CENTER_MARK_THEMED = 'ui/logos/defendx_center_mark.svg';
const CENTER_MARK_ON_LIGHT = exports.CENTER_MARK_ON_LIGHT = 'ui/logos/defendx_center_mark_on_light.svg';
const CENTER_MARK_ON_DARK = exports.CENTER_MARK_ON_DARK = 'ui/logos/defendx_center_mark_on_dark.svg';
const ANIMATED_MARK_THEMED = exports.ANIMATED_MARK_THEMED = 'ui/logos/spinner.svg';
const ANIMATED_MARK_ON_LIGHT = exports.ANIMATED_MARK_ON_LIGHT = 'ui/logos/spinner_on_light.svg';
const ANIMATED_MARK_ON_DARK = exports.ANIMATED_MARK_ON_DARK = 'ui/logos/spinner_on_dark.svg';
EOL"
echo -e "${GREEN}✅ Logos renamed in get_logos.js!${RESET}"

# Step 7: Update /etc/issue for Branding
echo -e "${BLUE}🔹 Updating /etc/issue with DefendX branding...${RESET}"
cat << EOL > /etc/issue
🔹 Welcome to DefendX – Unified XDR & SIEM 🔹

📖 Documentation: docs.conzex.com/defendx
🌐 Website: www.conzex.com
📧 Support: defendx-support@conzex.com
_______________________________________________________________________
👤 User: admin
🔒 Password: Adm1n@123
EOL
echo -e "${GREEN}✅ /etc/issue updated successfully!${RESET}"

# Step 8: Restart Wazuh Services
echo -e "${BLUE}🔹 Restarting Wazuh Services...${RESET}"
for service in wazuh-manager wazuh-indexer wazuh-dashboard; do
    systemctl restart $service
    systemctl enable $service
    if systemctl is-active --quiet $service; then
        echo -e "${GREEN}✅ Service $service restarted successfully!${RESET}"
    else
        echo -e "${RED}❌ Service $service failed to start!${RESET}"
    fi
done

# Step 9: Check Service Status
echo -e "${BLUE}🔹 Checking service status...${RESET}"
services=(wazuh-manager wazuh-indexer wazuh-dashboard)
status_line=""
for service in "${services[@]}"; do
    status=$(systemctl show -p SubState --value $service)
    if [[ "$status" == "running" ]]; then
        status_line+="${GREEN}$service: Running${RESET} | "
    else
        status_line+="${RED}$service: Stopped ($status)${RESET} | "
    fi
done
echo -e "🚀 **Service Status:** ${status_line% | }"

# Final Message
echo -e "${GREEN}${BOLD}✅ DefendX setup completed successfully!${RESET}"
echo -e "🌐 Login: https://$(hostname -I | awk '{print $1}')"
echo -e "👤 User: admin"
echo -e "🔒 Password: admin"
