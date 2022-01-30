This script is designed to install Z-Push on a fresh Modoboa system (and replace automx).

**Requirements:**

- Debian based system (EG: Debian 10/11 or Ubuntu 18.04/20.04)
- Default Modoboa NginX setup (EG: autoconfig.DOMAIN.TLD.conf and mail.DOMAIN.TLD.conf in /etc/nginx/sites-available)
- Terminal access (Obviously)

**What it installs:**

- PHP FPM
- Z-Push

**How to run**

Copy the following line into your terminal: 
> curl -L https://raw.githubusercontent.com/dborg89/modoboa-z-push/main/install-zpush.sh |bash

**What do I do if the install breaks my NginX config?**

Simple, cd into the nginx sites-available DIR and move the backup files (denoted with .bkup-<DATE>) into the original names
  
**Do you provide support or warranty?**
  
- Warranty - **NO.** Use at your own risk.
- Support - *Maybe*, depends if I am online.
  
**How do I request support?**
  
Post an issue or ask in https://discord.gg/WuQ3v3PXGR for anyone that has used this script.
