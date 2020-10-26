#!/bin/bash
clear 

##.................color...................
RED='\033[0;31m'
GREEN='\e[32m'
YELLOW='\033[1;33m'
BLUE='\033[1;32m'
NC='\033[0m'



createlog(){

    ## syncronize time

    timedatectl set-timezone Asia/Phnom_Penh
    timedatectl set-ntp 1
    timedatectl

    NOW=$(date +"%m-%d-%Y-%T")
    mkdir -p /klab/
    mkdir -p /klab/samba
    mkdir -p /klab/samba/log
    LOG="/klab/samba/log/clientlog-$NOW"

    rm -rf $LOG
}

##.................read input..................
readinput(){

    hostname=$(TERM=ansi whiptail --clear --title "[ Hostname Selection ]"  --backtitle "Samba Active Directory Domain Controller" \
    --nocancel --ok-button Submit --inputbox \
    "\nPlease enter a suitable new hostname for your client to join the active directory server.\n\nExample:  adclient-01\n" 10 100 \
    3>&1 1>&2 2>&3)

    REALM=$(TERM=ansi whiptail --clear --backtitle "Samba Active Directory Domain Controller" \
    --title "[ Realm Selection ]" --nocancel --ok-button Submit  --inputbox "                                       
Please enter the FULL REALM NAME of the active directory server. Example:

        Server Name     =   adlab
        Domain Name     =   koompilab
        Realm Name      =   koompilab.org

----------------------------------------------------------------------------
        Full Realm Name =   adlab.koompilab.org" 15 80 3>&1 1>&2 2>&3) 
    
    server_hostname=$(echo $REALM |awk -F'.' '{printf $1}')
    secondlvl_domain=$(echo $REALM |awk -F'.' '{printf $NF}')

    DOMAIN=${REALM//"$server_hostname."}
    DOMAIN=${DOMAIN//".$secondlvl_domain"}

    FULLREALM=$REALM

    if [[ "$DOMAIN" == *.* ]];
    then
        DOMAIN=$(echo $DOMAIN | awk -F',' '{printf $1}')
    fi    

    REALM="$DOMAIN.$secondlvl_domain"

    REALM=${REALM^^}
    DOMAIN=${DOMAIN^^}

    while true;
    do
        IPADDRESS=$(TERM=ansi whiptail --clear --backtitle "Samba Active Directory Domain Controller" \
        --title "[ IP of Domain ]" --nocancel --ok-button Submit --inputbox \
        "\nPlease enter the IP of the active directory server\nExample:  172.16.1.1\n" 8 80 3>&1 1>&2 2>&3)
        if [[ $IPADDRESS =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]];
        then
            break
        else
            TERM=ansi whiptail --clear --backtitle "Samba Active Directory Domain Controller" --title \
            "[ IP for Domain ]" --msgbox "Your IP isn't valid. A valid IP should looks like XXX.XXX.XXX.XXX" 10 80
        fi
    done

    admin=$(TERM=ansi whiptail --clear --title "[ Administrator Selection ]"  --backtitle "Samba Active Directory Domain Controller" \
    --nocancel --ok-button Submit --inputbox \
    "\nPlease enter A Suitable User for your client to join the active directory server.\n\nDefault:  Administrator" 10 100 \
    3>&1 1>&2 2>&3)

    if [[ -z "$admin" ]];
    then
        admin=Administrator
    fi


    while true;
    do
        samba_password=$(TERM=ansi whiptail --clear --title "[ Administrator Password ]" --nocancel --ok-button Submit --passwordbox \
        "\nPlease enter Administrator password for joining domain\n" 10 80 3>&1 1>&2 2>&3)

        samba_password_again=$(TERM=ansi whiptail --clear --title "[ Administrator Password ]" --nocancel --ok-button Submit \
        --passwordbox "\nPlease enter Administrator password again" 10 80  3>&1 1>&2 2>&3)

        if  [[ "$samba_password" != "$samba_password_again" ]];
        then
            TERM=ansi whiptail --clear --backtitle "Samba Active Directory Domain Controller" --title \
            "[ Administrator Password ]" --msgbox "Your password does match. Please retype it again" 10 80

        elif [[ "${#samba_password}" -lt 8 ]];
        then
                TERM=ansi whiptail --clear --backtitle "Samba Active Directory Domain Controller" --title \
                "[ Administrator Password ]" --msgbox "Your password does not meet the length requirement." 10 80
        else
                break
        fi

    done

}


check_root(){
    if [[ $(id -u) != 0 ]];
    then 
        echo -e "${RED}[ FAILED ]${NC} Root Permission Requirement Failed"
        exit;
    fi 
}


sethostname(){

    sudo hostnamectl set-hostname $hostname
    HOSTNAME=$hostname

}

##....................banner....................
banner(){

    echo -e "XXX\n$1\n$2\nXXX"
}

##....................check root user.................

##..........................install package base.......................
install_package_base(){

    errorexit="false"
    sudo pacman -Sy pacman-contrib --noconfirm 2>/dev/null >> $LOG
    progress=10

    for PKG in $(cat $(pwd)/package/package_x86_64)
    do
        progress=$(echo $(( $progress+2 )))
        banner "$progress" "Installing package $PKG..."

        if [[ -n "$(pacman -Qs $PKG)" ]];
        then 
            echo -e "${GREEN}[ OK ]${NC} Package: $RED $PKG $NC Installed." >> $LOG
        else 
            sudo pacman -S $(pactree -alsu $PKG) --needed --noconfirm 2>/dev/null >> $LOG
            echo -e "${GREEN}[ OK ]${NC} Package: $RED $PKG $NC Installed successful." >> $LOG
        fi
    done

    for PKG in $(cat $(pwd)/package/package_x86_64)
    do

        if [[ ! -n "$(pacman -Qs $PKG)" ]];
        then 
            echo -e "${GREEN}[ OK ]${NC} Package: $RED $PKG $NC failed to Install" >> $LOG
            errorexit="true"
            break
        fi
    done

    if [[ "$errorexit" == "true" ]];
    then
        exit
    else
        cp service/smb.service /usr/lib/systemd/system/
        cp service/nmb.service /usr/lib/systemd/system/
        cp service/winbind.service /usr/lib/systemd/system/
    fi
}

##...................krb5 rename.......................
krb5(){

    cp $(pwd)/krb5/krb5.conf /etc/
    grep -rli SRVREALM /etc/krb5.conf | xargs -i@ sed -i s/SRVREALM/"${server_hostname^^}.$REALM"/g @
    grep -rli REALM /etc/krb5.conf | xargs -i@ sed -i s/REALM/$REALM/g @
    grep -rli DOMAIN /etc/krb5.conf | xargs -i@ sed -i s/DOMAIN/$DOMAIN/g @
    echo -e "${GREEN}[ OK ]${NC} Configuring krb5..." >> $LOG

}

##..................samba rename...................
samba(){

    sudo cp $(pwd)/samba/* /etc/samba/
    sudo cp $(pwd)/samba/pam_winbind.conf /etc/security/
    echo -e "${GREEN}[ OK ]${NC} copy config."

    grep -rli DOMAIN /etc/samba/smb.conf | xargs -i@ sed -i s/DOMAIN/$DOMAIN/g @
    grep -rli SMALLREALM /etc/samba/smb.conf | xargs -i@ sed -i s/SMALLREALM/${REALM,,}/g @
    grep -rli REALM /etc/samba/smb.conf | xargs -i@ sed -i s/REALM/$REALM/g @
    grep -rli HOSTNAME /etc/samba/smb.conf | xargs -i@ sed -i s/HOSTNAME/$HOSTNAME/g @
    echo -e "${GREEN}[ OK ]${NC} Configuring samba rename"

}

##.....................pam mount.......................
pam_mount(){
   
    cp $(pwd)/pam_mount/* /etc/security/
    echo -e "${GREEN}[ OK ]${NC} Copy pam_mount configure" 

    grep -rli REALM /etc/security/pam_mount.conf.xml | xargs -i@ sed -i s+REALM+${REALM,,}+g @
    grep -rli DOMAIN /etc/security/pam_mount.conf.xml | xargs -i@ sed -i s+DOMAIN+${DOMAIN}+g @
    echo -e "${GREEN}[ OK ]${NC} Configure pam_mount"

}
##..................mysmb service..................
mysmb(){
    
    sudo cp $(pwd)/scripts/mysmb /usr/bin/mysmb
    sudo cp $(pwd)/service/mysmb.service /usr/lib/systemd/system/
    sudo chmod +x /usr/bin/mysmb
    echo -e "${GREEN}[ OK ]${NC} Configuring necessary service" 
}

##..................nsswitch..................
nsswitch(){
    
    sudo cp $(pwd)/nsswitch/nsswitch.conf /etc/nsswitch.conf
    echo -e "${GREEN}[ OK ]${NC} Configuring nsswitch" 
}

##..................pam authentication...............
pam(){

    sudo cp $(pwd)/pam.d/* /etc/pam.d/
    echo -e "${GREEN}[ OK ]${NC} Configuring pam.d"
}

##...................resolv..................
resolv(){

    RESOLVCONF_FILE=/etc/resolvconf.conf
    RESOLV_FILE=/etc/resolv.conf

    echo -e "[main]\ndns=none\nsystemd-resolved=false" > /etc/NetworkManager/conf.d/dns.conf
    systemctl restart NetworkManager
    rm -rf $RESOLV_FILE
    echo -e "${GREEN}[ OK ]${NC} Restrict NetworkManager from touching resolv.conf"

    #resolvconf
    cp resolv/resolvconf.conf ${RESOLVCONF_FILE}
    grep -rli REALM ${RESOLVCONF_FILE} | xargs -i@ sed -i s+REALM+${REALM,,}+g @
    grep -rli NAMESERVER ${RESOLVCONF_FILE} | xargs -i@ sed -i s+NAMESERVER+${IPADDRESS}+g @
    echo -e "${GREEN}[ OK ]${NC} Configuring resolvconf.conf"

    #resolv
    echo "search ${REALM,,}" > ${RESOLV_FILE}
    echo "nameserver ${IPADDRESS}" >> ${RESOLV_FILE}
    echo "nameserver 8.8.8.8" >> ${RESOLV_FILE}
    echo "nameserver 8.8.4.4" >> ${RESOLV_FILE}
    echo -e "${GREEN}[ OK ]${NC} Configuring resolv.conf"

    resolvconf -u

    echo -e "\n${IPADDRESS} ${REALM,,}\n" >> /etc/hosts

    echo -e "${GREEN}[ OK ]${NC} Configure RESOLVE successful. $NC"
}

ntp(){

    NTPCONF=/etc/ntp.conf

    cp ntp/ntp.conf $NTPCONF
    grep -rli NTPSRV $NTPCONF | xargs -i@ sed -i s+NTPSRV+${FULLREALM,,}+g @

    echo -e "${GREEN}[ OK ]${NC} Configure NTP successful. $NC"

}

##........................stop service...................
stopservice(){

    sudo systemctl enable ntpd smb nmb winbind mysmb 
    sudo systemctl stop ntpd smb nmb winbind mysmb
    echo -e "${GREEN}[ OK ]${NC} Stoped service"

}

##.....................join domain.......................
joindomain(){

    echo "$samba_password" | kinit ${admin,,}@${REALM}
    echo "$samba_password" | sudo net ads join -U $admin@$REALM
    echo -e "${GREEN}[ OK ]${NC} Join domain successful"
}

##.......................start service.....................
startservice(){

    sudo systemctl start mysmb ntpd smb nmb winbind
    echo -e "${GREEN}[ OK ]${NC} Started service" 
    echo -e "${GREEN}[ OK ]${NC} Installation Completed"

}

check_root
createlog
readinput

{

    banner "5" "Setting Hostname"
    sethostname >> $LOG || echo -e "${RED}[ FAILED ]${NC} Setting Hostname Failed. Please Check log in $LOG" 

    banner "10" "Installing necessary packages."
    install_package_base || echo -e "${RED}[ FAILED ]${NC} Installing Packages Failed. Please Check log in $LOG" 

    banner "25" "Configuring Keberos Network Authenticator"
    krb5 >> $LOG || echo -e "${RED}[ FAILED ]${NC} Configuring Keberos Failed. Please Check log in $LOG" 

    banner "27" "Configuring Network Time Server"
    ntp >> $LOG || echo -e "${RED}[ FAILED ]${NC} Configuring Network Time Server. Please Check log in $LOG" 
 
    banner "30" "Configuring Samba Active Directory Domain Controller Server"
    samba >> $LOG || echo -e "${RED}[ FAILED ]${NC} Configuring Samba Failed. Please Check log in $LOG" 

    banner "50" "Configuring Auto-mount Storage Drives Settings"
    pam_mount >> $LOG || echo -e "${RED}[ FAILED ]${NC} Configuring PAM Mount Failed. Please Check log in $LOG" 

    banner "55" "Configuring Samba Helper Service"
    mysmb >> $LOG || echo -e "${RED}[ FAILED ]${NC} Configuring Samba Helper Failed. Please Check log in $LOG" 

    banner "65" "Configuring Name Service Swtich"
    nsswitch >> $LOG || echo -e "${RED}[ FAILED ]${NC} Configuring Name Service Switch Failed. Please Check log in $LOG" 

    banner "70" "Configuring Pluggable Authentication Modules For Linux"
    pam >> $LOG || echo -e "${RED}[ FAILED ]${NC} Configuring Pluggable Authentication Modules For Linux Failed. \
    Please Check log in $LOG" 

    banner "75" "Configuring Dynamic Name Service Resolver"
    resolv >> $LOG || echo -e "${RED}[ FAILED ]${NC} Configuring DNS Failed. Please Check log in $LOG" 

    banner "80" "Stopping Samba Related Service"
    stopservice &>> $LOG || echo -e "${RED}[ FAILED ]${NC} Stopping Related Samba Service Failed. Please Check log in $LOG"

    banner "90" "Joining $REALM Domain" 

} | whiptail --clear --title "[ KOOMPI AD Server ]" --gauge "Please wait while installing" 10 100 0

    joindomain &>> $LOG || echo -e "${RED}[ FAILED ]${NC} Joining Domain Failed. Please Check log in $LOG"

{

    banner "100" "Starting Samba Related Service"
    startservice &>> $LOG || echo -e "${RED}[ FAILED ]${NC} Starting Related Samba Service Failed. Please Check log in $LOG"

} | whiptail --clear --title "[ KOOMPI AD Server ]" --gauge "Please wait while installing" 10 100 85

clear