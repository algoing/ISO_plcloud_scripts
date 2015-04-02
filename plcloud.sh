#!/bin/bash
#Filename:set.sh

interface_info=/root/interface_info.txt

check_ifcfg_exist() {
Interface=$1
if [ ! -f "/etc/sysconfig/network-scripts/ifcfg-${Interface}" ];then
	echo "${Interface} not set yet,use s to set it first"
	continue
else
	/bin/cp -f /etc/sysconfig/network-scripts/ifcfg-${Interface} /etc/sysconfig/network-scripts/ifcfg-${Interface}.bak
fi
}

check_interface_exist() {
Interface=$1
get_interface_list
Interface=${Interface:-none}
if ! echo "${Interfacelist}" | grep -w "${Interface}" >/dev/null;then	
	echo "${Interface} not exist,check your input"
	continue
fi
}

#get all the interface list
get_interface_list() {
Interfacelist="`/sbin/ip addr | egrep "^[2-9]" | awk -F '[: ]' '{print $3}' | xargs`"
}

#print all the interface infomation(name,status,ip,mac ...)
get_interface_info() {
/sbin/ip addr | egrep "(^[2-9]:|ether)" | awk -F '[: ]' '{if($0 ~ /UP/) print $3":UP";else if($0 ~ /DOWN/) print $3":DOWN";else if($0 ~ /link\/ether/) print $6":"$7":"$8":"$9":"$10":"$11}'| awk '/eth/{T=$0;next;}{print T,$0}' | awk 'BEGIN{printf "%-20s %-20s %-20s %-20s %-20s\n","id","interface:status","mac address","ip","netmask"}{printf "%-20s %-20s %-20s\n",NR,$1,$2}' > ${interface_info}
}

#get the active interface ip,netmask
get_interface_ip() {
Interface=$1
ip_inter="`ifconfig ${Interface} 2>/dev/null | grep "inet addr" | awk -F '[: ]' '{print $13}'`"
netmask_inter="`ifconfig ${Interface} 2>/dev/null | grep "inet addr" | awk -F '[: ]' '{print $19}'`"
}

#get all the active interface ip,netmask,gateway
get_all_ip() {
get_interface_list
get_interface_info

for i in ${Interfacelist};do
	get_interface_ip $i
	/bin/cp -f ${interface_info} ${interface_info}.bak
	if [ -n "${ip_inter}" -a -n "${netmask_inter}" ];then
	cat ${interface_info}.bak | awk -v ip="${ip_inter}" -v netmask="${netmask_inter}" -v interface="${i}" 'NR==1{print} NR>1{if($0 ~ interface) printf "%-20s %-20s %-20s %-20s %-20s\n",$1,$2,$3,ip,netmask;else print $0}' > ${interface_info}
	fi
done
}

#---------------------------------------------------
#      get the interface ifcfg from user
#---------------------------------------------------
get_interface_ifcfg() {
Interface=$1
Hwaddr="`/sbin/ip link show ${Interface} | grep ether | awk '{print $2}'`"

while true;do
read -p "${Interface}:BOOTPROTO ? (dhcp or static)(default:static)|:" Bootproto
Bootproto=${Bootproto:-static}
if [ "${Bootproto}" == "static" ] || [ "${Bootproto}" == "dhcp" ];then
	break
else
	echo "BOOTPROTO=[static|dhcp]"
fi
done

while true;do
read -p "${Interface}:ONBOOT ? (yes or no)(default:yes)|:" Onboot
Onboot=${Onboot:-yes}
if [ "${Onboot}" == "yes" ] || [ "${Onboot}" == "no" ];then
	break
else
	echo "ONBOOT=[yes|no]"
fi
done

while true;do
read -p "${Interface}:NM_CONTROLLED ? (yes or no)(default:yes)|:" Nm_controlled
Nm_controlled=${Nm_controlled:-yes}
if [ "${Nm_controlled}" == "yes" ] || [ "${Nm_controlled}" == "no" ];then
	break
else
	echo "NM_CONTROLLED=[yes|no]"
fi
done

if [ "${Bootproto}" == "static" ];then
	read -p "${Interface}:(ip address)|:" Ipaddr
	read -p "${Interface}:(netmask)(default:255.255.255.0)|:" Netmask
	Netmask=${Netmask:-255.255.255.0}
	read -p "${Interface}:(gateway)(default:none)|:" Gateway
	read -p "${Interface}:(DNS1)(default:none)|:" Dns1
	read -p "${Interface}:(DNS2)(default:none)|:" Dns2
fi
}

#-----------------------------------------------------------------
#      set the interface ifcfg file accroding to the user input
#-----------------------------------------------------------------
set_interface_ifcfg()
{
Interface=$1
cat > /etc/sysconfig/network-scripts/ifcfg-${Interface}.bak << EOF
TYPE=Ethernet
DEVICE="${Interface}"
HWADDR="${Hwaddr}"
ONBOOT="${Onboot}"
NM_CONTROLLED="${Nm_controlled}"
BOOTPROTO="${Bootproto}"
IPV6INIT=no
USERCTL=no
EOF

if [ "${Bootproto}" == "static" ];then
	echo "IPADDR="${Ipaddr}"" >> /etc/sysconfig/network-scripts/ifcfg-${Interface}.bak
	echo "NETMASK="${Netmask}"" >> /etc/sysconfig/network-scripts/ifcfg-${Interface}.bak
	[ -n "${Gateway}" ] && echo "GATEWAY="${Gateway}"" >> /etc/sysconfig/network-scripts/ifcfg-${Interface}.bak
	[ -n "${Dns1}" ] && echo "DNS1="${Dns1}"" >> /etc/sysconfig/network-scripts/ifcfg-${Interface}.bak
	[ -n "${Dns2}" ] && echo "DNS2="${Dns2}"" >> /etc/sysconfig/network-scripts/ifcfg-${Interface}.bak
fi
}

