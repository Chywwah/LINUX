#!/bin/bash

#Script a executer au niveau du client local souhaitant utiliser le serveur local
if [ -z "$1" ];then
	echo "./repo.sh <IP _SERVEUR>"
	exit
fi
 
if ! grep -q "http://${1}/" /etc/apt/sources.list;then
	echo "deb [trusted=yes] http://${1}/ ./" >> /etc/apt/sources.list
	apt update
fi
