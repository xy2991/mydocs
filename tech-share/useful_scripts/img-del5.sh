#!/bin/bash

currdate=$(date +'%Y%m%d')
[ -f ./.imgdel_tmpdate-$currdate ] && rm -f .imgdel_tmpdate-$currdate
[ -f ./.img_tmpdate-$currdate ] && rm -f .img_tmpdate-$currdate
docker images > .img_tmpdate-$currdate
if [ $# -eq 1 ];then
    thread=$1
else
    thread=60
fi

function pre(){
    round_num=$(cat .img_tmpdate-$currdate|sed -n '2,$p'|awk '{print $1}'|sort|uniq -c|wc -l)
    echo -e '\n############### Redandent images ####################\n'
    for (( c=1; c<=$round_num; c++ ));do
        img_num=$(cat .img_tmpdate-$currdate|sed -n '2,$p'|awk '{print $1}'|sort|uniq -c|awk '{print $1}'|sed -n "${c}p")
        img_name=$(cat .img_tmpdate-$currdate|sed -n '2,$p'|awk '{print $1}'|sort|uniq -c|awk '{print $2}'|sed -n "${c}p")
        if [ "$img_num" -gt 2 ];then
            echo "image name: $img_name"
            echo "image number: $img_num"
			#cat .img_tmpdate-$currdate |grep ${img_name}|sed -n '3,$p'|awk '{print $3}' >> imgdel_tmpdate
            cat .img_tmpdate-$currdate |grep ${img_name}|sed -n '3,$p' >> .imgdel_tmpdate-$currdate
        fi
    done
    echo -e '\n################################### Detail info of deleting images ###############################################\n'
    if [ -f .imgdel_tmpdate-$currdate ];then
        cat .imgdel_tmpdate-$currdate
    else
        echo "There's no redundant images.";exit 0
    fi
    echo -e '\n'
}

function del(){
#	cat .imgdel_tmpdate-$currdate|awk '{print $3}'|uniq|xargs docker rmi -f
    docker rmi -f $1
}

function just() {
    read -t 60 -p "Are you sure to delete these redandent images,after deletting,there will be 2 of these kind images remaining[y/n]:" bool
	#echo -e "\n"
	#echo "$bool"

    if [ "$bool" == "y" ];then
        echo 'deletting...'
        para_del $thread
    elif [ "$bool" == "n" ];then
        [ -f ./.img_tmpdate-$currdate ] && rm -f .img_tmpdate-$currdate
        [ -f ./.imgdel_tmpdate-$currdate ] && rm -f .imgdel_tmpdate-$currdate
        exit 0
    else
        just
    fi
}

function para_del(){
#####################################################################################
#  This is a function to delete numbers of images in same time                      #
#####################################################################################   
    cat .imgdel_tmpdate-$currdate|awk '{print $3}'|uniq > .imgdel_id-$currdate
    imgnum=$(cat .imgdel_id-$currdate|wc -l )
    mkfifo ./fifo.$$ &&  exec 233<> ./fifo.$$ && rm -f ./fifo.$$
    for ((i=0; i<$1; i++)); do
        echo "init time add $i" >&233
    done
	
    for((i=1; i<=$imgnum; i++)); do
        read -u 233   # read from mkfifo file
        {   # REPLY is var for read
            del_id=$(sed -n "${i}p" .imgdel_id-$currdate)
            del ${del_id}   
            echo >&233 # write to $ff_file
        } & # & to backgroud each process in {}
    done
    wait    # wait all con-current cmd in { } been running over
}

################################################main###############################################
pre
just

[ -f ./.img_tmpdate-$currdate ] && rm -f .img_tmpdate-$currdate
[ -f ./.imgdel_tmpdate-$currdate ] && rm -f .imgdel_tmpdate-$currdate
[ -f ./.imgdel_id-$currdate ] && rm -f .imgdel_id-$currdate
