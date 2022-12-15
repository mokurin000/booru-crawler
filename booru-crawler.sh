#!/usr/bin/env bash

# leave your proxy setting here
http_proxy=127.0.0.1:7890
https_proxy=127.0.0.1:7890

# set download thread for aria2
aria2_thread=1

temp0=`mktemp -td dir.XXXXXXXX`
cd $temp0
function set_booru() {
	booru=`kdialog --menu "Please select a site." 1 Danbooru 2 Konachan 3 Yande.re 2>/dev/null`
	if [ x$booru != x ]
	then	case $booru in
		1)
		booru=danbooru.donmai.us/posts
		;;
		2)
		booru=konachan.net/post
		;;
		3)
		booru=yande.re/post
		;;
		esac
	else set_booru
	fi
}

function save_file() {
	path="`kdialog --getsavefilename $HOME "*.txt" 2>/dev/null`"
	if [ x"${path}" = x ]
	then save_file
	fi
}

function search_tags() {
	if tags=`kdialog --inputbox "Please type keywords of one tag" 2>/dev/null`
	then if [ x = x"${tags}" ]
	     then search_tags
	     fi
	fi

	if [ x != x"${tags}" ]
	then
		tags_box=`mktemp -t temp.XXXXXXXX`

		echo Konachan: >> ${tags_box}

		max_tags=`wget https://konachan.net/tag?name="${tags}" -o /dev/null -O -|grep next_page|sed -s 's/&amp;type=">/\n/g ; s/</\n/g ; s/">/\n/g'|sed -n 29p`

		if [ x$max_tags != x ]
		then	page_tags=0
			until [ $page_tags = $max_tags ]
			do	page_tags=$((page_tags+1))
				echo https://konachan.net/tag.json?name="${tags}"\&page\=$page_tags >> tags
			done
			aria2c -i tags -j ${aria2_thread} --http-proxy=$http_proxy --https-proxy=$https_proxy
			cat tag.*|sed 's/,/\n/g'|grep \"name|sed 's/"name":"//g;s/"//g' >> ${tags_box}
		else
			wget https://konachan.net/tag.json?name="${tags}" -o /dev/null -O -|sed 's/,/\n/g'|grep \"name|sed 's/"name":"//g;s/"//g' >> ${tags_box}
		fi
		rm tag*

		echo >> ${tags_box}
		echo Yande.re: >> ${tags_box}

		max_tags=`wget https://yande.re/tag?name="${tags}" -o /dev/null -O -|grep next_page|sed -s 's/&amp;type=">/\n/g ; s/</\n/g ; s/">/\n/g'|sed -n 29p`

		if [ x$max_tags != x ]
		then	page_tags=0
			until [ $page_tags = $max_tags ]
			do	page_tags=$((page_tags+1))
				echo https://yande.re/tag.json?name="${tags}"\&page\=$page_tags >> tags
			done
			aria2c -i tags -j ${aria2_thread} --http-proxy=$http_proxy --https-proxy=$https_proxy
			cat tag.*|sed 's/,/\n/g'|grep \"name|sed 's/"name":"//g;s/"//g' >> ${tags_box}
		else
			wget https://yande.re/tag.json?name="${tags}" -o /dev/null -O -|sed 's/,/\n/g'|grep \"name|sed 's/"name":"//g;s/"//g' >> ${tags_box}
		fi
		rm tag*

		echo >> ${tags_box}
		echo Danbooru: >> ${tags_box}
		wget 'https://danbooru.donmai.us/tags.json?commit=Search&search[hide_empty]=yes&search[name_matches]=*'"${tags}"'*&search[order]=date&utf8=%E2%9C%93' -o /dev/null -O -|
			sed 's/,/\n/g'|grep \"name|sed 's/"name":"//g;s/"//g' >> ${tags_box}
		rm tag*
		kdialog --textbox $tags_box 450 675 2>/dev/null &
		if kdialog --yesno "Would you like to search the next tag?" 2>/dev/null
		then	tags=
			search_tags
		fi
	fi
}

search_tags
set_booru

tags=`kdialog --inputbox "Please type tag(s), 'and' use '+', 'except' use '+-'" 2>/dev/null`
if [ $booru != danbooru.donmai.us/posts ]
then 	wget https://$booru\?tags\="${tags}"\&limit\=1000 -o /dev/null -O - |grep pagination|sed 's/<a class="next_page"/\n/g ; s\</a>\\g ; s/">/\n/g'|tail -n 3|sed -n 1p > page
	if ! [ 0 -lt `cat page` ]
	then	 page_max=1
	else	 page_max=`cat page`
	fi
else 	page_max=`kdialog --inputbox "Please type how many page do you wish to get URLs(limited in 200pictures/page)" 2>/dev/null`
fi

page=0
while [ $page -lt $page_max ]
do 	page=$((page+1))
	echo https://$booru.json?tags="${tags}"\&page=$page\&limit\=1000 >> page_list
done

direct_links_file=`mktemp -t temp.XXXXXXXX`

kdialog --msgbox "Now getting..." 2>/dev/null &
aria2c -i page_list -j ${aria2_thread} --http-proxy=$http_proxy --https-proxy=$https_proxy
sed 's/{/\n{/g ; s/}]/}\n]/g' ${booru#*/}*|
# grep -v 'rating":"q' | #exclude the 'Questionable' pics
# grep -v 'rating":"e' | #exclude the 'Explicit' pics
# grep -v 'rating":"s' | #exclude the 'Safe' pics
sed 's/,/\n/g'|grep \"file_url|sed 's/"file_url":"//g;s/"//g' > $direct_links_file
save_file
cp $direct_links_file "${path}"
rm -rf $temp0 $temp1 $direct_links_file
