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
# read -p "Domain: " VAL1
# read -p "IP Address: " IPADDRESS

    hostname=$(TERM=ansi whiptail --clear --title "[ Hostname Selection ]"  --inputbox \
    "\nPlease enter a suitable new hostname for the client to join the active directory server.\nExample:  adclient-01\n" 10 80 \
    3>&1 1>&2 2>&3)

    REALM=$(TERM=ansi whiptail --clear --title "[ Realm Selection ]"  --inputbox \
    "\nPlease enter a realm name of the active directory server.\nExample:  KOOMPILAB.ORG\n" 10 80 3>&1 1>&2 2>&3)
    REALM=${REALM^^}

    DOMAIN=$(TERM=ansi whiptail --clear --title "[ Domain Selection ]" --inputbox \
    "\nPlease enter an domain of the active directory server\nExample:  KOOMPILAB\n" 10 80 3>&1 1>&2 2>&3)
    DOMAIN=${DOMAIN^^}

    while true;
    do
        IPADDRESS=$(TERM=ansi whiptail --clear --title "[ IP of Domain ]" --inputbox \
        "\nPlease enter the IP of the active directory server\nExample:  172.16.1.1\n" 8 80 3>&1 1>&2 2>&3)
        if [[ $IPADDRESS =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]];
        then
            break
        else
            TERM=ansi whiptail --clear --backtitle "Samba Active Directory Domain Controller" --title \
            "[ IP for Domain ]" --msgbox "Your IP isn't valid. A valid IP should looks like XXX.XXX.XXX.XXX" 10 80
        fi
    done

    server_hostname=$(TERM=ansi whiptail --clear --title "[ Server Hostname ]"  --inputbox \
    "\nPlease enter the hostname of the active directory server.\nExample:  adlab\n" 10 80 3>&1 1>&2 2>&3)

    while true;
    do
        samba_password=$(TERM=ansi whiptail --clear --title "[ Administrator Password ]" --passwordbox \
        "\nPlease enter Administrator password for joining domain\n" 10 80 3>&1 1>&2 2>&3)

        samba_password_again=$(TERM=ansi whiptail --clear --title "[ Administrator Password ]" --passwordbox \
        "\nPlease enter Administrator password again" 10 80  3>&1 1>&2 2>&3)

        if  [[ "$samba_password" != "$samba_password_again" ]];
        then
            TERM=ansi whiptail --clear --backtitle "Samba Active Directory Domain Controller" --title \
            "[ Administrator Password ]" --msgbox "Your password does match. Please retype it again" 10 80

        elif [[ "${#samba_password}" < 8 ]];
        then
                TERM=ansi whiptail --clear --backtitle "Samba Active Directory Domain Controller" --title \
                "[ Administrator Password ]" --msgbox "Your password does not meet the length requirement." 10 80
        else
                break
        fi

    done


# newdomains=$VAL1
# NEWDOMAIN=$(echo "$VAL1" | tr '[:lower:]' '[:upper:]')
# newsubdomains=$(echo "$VAL1" | awk -F'.' '{print $1}')
# NEWSUBDOMAIN=$(echo "$newsubdomains" | tr '[:lower:]' '[:upper:]')
}

function sethostname(){
    sudo hostnamectl set-hostname $hostname
    sudo hostname $hostname
    HOSTNAME=$hostname
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
if [[ $(id -u) != 0 ]];
then 
    echo "This script run as root"
    exit;
fi 
}

##..........................install package base.......................
install_package_base(){
banner "Install package."

    for P in $(cat $(pwd)/package/package_x86_64)
    do
        if [[ -n "$(pacman -Q $P)" ]];
        then 
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
    # grep -rli DOMAIN /etc/krb5.conf | xargs -i@ sed -i s/DOMAIN/$NEWDOMAIN/g @
    # grep -rli domains /etc/krb5.conf | xargs -i@ sed -i s/domains/$newdomains/g @
    # grep -rli subdomain /etc/krb5.conf | xargs -i@ sed -i s/subdomain/$newsubdomains/g @
    grep -rli REALM /etc/krb5.conf | xargs -i@ sed -i s/REALM/$REALM/g @
    grep -rli DOMAIN /etc/krb5.conf | xargs -i@ sed -i s/DOMAIN/$DOMAIN/g @
    grep -rli SRVREALM /etc/krb5.conf | xargs -i@ sed -i s/SRVREALM/"${server_hostname^^}.$REALM"/g @
    echo -e "${GREEN}[ OK ]${NC} Configuring krb5..."

}

##..................samba rename...................
samba(){
banner "Configure samba"

    sudo cp $(pwd)/samba/* /etc/samba/
    sudo cp $(pwd)/samba/pam_winbind.conf /etc/security/
    echo -e "${GREEN}[ OK ]${NC} copy config."

    grep -rli DOMAIN /etc/samba/smb.conf | xargs -i@ sed -i s/DOMAIN/$DOMAIN/g @
    grep -rli REALM /etc/samba/smb.conf | xargs -i@ sed -i s/REALM/$REALM/g @
    grep -rli SREALM /etc/samba/smb.conf | xargs -i@ sed -i s/SREALM/${REALM,,}/g @
    grep -rli HOSTNAME /etc/samba/smb.conf | xargs -i@ sed -i s/HOSTNAME/$(HOSTNAME)/g @
    echo -e "${GREEN}[ OK ]${NC} Configuring samba rename"

}

##.....................pam mount.......................
pam_mount(){
banner "Configure pam_mount"
    
    cp $(pwd)/pam_mount/* /etc/security/
    echo -e "${GREEN}[ OK ]${NC} Copy configure"

    grep -rli REALM /etc/security/pam_mount.conf.xml | xargs -i@ sed -i s+DOMAIN+${REALM,,}+g @
    grep -rli DOMAIN /etc/security/pam_mount.conf.xml | xargs -i@ sed -i s+SDM+${DOMAIN}+g @
    echo -e "${GREEN}[ OK ]${NC} Configure pam_mount"
}
##..................mysmb service..................
mysmb(){
banner "Configure samba service"
    
    sudo cp $(pwd)/scripts/mysmb /usr/bin/mysmb
    sudo cp $(pwd)/service/mysmb.service /usr/lib/systemd/system/
    sudo chmod +x /usr/bin/mysmb
    echo -e "${GREEN}[ OK ]${NC} Configuring necessary service"
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
    grep -rli REALM ${RESOLVCONF_FILE} | xargs -i@ sed -i s+REALM+${REALM,,}+g @
    grep -rli NAMESERVER ${RESOLVCONF_FILE} | xargs -i@ sed -i s+NAMESERVER+${IPADDRESS}+g @
    # echo "name_servers=${IPADDRESS}" >> ${RESOLVCONF_FILE}
    # echo "search_domains=${REALM,,}" >> ${RESOLVCONF_FILE}
    echo -e "${GREEN}[ OK ]${NC} Configuring resolvconf"

    #resolv
    echo "search ${REALM,,}" > ${RESOLV_FILE}
    echo "nameserver ${IPADDRESS}" >> ${RESOLV_FILE}
    echo "nameserver 8.8.8.8" >> ${RESOLV_FILE}
    echo "nameserver 8.8.4.4" >> ${RESOLV_FILE}
    echo -e "${GREEN}[ OK ]${NC} Configuring resolv.conf"

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

    # domain=$(echo $VAL1 | tr '[:lower:]' '[:upper:]')
    echo "$samba_password" | kinit administrator@${REALM,,}
    echo "$samba_password" | sudo net join -U Administrator@$REALM
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
sethostname
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