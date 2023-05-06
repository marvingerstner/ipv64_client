#!/bin/bash
clear
######here all the variables#######################################################################################
apps="git build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libreadline-dev libffi-dev libsqlite3-dev libbz2-dev python3 python3-pip" #add here your application
service_file="/etc/systemd/system/node64_io.service"
initD_file="/etc/init.d/node64_io"
####################################################################################################################
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi
#this is the auto-install routine
if ! dpkg -s $apps >/dev/null 2>&1; then
    echo "Currently the source are updated"
    apt update -y >/dev/null 2>&1
    echo "The programs to be required will now be installed."
    apt install $apps -y >/dev/null 2>&1
fi

function print_text() {
    echo "______________________________________________________"
    echo "                   _         ____    ___     _        "
    echo "                  | |       / ___|  /   |   (_)       "
    echo " _ __    ___    __| |  ___ / /___  / /| |    _   ___  "
    echo "| '_ \  / _ \  / _\` | / _ \| ___ \/ /_| |   | | / _ \ "
    echo "| | | || (_) || (_| ||  __/| \_/ |\___  | _ | || (_) |"
    echo "|_| |_| \___/  \__,_| \___|\_____/    |_/(_)|_| \___/ "
    echo "______________________________________________________"
    # @uelle: https://patorjk.com/software/taag/#p=display&h=1&v=2&f=Doom&t=node64.io%0A
}

function get_ipv64_client() {
    if [ ! -d "/opt" ]; then
        mkdir /opt
    fi
    cd /opt/
    git clone https://github.com/ipv64net/ipv64_client.git
    cd ipv64_client/
    pip3 install -r requirements.txt
}

function update_ipv64_client() {
    cd /opt/ipv64_client/
    git fetch --all
    pip3 install -r requirements.txt
}

function ask_for_secret() {
    echo "################################################################"
    read -p "Please enter IPv64-Node-Secret: " secret
    echo "Your Secret is: ${secret}"
    echo "################################################################"
}

function make_service_file() {

    echo "[Unit]" >"${service_file}"
    echo "Description=node64.io client that is receiving tasks for dns, icmp and tracroute task." >>"${service_file}"
    echo "After=network.target" >>"${service_file}"
    echo "StartLimitIntervalSec=0" >>"${service_file}"
    echo "" >>"${service_file}"
    echo "[Service]" >>"${service_file}"
    echo "Type=simple" >>"${service_file}"
    echo "Restart=always" >>"${service_file}"
    echo "WorkingDirectory=/opt/ipv64_client/" >>"${service_file}"
    echo "ExecStart=python3 ipv64_client.py ${secret}" >>"${service_file}"
    echo "" >>"${service_file}"
    echo "[Install]" >>"${service_file}"
    echo "WantedBy=network-online.target" >>"${service_file}"
}

function make_initD_file() {
    echo "#!/bin/sh /etc/rc.common" >"${initD_file}"
    echo "USE_PROCD=1" >"${initD_file}"
    echo "START=95" >>"${initD_file}"
    echo "STOP=01" >>"${initD_file}"
    echo "start_service() {" >>"${initD_file}"
    echo "    procd_open_instance" >>"${initD_file}"
    echo "    procd_set_param respawn ${threshold:-20} ${timeout:-5} ${retry:-3}" >>"${initD_file}"
    echo "    procd_set_param command /usr/bin/python3 "/opt/ipv64_client/ipv64_client.py" ${secret}" >>"${initD_file}"
    echo "    procd_close_instance" >>"${initD_file}"
    echo "}" >>"${initD_file}"
}

function edit_config() {
    old_config=$(cat "${service_file}" | head -n10 | tail -n1 | awk '{print $3}')
    echo "------------------------------------------------------------------"
    echo "Your current node64.io Secret is: ""${old_config}"
    echo "------------------------------------------------------------------"
    while true; do
        read -p "Do you wish to your node64.io Secret? [y|n] " yn
        case $yn in
        [Yy]*)
            ask_for_secret
            make_service_file
            make_initD_file
            break
            ;;
        [Nn]*)
            echo "No changes have been made."
            exit 0
            ;;
        *) echo "Please answer yes or no." ;;
        esac
    done

}

display_help() {
    echo "Usage: install-service.sh [-h | --help] [-i | --install] [-u | --update]"
    echo "The Node64.io client is receiving tasks for dns, icmp and tracroute task."
    echo
    echo "  -h | --help    -> show this help text"
    echo "  -i | --install -> install the node64_io on your system"
    echo "  -u | --update  -> update the node64_io to the latest Version"
    echo "  -e | --edit    -> edit your node64_io config"
    echo
    exit 1
}

while :; do
    case "$1" in
    -h | --help)
        print_text
        display_help
        exit 0
        ;;
    -i | --install)
        if [ ! -d "/opt/ipv64_client/.git" ]; then
            print_text
            echo "****************************"
            echo "Install the node64_io Client"
            echo "****************************"
            get_ipv64_client
            ask_for_secret
            make_service_file
            make_initD_file
            echo "----------------------------------------------------"
            echo "The installation of the node64_io Client is finished"
            echo "----------------------------------------------------"
            echo "Enable the node64_io service"
            systemctl daemon-reload
            sleep 2
            systemctl enable node64_io.service
            sleep 2
            systemctl start node64_io.service
            break
        else
            print_text
            echo "*********************************************************"
            echo "The node64_io Client is already installed on your System."
            echo "Please update node64_io Client via -u."
            echo "*********************************************************"
            display_help
            exit 1
        fi
        ;;
    -u | --update)
        if [ -d "/opt/ipv64_client/.git" ]; then
            print_text
            echo "***************************"
            echo "Update the node64_io Client"
            echo "***************************"
            update_ipv64_client
            echo "----------------------------------------------"
            echo "The update of the node64_io Client is finished"
            echo "----------------------------------------------"
            echo "now restart the node64_io Service"
            systemctl restart node64_io.service
            sleep 2
            break
        else
            print_text
            echo "*********************************************************************************************"
            echo "The directory has not been cloned from Github or node64_io Client has not been installed yet."
            echo "Please install node64_io Client via github with -i."
            echo "*********************************************************************************************"
            display_help
            exit 1
        fi
        ;;
    -e | --edit)
        print_text
        if [ -f "${service_file}" ]; then
            echo "***************************"
            echo "Edit the node64_io Client"
            echo "***************************"
            edit_config
            echo "--------------------------------------------"
            echo "The edit of the node64_io Client is finished"
            echo "--------------------------------------------"
            echo "Reload and restart the node64_io service"
            systemctl daemon-reload
            sleep 2
            systemctl stop node64_io.service
            sleep 2
            systemctl start node64_io.service
            break
        else
            echo "***************************************************"
            echo "The service node64.io has not been installed yet."
            echo "Please install node64_io Client via github with -i."
            echo "***************************************************"
            exit 1
        fi
        ;;
    --)
        shift
        break
        ;;
    -*)
        echo "Error: Unknown option: $1" >&2
        display_help
        exit 1
        ;;
    *)
        echo "Error: There was no option" >&2
        display_help
        exit 1
        ;;
    esac
done

# created by Mr.Phil
