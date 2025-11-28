#!/bin/bash 

#creation du serveur web qui hebergera les paquets locaux
test_web_site(){
	echo -e "<VirtualHost *:80>\nServerName www.apt.mg\nServerAdmin webmaster@localhost\nDocumentRoot /var/www/html/apt\n</VirtualHost>" > /etc/apache2/sites-available/apt_local.conf
	if [ ! -d /var/www/html/apt ];then 
		mkdir /var/www/html/apt
		chown -R www-data:www-data /var/www/html/apt
		chmod -R 755 /var/www/html/apt
	fi
	if ! grep -q "127.0.0.1 www.apt.mg" /etc/hosts;then #configuration DNS
		echo "127.0.0.1 www.apt.mg" >> /etc/hosts
        fi
	a2dissite apt_local
	a2ensite apt_local
        systemctl reload apache2
}

make_repo(){
	cp /var/cache/apt/archives/*.deb /var/www/html/apt
	dpkg-scanpackages /var/cache/apt/archives/*.deb /dev/null > /var/www/html/apt/Packages #generer le fichier Packages pour indexation
	dpkg-scanpackages /var/cache/apt/archives/*.deb /dev/null | gzip -9c > /var/www/html/apt/Packages.gz #generer les .gz de tous les .debOrigin: localrepo 
	if ! grep -q "deb [trusted=yes] http://www.apt.mg/ ./" /etc/apt/surces.list;then
		echo "deb [trusted=yes] http://www.apt.mg/ ./" >> /etc/apt/sources.list
	fi
	apt update
}

echo -e "Cette operation peut durer quelques secondes \nVeuillez patienter...."

test_web_site > /dev/null 2>&1
make_repo > /dev/null 2>&1 

