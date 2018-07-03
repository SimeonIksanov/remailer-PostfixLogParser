#!/bin/bash

cd /root/API

#
# STEP 1
#
MailLogFile="/var/log/mail.info"
fileStep1="./step1.log"
fileStep2="./step2.log"
# интервал за который берется лог почтовика, с этой же переодичностью должен работать запускать скрипт крон
interval=10
# Вычисляется дата и время interval минут назад
prevDate=$(date -d "$interval minutes ago" +'%b %_d %H:%M')

rm $fileStep1 2>/dev/null
rm ./tmp* 2>/dev/null
rm $fileStep2 2>/dev/null

# Блок while нужен на случай, когда в логах нет событий на момент interval минут назад. В таком случае интервал уменьшается до тех пор, пока не найдутся события
while ! { grep "^$prevDate" $MailLogFile > /dev/null; };
do
	if [ "$interval" -eq 0 ]
	then
		break
	fi
        ((interval--))
        prevDate=$(date -d "$interval minutes ago" +'%b %_d %H:%M')
done
# Выделяем диапозон событий из лога в отдельный файл для более быстрого поиска
sed -n "/$prevDate/,\$p" $MailLogFile >> $fileStep1 
# следующая строка нужна для диагностики, на функционал не влияет
#cat $fileStep1 >> ./nodel_fileStep1.log

#
# STEP 2
#
echo "Enter Step 2"
curlString1="curl --request POST  --url http://46.254.18.186:8080/message_status/ --header 'content-type: application/json' --data '[{"
curlString2="}]'"
concat="},{"
# количество данных в одном запросе
max=10
# finLine накапливает команду curl и все параметры для выполнения
finLine=$curlString1
# выделяем из лога те строки, где есть факт не отправки и вынимаем уникальный идентификатор отправки. складываем во временный файл
grep -P 'status=(?!sent)' $fileStep1 | grep -Po '\b[0-9A-Z]{3,}(?=:)' | sort -u > ./tmp.tmp
counter=0
# для каждого идентификатора вытаскиваем из лога все строки отправки. из полученых строк выделяем нужные данные для отправки
# данные группируются по max штук в каждый запрос. это нужно для уменьшения кол-ва вызовов curl
for i in `cat ./tmp.tmp`;
do
        t=$(grep $i $fileStep1)
        str1=$(echo "$t" | grep -m1 -Po 'message-id=<[^>]+>' | sed 's/message-id=</"id": "/' | sed 's/>/",/')
        str2=$(echo "$t" | grep -m1 'said' | sed -r 's/.*said: ([0-9]+)/"errorCode": \1 <anchor>/ ; s/<anchor>/, "errorMessage": "/ ; s/$/"/')
        if [[ -n "$str1" && -n "$str2" ]]; then
                if [ "$counter" -eq "$max"  ]; then
			finLine=$finLine$curlString2
                        echo $finLine >> $fileStep2
                        finLine=$curlString1
                        counter=0
		fi
		if [ "$counter" -gt 0 ]; then
                        finLine=$finLine$concat
                fi
		finLine=$finLine$str1$str2
                ((counter++))
        fi
done
finLine=$finLine$curlString2
# если данные для отправки нашлись - формируем файл с данными
if [ "$finLine" != "$curlString1$curlString2" ] ; then
	echo $finLine >> $fileStep2
fi
#
# STEP 3
#
echo "Enter Step 3"
# делаем вызовы curl из файла
if [ -f $fileStep2 ]; then
	#cat $fileStep2 >> ./nodel_fileStep2.log
	IFS=$'\n'
	for i in $(cat $fileStep2 );
	do
        	sh -c "$i"
	done
fi
