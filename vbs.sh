#!/bin/bash

function main {
  echo "Please select a task:"
  echo
  echo "1. Add port forwarding rule"
  echo "2. Delete port forwarding rule"
  echo "3. Change ssh port"
  echo "4. Install BBR"
  echo "5. Install x-ui"
  echo "6. Quit"
  echo
  read -p "Enter your choice (1-6): " choice

  clear
  # Handle the user's selection
  case $choice in
    1)
      # Add the NAT rule to the PREROUTING chain
      read -p "Enter Server Ip : " server_ip
      read -p "Enter Destination Server Ip : " destination_server_ip
      addPortForwardRule $server_ip $destination_server_ip
      ;;
    2)
      # Delete the NAT rule from both chains
      deletePortForwardRule
      ;;
    3)
      echo "current ssh port :" $(getSSHPort)
      read -p "Enter new port : " new_port
      changeSSHPort $new_port
      ;;
    4)
      installBBR
      ;;
    5)
      installXUI
      ;;
    6)
      echo "Good Bye"
      exit 0
      ;;
    *)
      echo "Invalid choice"
      ;;
  esac

}


function getSSHPort {
  ssh_port=$(grep -iE '^[[:space:]]*Port[[:space:]]+[0-9]+$' /etc/ssh/sshd_config | awk '{print $2}')
  if [ -z "$ssh_port" ]; then
    echo "SSH port not found in config file"
    return 1
  else
    echo "$ssh_port"
    return 0
  fi
}

function changeSSHPort {
  new_port=$1

  if [ -z "$new_port" ]; then
    echo "You need to specify a new SSH port number"
    return 1
  fi

  if [[ "$new_port" =~ [^0-9] ]]; then
    echo "The SSH port number must be a positive integer"
    return 1
  fi

  if [ "$new_port" -lt 1024 ] || [ "$new_port" -gt 65535 ]; then
    echo "The SSH port number must be between 1024 and 65535"
    return 1
  fi

  sed -i "s/^#*Port .*/Port $new_port/" /etc/ssh/sshd_config

  systemctl restart sshd

  echo "SSH port changed to $new_port"

}

function addPortForwardRule {
    sysctl net.ipv4.ip_forward=1
    ssh_port=$(getSSHPort)

    if [ $ssh_port != "SSH port not found in config file" ]; then
        iptables -t nat -A PREROUTING -p tcp --dport $ssh_port -j DNAT --to-destination $1
    fi

    iptables -t nat -A PREROUTING -j DNAT --to-destination $2
    iptables -t nat -A POSTROUTING -j MASQUERADE

    if [ -f /etc/rc.local ]; then
        # If the file exists, empty it
        echo -n > /etc/rc.local
    else
        # If the file doesn't exist, create it and make it executable
        touch /etc/rc.local
        chmod +x /etc/rc.local
    fi

    echo "#!/bin/bash" >> /etc/rc.local
    echo sysctl net.ipv4.ip_forward=1 >> /etc/rc.local
    if [ $ssh_port != "SSH port not found in config file" ]; then
        echo iptables -t nat -A PREROUTING -p tcp --dport $ssh_port -j DNAT --to-destination $1 >> /etc/rc.local
    fi
    echo iptables -t nat -A PREROUTING -j DNAT --to-destination $2 >> /etc/rc.local
    echo iptables -t nat -A POSTROUTING -j MASQUERADE >> /etc/rc.local
    echo exit 0 >> /etc/rc.local

    echo "Added port forwarding rule"
}

function deletePortForwardRule {
      sysctl net.ipv4.ip_forward=0
      if [ -f /etc/rc.local ]; then
          # If the file exists, delete it
          rm /etc/rc.local
      fi
      iptables -t nat -F PREROUTING
      iptables -t nat -F POSTROUTING
      echo "Deleted port forwarding rule"
}

function installBBR {
  wget -N --no-check-certificate https://github.com/teddysun/across/raw/master/bbr.sh && chmod +x bbr.sh && bash bbr.sh
}

function installXUI {
  bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
}

function checkParameters {
  for (( i = 1; i <= $#; i++ )); do
    option=${!i}
    if [[ "${option:0:1}" != "-" ]]; then
      continue
    fi
    echo
    case "${!i}" in
        "-p")
            # port forwarding
            echo "port forwarding"

            si=$((i+1))
            si=${!si}

            di=$((i+2))
            di=${!di}

            if [[ $si =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] && [[ $di =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
              addPortForwardRule $si $di
              i=$((i+2))
            else
              echo "invalid -p params (ex : -p [server id] [destination server id] )"
              exit 1
            fi
            ;;
        "-s")
            # change ssh port
            echo "changing ssh port"

            p=$((i+1))
            p=${!p}

            if [[ "${p:0:1}" == "-" ]]; then
                  echo "invalid -p params (ex : -s [new ssh port] )"
                  exit 1
            fi

            changeSSHPort $p

            ;;
        "-b")
            # install bbr script
            echo "installing bbr script"
            installBBR
            ;;
          "-x")
            # install x-ui
            echo "installing x-ui"
            installXUI
            ;;
        *)
            echo "unknown command: ${option}"
            exit 1
            ;;
    esac
    echo "------"
  done
}

while true; do
  if [ $# == 0 ];
  then
      clear
      main
      echo
      echo
      read -p "Press Enter to continue"
  else
        checkParameters $@
  fi

  exit 0
done
