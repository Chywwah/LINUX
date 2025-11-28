#!/bin/bash

send_mail(){
	echo -e "\n\nBonjour,\nIl semblerait que vous avez atteint le quota designe par l'administrateur${2}\n${3}" | mail -s "$(date)" $1
}

make_quota_home() {
	grep -vq "^#" /etc/fstab |grep -wq "/home" |grep -q "usrquota" 
	if [ $? -ne 0 ];then
		line_number=$(cat /etc/fstab |awk '$2=="/home" && $1 != "#"{print NR}')
		option=$(sed -n "${line_number}p" /etc/fstab |awk '{print $4}')
		sed -i "${line_number}s/$option/${option},usrquota/" /etc/fstab
		systemctl daemon-reload
		mount -o remount /home
		quotacheck -fcum /home
		quotaon  /home
		setquota  -t 604800 604800 /home
		setquota -u root 512000 716000 0 0 /home
	fi
	user_list=$(repquota /home |sed "1,6d" |awk ' $4==0 {print $1}') #appliquer les limites quotas seulement si ce n'est pas encore appliques
	for user in $(awk -F: '$3>=1000 {print $1}' /etc/passwd); do
		if echo "$user_list" |grep -q $user;then
			edquota -p root $user  #copier les config de root vers tous les users
		fi
	done
}


look_limit_home(){
        bad_user=$(repquota /home |sed "1,5d" |awk '$3>=$4 && $1 != ""{print $1}')
	for user in $bad_user;do
		send_mail $user "$(sed -n "4p" <<< $(repquota /home))" "$(repquota /home| grep $user)" 
	done
}

make_quota_data() {
         cat /etc/fstab |grep -vq "^#" |grep -wq "/data" |grep -q "grpquota" 
         if [ $? -ne 0 ];then
                 line_number=$(cat /etc/fstab |awk '$2=="/data" && $1 != "#" {print NR}')
 		 option=$(sed -n "${line_number}p" /etc/fstab |awk '{print $4}')
                 sed -i "${line_number}s/$option/${option},grpquota/" /etc/fstab
		 systemctl daemon-reload
                 mount -o remount /data
                 quotacheck -cgm /data
                 quotaon -g /data
		 setquota -g root 0 0 10 15  /data
		 setquota -tg 604800 604800  /data
	fi
        grp_list=$(repquota -g /data |sed "1,6d" |awk '$4==0 {print $1}') 
        for grp in $(awk -F: '$3>=1000 {print $1}' /etc/group); do
        	if echo "$grp_list" |grep -q $grp;then 
			edquota -g -p root $grp
		fi
       	done
}

look_limit_data(){
        check_list=$(repquota -g /data |sed "1,5d")
        while IFS= read -r line ;do
                bad_group=$(echo "$line" |awk '$2=="++" || $2=="-+" || $2 == "+-" {print $1}')
                if [ -n "$bad_group" ];then
                        bad_user=$(getent group $bad_group |cut -d: -f4 |tr "," "\n")
                        for user in $bad_user;do
				send_mail $user "$(sed -n "4p" <<< $(repquota -g /data))" "$line" 
                        done
			send_mail $bad_group "$(sed -n "4p" <<< $(repquota -g /data))" "$line" #groupe principal
                fi
        done <<< "$check_list"
}

send_every_day_mail(){
	echo "#!/bin/bash" >> /root/every_day.sh
	bad_group=$(echo "$line" |awk '$2=="++" || $2=="-+" || $2 == "+-" {print $1}') > /root/every_day.sh
	bad_user=$(repquota /home |sed "1,5d" |awk '$3>=$4 && $1 != ""{print $1}') >> /root/every_day.sh
	if [ -n "$bad_user" ] || [ -n "$bad_group" ] ;then >> /root/every_day.sh
		/root/make_quota.sh >>  /root/every_day.sh
	fi
}


make_cron(){
	crontab -l 2>/dev/null > temp || touch temp
	grep -q "make_quota.sh" temp || echo "0 12 * * 1 /root/make_quota.sh" >> temp
	grep -q "make_quota.sh" <<< "$(crontab -l)" | echo "0 12 * * * /root/every_day.sh" >> temp
	crontab temp
	rm -f temp
}

make_quota_home 2>/dev/null 
look_limit_home 2>/dev/null 
make_quota_data 2>/dev/null 
look_limit_data 2>/dev/null 
make_cron 2>/dev/null 

