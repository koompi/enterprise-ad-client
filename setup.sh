#!/bin/bash
clear 

##.................color...................
RED='\033[0;31m'
GREEN='\e[32m'
YELLOW='\033[1;33m'
BLUE='\033[1;32m'
NC='\033[0m'

NOW=$(date +"%m-%d-%Y-%T")

mkdir -p /klab/
mkdir -p /klab/samba
mkdir -p /klab/samba/log
LOG="/klab/samba/log/clientlog-$NOW"

rm -rf $LOG

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


check_root(){
    if [[ $(id -u) != 0 ]];
    then 
        echo "This script run as root"
        exit;
    fi 
}


sethostname(){
    banner 5 "Setting Hostname"
    sudo hostnamectl set-hostname $hostname
    sudo hostname $hostname
    HOSTNAME=$hostname
}

##....................banner....................
banner(){
    # echo
    # BANNER_NAME=$1
    # echo -e "${YELLOW}[+] ${BANNER_NAME} "
    # echo -e "---------------------------------------------------${NC}"
    echo -e "XXX\n$1\n$2\nXXX"
}

##....................check root user.................

##..........................install package base.......................
install_package_base(){
banner 10 "Installing necessary packages."

    for P in $(cat $(pwd)/package/package_x86_64)
    do
        if [[ -n "$(pacman -Q $P)" ]];
        then 
            echo -e "${GREEN}[ OK ]${NC} Package: $RED $P $NC Installed." >> $LOG
        else 
            sudo pacman -S $P --noconfirm
            echo -e "${GREEN}[ OK ]${NC} Package: $RED $P $NC Installed successful." >> $LOG
        fi
    done
}

##...................krb5 rename.......................
krb5(){
banner 25 "Configuring Keberos Network Authenticator"

    cp $(pwd)/krb5/krb5.conf /etc/
    # grep -rli DOMAIN /etc/krb5.conf | xargs -i@ sed -i s/DOMAIN/$NEWDOMAIN/g @
    # grep -rli domains /etc/krb5.conf | xargs -i@ sed -i s/domains/$newdomains/g @
    # grep -rli subdomain /etc/krb5.conf | xargs -i@ sed -i s/subdomain/$newsubdomains/g @
    grep -rli SRVREALM /etc/krb5.conf | xargs -i@ sed -i s/SRVREALM/"${server_hostname^^}.$REALM"/g @
    grep -rli REALM /etc/krb5.conf | xargs -i@ sed -i s/REALM/$REALM/g @
    grep -rli DOMAIN /etc/krb5.conf | xargs -i@ sed -i s/DOMAIN/$DOMAIN/g @
    echo -e "${GREEN}[ OK ]${NC} Configuring krb5..." >> $LOG

}

