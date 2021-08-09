#!/bin/bash
# Monitor servers states
#

# Hosts/www pages check settings
websites[0]=google.com
websites[1]=nextsite.com
websites[2]=gooogle.com/wrongpage
websites[3]=google.wrong.domen

# SSL Check settings
sslwebsites[0]=google.com
sslwebsites[1]=nextsite.com

ssldays=3

# SMTP Check settings
smtphosts[0]="smtp.gmail.com"
smtphosts[1]="smtp.someserver.ru"

smtpports[0]="465"
smtpports[1]="25"

# Telegram delivery settings
botapikey="xxxxxxxxxx"

chatids[0]="10001"
chatids[1]="10002"
chatids[2]="-90000"

# Email delivery settings
emailsto[0]="myadmin@mail.ru"
emailsto[1]="myadmin@gmail.com"

emailfrom="somesendmail@gmail.com"
emailpass="somepassword"
emailport=465
emailhost="smtp.gmail.com"

# Other
errors=0

# WWW Check
result+="<b>Web Sites</b>:%0A"

for www in ${websites[@]}; do
	info=$(curl -I -o /dev/stdout -w '%{time_total}tm-stmp' --url "https://$www" -m 9 -s)
	errr=$(echo $?)

	code=$(echo "$info" | grep HTTP | grep -v 'HTTP/2 200')
	date=$(echo "$info" | grep -i 'date:')
	dlay=$(echo "$info" | grep tm-stmp | sed -e 's/tm-stmp//')

	site=$(echo "$www" | sed 's/\./_/g')

	if [[ $errr != 0 ]]; then
		result+="<b>$site</b>: Cannot connect to the host:$errr%0A"
    ((errors=errors+1))
	elif [[ -n $code ]]; then
		result+="<b>$site</b>: Wrong response code:$code%0A"
    ((errors=errors+1))
  else
		result+="<b>$site</b>: OK, time: $dlay%0A"
  fi
done

# SSL Check
old_date=$(<date.txt)
cur_date=`date '+%d %b %Y'`

if [[ $cur_date != $old_date ]]; then

  echo $cur_date > date.txt
  result+="%0A<b>SSL Expiration</b>:%0A"

  for www in ${sslwebsites[@]}; do
    expirationdate=$(date -d "$(: | openssl s_client -connect $www:443 -servername $www 2>/dev/null | openssl x509 -text | grep 'Not After' | awk '{print $4,$5,$7}')" '+$')

    in7days=$(($(date +%s) + (86400*$ssldays)));

    daysleft=$((($expirationdate-$(date "+%s"))/(60*60*24)))

    site=$(echo "$www" | sed 's/\./_/g')

    if [ $in7days -gt $expirationdate ]; then
      result+="<b>$site</b>: Certificate expires in less than $ssldays days, on $(date -d @$expirationdate '+%d %b %Y'), <b>$daysleft</b> days left.%0A"
      ((errors=errors+1))
    else
      result+="<b>$site</b>: OK, Expires on $(date -d @$expirationdate '+%d %b %Y'), <b>$daysleft</b> days left.%0A"
    fi
  done
fi


#SMTP Check
result+="%0A<b>E-Mail services</b>:%0A"
for index in {0..1};
do
	/usr/bin/nmap -v "${smtphosts[index]}" -Pn -p "${smtpports[index]}" | grep open

	if [ $? -eq 0 ]; then
		result+="${smtphosts[index]}: External SMTP Service test OK%0A"
	else
		result+="${smtphosts[index]}: External SMTP Service doesn't work%0A"
    ((errors=errors+1))
	fi
done

if [ "$errors" -gt "0" ]; then
	result+="%0A==========%0A<b>ATTENTION!!!! [$errors] ERRORS HAVE BEEN FOUND!!!!</b>%0A==========:%0A"

	emailresult=$(echo "$result" | sed 's/%0A/\n/g')
  emailresult=$(echo "$emailresult" | sed 's/<b>//g')
  emailresult=$(echo "$emailresult" | sed 's/<\/b>//g')

	for emailto in ${emailsto[@]}; do
		curl --url "smtps://$emailhost:$emailport" --ssl-reqd \
      --mail-from "$emailfrom" \
      --mail-rcpt "$emailto" \
      --user "$emailfrom:$emailpass" \
      -T <(echo -e "From: $emailfrom\nTo: $emailto\nSubject: Attention! [$errors] Errors detected.\n\n$emailresult")
	done
fi

for chatid in ${chatids[@]}; do
  curl -s -X POST "https://api.telegram.org/bot$botapikey/sendMessage" -d chat_id="$chatid" -d text="$result" -d parse_mode=HTML
done
