#!/bin/bash
clear 

##.................color...................
RED='\033[0;31m'
GREEN='\e[32m'
YELLOW='\033[1;33m'
BLUE='\033[1;32m'
NC='\033[0m'

##.................read input..................
readinput(){
read -p "Domain: " VAL1
read -p "IP Address: " IPADDRESS

newdomains=$VAL1
NEWDOMAIN=$(echo "$VAL1" | tr '[:lower:]' '[:upper:]')
newsubdomains=$(echo "$VAL1" | awk -F'.' '{print $1}')
NEWSUBDOMAIN=$(echo "$newsubdomains" | tr '[:lower:]' '[:upper:]')
}

##....................banner....................
banner(){
echo
BANNER_NAME=$1
echo -e "${YELLOW}[+] ${BANNER_NAME} "
echo -e "---------------------------------------------------${NC}"
}

##....................check root user.................
check_root(){
if [[ $(id -u) != 0 ]];then 
echo "This script run as root"
exit;
fi 
}

##..........................install package base.......................
install_package_base(){
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
krb5(){
banner "Configure krb5"

    cp $(pwd)/krb5/krb5.conf /etc/
    grep -rli DOMAIN /etc/krb5.conf | xargs -i@ sed -i s/DOMAIN/$NEWDOMAIN/g @
    grep -rli domains /etc/krb5.conf | xargs -i@ sed -i s/domains/$newdomains/g @
    grep -rli subdomain /etc/krb5.conf | xargs -i@ sed -i s/subdomain/$newsubdomains/g @
    echo -e "${GREEN}[ OK ]${NC} Configuring krb5..."

}

##..................samba rename...................
samba(){
banner "Configure samba"

    sudo cp $(pwd)/samba/* /etc/samba/
    sudo cp $(pwd)/samba/pam_winbind.conf /etc/security/
    echo -e "${GREEN}[ OK ]${NC} copy config."

    grep -rli SUBDOMAIN /etc/samba/smb.conf | xargs -i@ sed -i s/SUBDOMAIN/$NEWSUBDOMAIN/g @
    grep -rli DOMAIN /etc/samba/smb.conf | xargs -i@ sed -i s/DOMAIN/$NEWDOMAIN/g @
    grep -rli domains /etc/samba/smb.conf | xargs -i@ sed -i s/domains/$newdomains/g @
    grep -rli HOSTNAME /etc/samba/smb.conf | xargs -i@ sed -i s/HOSTNAME/$(hostname)/g @
    echo -e "${GREEN}[ OK ]${NC} Configuring samba rename"

}

##.....................pam mount.......................
pam_mount(){
banner "Configure pam_mount"
    
    cp $(pwd)/pam_mount/* /etc/security/
    echo -e "${GREEN}[ OK ]${NC} Copy configure"

    grep -rli DOMAIN /etc/security/pam_mount.conf.xml | xargs -i@ sed -i s+DOMAIN+${VAL1}+g @
    grep -rli SDM /etc/security/pam_mount.conf.xml | xargs -i@ sed -i s+SDM+${NEWSUBDOMAIN}+g @
    echo -e "${GREEN}[ OK ]${NC} Configure pam_mount"
}
##..................mysmb service..................
mysmb(){
banner "Configure samba service"
    
    sudo cp $(pwd)/scripts/mysmb /usr/bin/mysmb
    sudo cp $(pwd)/service/mysmb.service /usr/lib/systemd/system/
    sudo chmod +x /usr/bin/mysmb
    echo -e "${GREEN}[ OK ]${NC} Configuring client"
}

##..................nsswitch..................
nsswitch(){
banner "Configure nsswitch"
    
    sudo cp $(pwd)/nsswitch/nsswitch.conf /etc/nsswitch.conf
    echo -e "${GREEN}[ OK ]${NC} Configuring nsswitch"
}

##..................pam authentication...............
pam(){
banner "Configure pam"

    sudo cp $(pwd)/pam.d/* /etc/pam.d/
    echo -e "${GREEN}[ OK ]${NC} Configuring pam.d"
}

##...................resolv..................
resolv(){
banner "Configure resolv"

    RESOLVCONF_FILE=/etc/resolvconf.conf
    RESOLV_FILE=/etc/resolv.conf
        
    #resolvconf
    cp resolv/resolvconf.conf ${RESOLVCONF_FILE}
    echo "name_servers ${IPADDRESS}" >> ${RESOLVCONF_FILE}
    echo "search_domains ${VAL1}" >> ${RESOLVCONF_FILE}
    echo "name_servers 8.8.8.8" >> ${RESOLVCONF_FILE}
    echo -e "${GREEN}[ OK ]${NC} Configuring resolvconf"

    #resolv
    echo "search ${VAL1}" > ${RESOLV_FILE}
    echo "nameserver ${IPADDRESS}" >> ${RESOLV_FILE}
    echo "nameserver 8.8.8.8" >> ${RESOLV_FILE}
    echo "nameserver 8.8.4.4" >> ${RESOLV_FILE}
    echo -e "${GREEN}[ OK ]${NC} Configuring resolv"

}

##........................stop service...................
stopservice(){
banner "Service"

    sudo systemctl enable smb nmb winbind mysmb
    sudo systemctl stop smb nmb winbind mysmb
    echo -e "${GREEN}[ OK ]${NC} Stoped service"
}

##.....................join domain.......................
joindomain(){
banner "Join Domain"

    domain=$(echo $VAL1 | tr '[:lower:]' '[:upper:]')
    kinit administrator@$domain
    sudo net join -U Administrator@$domain
    echo -e "${GREEN}[ OK ]${NC} Join domain successful"
}

##.......................start service.....................
startservice(){
banner "start service"

    sudo systemctl start smb nmb winbind
    echo -e "${GREEN}[ OK ]${NC} Started service"
    sudo systemctl status smb nmb winbind
    sudo  -e "${GREEN}[ OK ]${NC} Status service"
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
stopservice
joindomain
startservice