##..................samba rename...................
samba(){
banner 30 "Configuring Samba Active Directory Domain Controller Server"

    sudo cp $(pwd)/samba/* /etc/samba/
    sudo cp $(pwd)/samba/pam_winbind.conf /etc/security/
    echo -e "${GREEN}[ OK ]${NC} copy config." >> $LOG

    grep -rli DOMAIN /etc/samba/smb.conf | xargs -i@ sed -i s/DOMAIN/$DOMAIN/g @
    grep -rli REALM /etc/samba/smb.conf | xargs -i@ sed -i s/REALM/$REALM/g @
    grep -rli SREALM /etc/samba/smb.conf | xargs -i@ sed -i s/SREALM/${REALM,,}/g @
    grep -rli HOSTNAME /etc/samba/smb.conf | xargs -i@ sed -i s/HOSTNAME/$HOSTNAME/g @
    echo -e "${GREEN}[ OK ]${NC} Configuring samba rename" >> $LOG

}

##.....................pam mount.......................
pam_mount(){
banner 50 "Configuring Auto-mount Storage Drives Settings"
    
    cp $(pwd)/pam_mount/* /etc/security/
    echo -e "${GREEN}[ OK ]${NC} Copy pam_mount configure" >> $LOG

    grep -rli REALM /etc/security/pam_mount.conf.xml | xargs -i@ sed -i s+REALM+${REALM,,}+g @
    grep -rli DOMAIN /etc/security/pam_mount.conf.xml | xargs -i@ sed -i s+DOMAIN+${DOMAIN}+g @
    echo -e "${GREEN}[ OK ]${NC} Configure pam_mount" >> $LOG
}
##..................mysmb service..................
mysmb(){
banner 55 "Configuring Samba Helper Service"
    
    sudo cp $(pwd)/scripts/mysmb /usr/bin/mysmb
    sudo cp $(pwd)/service/mysmb.service /usr/lib/systemd/system/
    sudo chmod +x /usr/bin/mysmb
    echo -e "${GREEN}[ OK ]${NC} Configuring necessary service" >> $LOG
}

##..................nsswitch..................
nsswitch(){
banner 65 "Configuring Name Service Swtich"
    
    sudo cp $(pwd)/nsswitch/nsswitch.conf /etc/nsswitch.conf
    echo -e "${GREEN}[ OK ]${NC} Configuring nsswitch" >> $LOG
}

##..................pam authentication...............
pam(){
banner 70 "Configuring Pluggable Authentication Modules For Linux"

    sudo cp $(pwd)/pam.d/* /etc/pam.d/
    echo -e "${GREEN}[ OK ]${NC} Configuring pam.d" >> $LOG
}

##...................resolv..................
resolv(){
banner 75 "Configuring Dynamic Name Service Resolver"

    RESOLVCONF_FILE=/etc/resolvconf.conf
    RESOLV_FILE=/etc/resolv.conf
        
    #resolvconf
    cp resolv/resolvconf.conf ${RESOLVCONF_FILE}
    grep -rli REALM ${RESOLVCONF_FILE} | xargs -i@ sed -i s+REALM+${REALM,,}+g @
    grep -rli NAMESERVER ${RESOLVCONF_FILE} | xargs -i@ sed -i s+NAMESERVER+${IPADDRESS}+g @
    # echo "name_servers=${IPADDRESS}" >> ${RESOLVCONF_FILE}
    # echo "search_domains=${REALM,,}" >> ${RESOLVCONF_FILE}
    echo -e "${GREEN}[ OK ]${NC} Configuring resolvconf" >> $LOG

    #resolv
    echo "search ${REALM,,}" > ${RESOLV_FILE}
    echo "nameserver ${IPADDRESS}" >> ${RESOLV_FILE}
    echo "nameserver 8.8.8.8" >> ${RESOLV_FILE}
    echo "nameserver 8.8.4.4" >> ${RESOLV_FILE}
    echo -e "${GREEN}[ OK ]${NC} Configuring resolv.conf" >> $LOG

}

##........................stop service...................
stopservice(){
banner 80 "Stopping Samba Related Service"

    sudo systemctl enable smb nmb winbind mysmb
    sudo systemctl stop smb nmb winbind mysmb
    echo -e "${GREEN}[ OK ]${NC} Stoped service" >> $LOG
}

##.....................join domain.......................
joindomain(){
banner 90 "Joining $REALM Domain"

    # domain=$(echo $VAL1 | tr '[:lower:]' '[:upper:]')
    echo "$samba_password" | kinit administrator@${REALM}
    echo "$samba_password" | sudo net join -U Administrator@$REALM
    echo -e "${GREEN}[ OK ]${NC} Join domain successful" >> $LOG
}

##.......................start service.....................
startservice(){
banner 100 "Starting Samba Related Service"

    sudo systemctl start smb nmb winbind
    echo -e "${GREEN}[ OK ]${NC} Started service" >> $LOG
    echo -e "${GREEN}[ OK ]${NC} Installation Completed" >> $LOG
}

{
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
} | whiptail --clear  --title "[ KOOMPI AD Server ]" --backtitle "Samba Active Directory Domain Controller" \
--gauge "Please wait while installing" 6 60 0