#-----------------------------------------------------------------
#     godfather 
#-----------------------------------------------------------------
godfather() {
Interface=$1
while true
do
	cat -n /etc/sysconfig/network-scripts/ifcfg-${Interface}.bak
	read -p "(y|a|c|d)(h for help)|:" check
	if [ "${check}" == "c" ];then 
		check=c
		change_interface_ifcfg ${Interface} ${check}
	elif [ "${check}" == "a" ];then
		check=a
		change_interface_ifcfg ${Interface} ${check}
	elif [ "${check}" == "d" ];then
		check=d
		change_interface_ifcfg ${Interface} ${check}
	elif [ "${check}" == "y" ];then
		break
	else
cat << EOF
-----------------------------------------
"y": apply the ifcfg file
"a": add a new line to the ifcfg file
"c": change a exist line
"d": delete a line 
-----------------------------------------
EOF
	fi
done

/bin/cp -f /etc/sysconfig/network-scripts/ifcfg-${Interface}.bak /etc/sysconfig/network-scripts/ifcfg-${Interface}
echo "${Interface} Set done,now restart the network service to active"
}

#-------------------------------------------------------------------------
#     change,add,delete the interface ifcfg file accroding to user input
#-------------------------------------------------------------------------
change_interface_ifcfg() {
Interface=$1
operation=$2
note=$3

[ "${operation}" == "d" ] && read -p "input the line number you want to delete|:" Line
[ "${operation}" == "c" ] && read -p "input the line number you want to change|:" Line
case ${operation} in
"c")
	Change="`cat /etc/sysconfig/network-scripts/ifcfg-${Interface}.bak | awk -F '=' -v line=${Line} 'NR==line{print $1"="}'`"
	read -p "input the new ${Change}|:" new
	sed -r -i "${Line}s/(^.*=).*/\1${new}/g" /etc/sysconfig/network-scripts/ifcfg-${Interface}.bak > /dev/null
;;
"d")
	sed -r -i "${Line}d" /etc/sysconfig/network-scripts/ifcfg-${Interface}.bak
;;
"a")
	read -p "please input the key|:" sub_key
	read -p "please input the value|:" sub_value
	echo ""${sub_key}"="${sub_value}"" >> /etc/sysconfig/network-scripts/ifcfg-${Interface}.bak
;;
esac	
}

#shutdown the interface
down_interface() {
Interface=$1
ifdown ${Interface} 2>/dev/null
if [ $? == 0 ];then
	echo "${Interface} shutdown done!"
else
	echo "${Interface} shutdown error,please check"
fi
}

#open the interface
open_interface() {
Interface=$1
ifup ${Interface} 2>/dev/null
if [ $? == 0 ];then
	echo "${Interface} open done!"
else
	echo "${Interface} open error,please check"
fi
}



cleans() {
echo "this is a test"
}

trap "{ cleans;  }" 1 2 3 4 6 8 9 11 13 15 17 18 19 20 21 22	

while true;do
read -p "PL-network|:" choice
case $choice in 
"q")
	read -p "please input your exit code:" Code
	if [ "${Code}" == "zijian" ];then 
		exit 2
	else 
		echo "error"
	fi
;;

"p"|"P")
	get_all_ip
	echo "-------------------------------------------------------------------------------------------------------------"
	cat ${interface_info}	
	echo "-------------------------------------------------------------------------------------------------------------"
;;

"r"|"R")
	/etc/init.d/network restart	
;;

"s"|"S")
	read -p "The interface you want to set|:" Interface
	check_interface_exist ${Interface}
	echo "This will clean the ${Interface} ifcfg"
	get_interface_ifcfg ${Interface}
	set_interface_ifcfg ${Interface}
	godfather ${Interface}
;;

"c"|"C")
	read -p "The interface you want to change|:" Interface
	check_interface_exist ${Interface}
	check_ifcfg_exist ${Interface}
	godfather ${Interface}
;;

"d"|"D")
	read -p "The interface you want to shutdown|:" Interface
	check_interface_exist ${Interface}
	down_interface ${Interface}
;;

"o"|"O")
	read -p "The interace you want to open|:" Interface
	check_interface_exist ${Interface}
	open_interface ${Interface}
;;

*)
	echo "${choice} is not be accept"
cat << EOF
---------------------------------------------
q: Quit
p: Print the current interface status
r: Restart the network service
s: Set a interface for your select
c: Change a interface argv for your select,(note:if you use "s" or "c" for a interface,the follow command is active)
	"y" to apply the ifcfg file
	"a" to add a new line to the ifcfg file
	"c" to change a exist line
	"d" to delete a line 
d: Shutdown a interface for your select
o: Open a interface for your select
r: Restart the network service
h: Print this help
--------------------------------------------
EOF
;;
esac
done
