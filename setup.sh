#!/bin/bash
clear 

##color
RED='\033[0;31m'
GREEN='\e[32m'
YELLOW='\033[1;33m'
BLUE='\033[1;32m'
NC='\033[0m'

function readinput(){
read -p "Domain: " VAL1
read -p "IP Address: " IPADDRESS

newdomains=$VAL1
NEWDOMAIN=$(echo "$VAL1" | tr '[:lower:]' '[:upper:]')
newsubdomains=$(echo "$VAL1" | awk -F'.' '{print $1}')
NEWSUBDOMAIN=$(echo "$newsubdomains" | tr '[:lower:]' '[:upper:]')
}

##...............BANNER...............
function banner(){
echo
BANNER_NAME=$1
echo -e "${YELLOW}[+] ${BANNER_NAME} "
echo -e "---------------------------------------------------${NC}"
}

function check_root(){
if [[ $(id -u) != 0 ]];then 
echo "This script run as root"
exit;
fi 
}

##..........................INSTALL PACKAGE.......................
function install_package_base(){
banner "Install package."

    for P in $(cat $(pwd)/package/package_x86_64)
    do
        if [[ -n "$(pacman -Q $P)" ]];then 
            echo -e "${GREEN}[ OK ]${NC} Package: $RED $P $NC Installed."
        else 
            sudo pacman -S $P --noconfirm
            echo -e "${GREEN}[ OK ]${NC} Package: $RED $P $NC Installed successful."
        fi
    done
}

##...................krb5 rename.......................
function krb5(){
banner "Configure krb5"

    grep -rli DOMAIN $(pwd)/krb5/* | xargs -i@ sed -i s/DOMAIN/$NEWDOMAIN/g @
    grep -rli domains $(pwd)/krb5/* | xargs -i@ sed -i s/domains/$newdomains/g @
    grep -rli subdomain $(pwd)/krb5/* | xargs -i@ sed -i s/subdomain/$newsubdomains/g @
    echo -e "${GREEN}[ OK ]${NC} Configuring krb5..."

    sudo cp /etc/krb5.conf /etc/krb5.conf.backup
    sudo cp $(pwd)/krb5/krb5.conf /etc/krb5.conf
    echo -e "${GREEN}[ OK ]${NC} Copy config"
}

##..................samba rename...................
function samba(){
banner "Configure samba"

    grep -rli SUBDOMAIN $(pwd)/samba/smb.conf | xargs -i@ sed -i s/SUBDOMAIN/$NEWSUBDOMAIN/g @
    grep -rli DOMAIN $(pwd)/samba/smb.conf | xargs -i@ sed -i s/DOMAIN/$NEWDOMAIN/g @
    grep -rli domains $(pwd)/samba/smb.conf | xargs -i@ sed -i s/domains/$newdomains/g @
    grep -rli HOSTNAME $(pwd)/samba/smb.conf | xargs -i@ sed -i s/HOSTNAME/$(hostname)/g @
    echo -e "${GREEN}[ OK ]${NC} configuring samba rename"

    sudo cp $(pwd)/samba/smb.conf /etc/samba/smb.conf
    sudo cp $(pwd)/samba/pam_winbind.conf /etc/security/pam_winbind.conf
    echo -e "${GREEN}[ OK ]${NC} Copy config samba"
    
}

##.....................pam mount.......................
function pam_mount(){
banner "Configure pam_mount"
    
    cp $(pwd)/pam_mount/* /etc/security/
    echo -e "${GREEN}[ OK ]${NC} Copy configure"

    grep -rli DOMAIN $(pwd)/pam_mount | xargs -i@ sed -i s+DOMAIN+${VAL1}+g @
    grep -rli SDM $(pwd)/pam_mount | xargs -i@ sed -i s+SDM+${NEWSUBDOMAIN}+g @
    echo -e "${GREEN}[ OK ]${NC} Configure pam_mount"
}
##..................mysmb service..................
function mysmb(){
banner "Configure samba service"
    
    sudo cp $(pwd)/scripts/mysmb /usr/bin/mysmb
    sudo cp $(pwd)/service/mysmb.service /usr/lib/systemd/system/
    sudo chmod +x /usr/bin/mysmb
    echo -e "${GREEN}[ OK ]${NC} configuring client"
}

function nsswitch(){
banner "Configure nsswitch"
    
    sudo cp $(pwd)/nsswitch/nsswitch.conf /etc/nsswitch.conf
    echo -e "${GREEN}[ OK ]${NC} configuring nsswitch"
}

function pam(){
banner "Configure pam"

    sudo cp $(pwd)/pam.d/* /etc/pam.d/
    echo -e "${GREEN}[ OK ]${NC} Configuring pam.d"
}

function resolv(){
banner "Configure resolv"

    RESOLVCONF_FILE=/etc/resolvconf.conf
    RESOLV_FILE=/etc/resolv.conf
        
    echo "resolv_conf=/etc/resolv.conf" > ${RESOLVCONF_FILE}
    echo "search_domain ${VAL1}" >> ${RESOLVCONF_FILE}
    echo "name_servers ${IPADDRESS}" >> ${RESOLVCONF_FILE}
    echo "name_servers 8.8.8.8" >> ${RESOLVCONF_FILE}
    echo -e "${GREEN}[ OK ]${NC} Configuring resolvconf"

    echo "search ${VAL1}" > ${RESOLV_FILE}
    echo "nameserver ${IPADDRESS}" >> ${RESOLV_FILE}
    echo "nameserver 8.8.8.8" >> ${RESOLV_FILE}
    echo "nameserver 8.8.4.4" >> ${RESOLV_FILE}
    echo -e "${GREEN}[ OK ]${NC} Configuring resolv"

}

function service(){
banner "Service"

    sudo systemctl enable smb nmb winbind mysmb
    sudo systemctl stop smb nmb winbind mysmb
    echo -e "${GREEN}[ OK ]${NC} stoping service"
}

function joindomain(){
banner "Join Domain"

    domain=$(echo $VAL1 | tr '[:lower:]' '[:upper:]')
    kinit administrator@$domain
    sudo net join -U Administrator@$domain
    echo -e "${GREEN}[ OK ]${NC} Join domain successful"
}

##call function
check_root
readinput
install_package_base
krb5
samba
pam_mount
mysmb
nsswitch
pam
resolv
service
joindomain