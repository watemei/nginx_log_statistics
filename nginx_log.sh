#!/bin/bash

function clear_file
{
    printf "">"$domain/tmp_file/filtered_api"
    printf "">"$domain/tmp_file/filtered_log"
}
function init_file
{
    if ! test -d $domain
    then
        sudo mkdir $domain
        sudo chmod 777 $domain
    fi
    if ! test -d "$domain/tmp_file"
    then
        sudo mkdir "$domain/tmp_file"
        sudo chmod 777 "$domain/tmp_file"
    fi
    if ! test -f "$domain/tmp_file/filtered_log"
    then
        sudo touch "$domain/tmp_file/filtered_log"
        sudo chmod 666 "$domain/tmp_file/filtered_log"
    fi
    if ! test -f "$domain/tmp_file/filtered_api"
    then
        sudo touch "$domain/tmp_file/filtered_api"
        sudo chmod 666 "$domain/tmp_file/filtered_api"
    fi
    if ! test -d "$domain/out_file"
    then
        sudo mkdir "$domain/out_file"
        sudo chmod 777 "$domain/out_file"
    fi
}
function log_filter
{
    awk '{if($8~/HTTP\/1\.[1|0]/ && $(NF)~/.\..../ && $4~/.*....:..:..:../ && substr($4,length($4)-4,2)+0>minute-interval-1 && substr($4,length($4)-4,2)+0<minute+1) { sub(/.*\//,"",$4);sub(/?.*/,"",$7);print $4 " " $7 " " $(NF) } }' minute=$m interval=$interval $nginxlog>> "$domain/tmp_file/filtered_log"
}
function api_filter
{
    if [ "$api" == "*" ]
    then
        cp "$domain/tmp_file/filtered_log" "$domain/tmp_file/filtered_api"
        return
    fi
    fgrep -h "$api" "$domain/tmp_file/filtered_log" >> "$domain/tmp_file/filtered_api"
}
function output_api_message
{
    awk '{

        $3*=1000

        total_num+=1
        total_defer+=$3
        if(total_max<$3)
            total_max=$3
        if(total_min>$3||total_num==1)
            total_min=$3
        if($3<=20)
            total_0_20+=1
        if($3>20 && $3<=50)
            total_20_50+=1
        if($3>50 && $3<=200)
            total_50_200+=1
        if($3>200 && $3<=500)
            total_200_500+=1
        if($3>500 && $3<=1000)
            total_500_1000+=1
        if($3>1000 && $3<=3000)
            total_1000_3000+=1


        api_num[$2]+=1
        api_defer[$2]+=$3
        if(api_max[$2]<$3)
            api_max[$2]=$3
        if(api_min[$2]>$3||api_num[$2]==1)
            api_min[$2]=$3
        if($3<=20)
            time_0_20[$2]+=1
        if($3>20 && $3<=50)
            time_20_50[$2]+=1
        if($3>50 && $3<=200)
            time_50_200[$2]+=1
        if($3>200 && $3<=500)
            time_200_500[$2]+=1
        if($3>500 && $3<=1000)
            time_500_1000[$2]+=1
        if($3>1000 && $3<=3000)
            time_1000_3000[$2]+=1

        if($3>limit)
        {
            alert[$2]+=1
        }
    }
    END{

        for(i in alert)
        {
            if(alert[i]>frequency)
            {
            printf ("\n========================================\033[41;33m Alert Message \033[0m========================================================\n\n")
            printf ("API                     :\t%s\n",                 i)
            printf ("Illegal Querys          :\t%d(querys)\n",  alert[i])
            printf ("Tolerable Illegal Querys:\t%d(querys)\n", frequency)
            printf ("Tolerable Max Latency   :\t%d(ms)\n",         limit)
            printf ("\nBecause %d>%d, alert message is sent ! Please handle in time, or ignore if not important !\n", alert[i],frequency)
            printf ("\n________________________________________________________________________________________________________________")
            printf "\n\n"
            }
        }
        for(i in api_num)
        {
            printf ("\n========================================\033[40;33m Api   Message \033[0m========================================================\n\n")
            printf ("API          :\t%s\n",       i)
            printf ("Total Request:\t%d\n",       api_num[i])
            printf ("Average time :\t%.2f(ms)\n", api_defer[i]/api_num[i])
            printf ("Max time     :\t%.2f(ms)\n", api_max[i])
            printf ("Min time     :\t%.2f(ms)\n", api_min[i])
            printf ("Time inteval :\t%-10s \t %-10s \t %-10s \t %-10s \t %-10s \t %-10s \n", "0-20(ms)", "20-50(ms)",  "50-200(ms)",  "200-500(ms)",  "500-1000(ms)",  "1000-3000(ms)")
            printf ("Request   num:\t%-10s \t %-10s \t %-10s \t %-10s \t %-10s \t %-10s \n",time_0_20[i],time_20_50[i],time_50_200[i],time_200_500[i],time_500_1000[i],time_1000_3000[i])
            p1=time_0_20[i]     *100/api_num[i]
            p2=time_20_50[i]    *100/api_num[i]
            p3=time_50_200[i]   *100/api_num[i]
            p4=time_200_500[i]  *100/api_num[i]
            p5=time_500_1000[i] *100/api_num[i]
            p6=time_1000_3000[i]*100/api_num[i]
            printf ("Request ratio:\t%-5.2f%-5s \t %-5.2f%-5s \t %-5.2f%-5s \t %-5.2f%-5s \t %-5.2f%-5s \t %-5.2f%-5s \n",p1,"(%)",p2,"(%)",p3,"(%)",p4,"(%)",p5,"(%)",p6,"(%)")
            printf ("\n________________________________________________________________________________________________________________")
            printf "\n\n"
        }
        if(total_num>0)
        {
            printf ("\n====================================\033[40;33m All Api Statistic Message \033[0m================================================\n\n")
            printf ("Total Request:\t%d\n",       total_num)
            printf ("Average time :\t%.2f(ms)\n", total_defer/total_num)
            printf ("Max time     :\t%.2f(ms)\n", total_max)
            printf ("Min time     :\t%.2f(ms)\n", total_min)
            printf ("Time inteval :\t%-10s \t %-10s \t %-10s \t %-10s \t %-10s \t %-10s \n","0-20(ms)","20-50(ms)","50-200(ms)","200-500(ms)","500-1000(ms)","1000-3000(ms)")
            printf ("Request num  :\t%-10s \t %-10s \t %-10s \t %-10s \t %-10s \t %-10s \n",total_0_20,total_20_50,total_50_200,total_200_500,total_500_1000,total_1000_3000)
            p1=total_0_20     *100/total_num
            p2=total_20_50    *100/total_num
            p3=total_50_200   *100/total_num
            p4=total_200_500  *100/total_num
            p5=total_500_1000 *100/total_num
            p6=total_1000_3000*100/total_num
            printf ("Request ratio:\t%-5.2f%-5s \t %-5.2f%-5s \t %-5.2f%-5s \t %-5.2f%-5s \t %-5.2f%-5s \t %-5.2f%-5s \n",p1,"(%)",p2,"(%)",p3,"(%)",p4,"(%)",p5,"(%)",p6,"(%)")
            printf ("\n________________________________________________________________________________________________________________")
            printf "\n\n"
        }

    }' frequency=$frequency limit=$limit "$domain/tmp_file/filtered_api"
}
function example
{
    sudo rm -rf /data/logs/nginx/name.wallet.com
    #--domain name.wallet.com --api add_money --interval 10 --limit 10 --frequency 0 --timetag '2022-02-02 02:02'
    sudo mkdir /data/logs/nginx/name.wallet.com                         #创建nginx域名的目录
    sudo mkdir /data/logs/nginx/name.wallet.com/202202                  #创建月份目录
    sudo mkdir /data/logs/nginx/name.wallet.com/202202/02               #创建日期目录
    sudo touch /data/logs/nginx/name.wallet.com/202202/02/access_02.log    #创建日志文件
    file='/data/logs/nginx/name.wallet.com/202202/02/access_02.log'
    sudo sh -c "echo  '- - - [02/Feb/2022:02:32:02 +0800] GET name.wallet.com/add_money?name=name&money=100 HTTP/1.1 403 162 - - - - 80 0.010'>>$file"
    sudo sh -c "echo  '- - - [02/Feb/2022:02:32:02 +0800] GET name.wallet.com/add_money?name=name&money=100 HTTP/1.1 403 162 - - - - 80 0.020'>>$file"
    sudo sh -c "echo  '- - - [02/Feb/2022:02:32:02 +0800] GET name.wallet.com/add_money?name=name&money=100 HTTP/1.1 403 162 - - - - 80 0.030'>>$file"
    sudo sh -c "echo  '- - - [02/Feb/2022:02:32:02 +0800] GET name.wallet.com/dcr_money?name=name&money=100 HTTP/1.1 403 162 - - - - 80 0.001'>>$file"
    sudo sh -c "echo  '- - - [02/Feb/2022:02:32:02 +0800] GET name.wallet.com/dcr_money?name=name&money=100 HTTP/1.1 403 162 - - - - 80 0.002'>>$file"
    sudo sh -c "echo  '- - - [02/Feb/2022:02:32:02 +0800] GET name.wallet.com/dcr_money?name=name&money=100 HTTP/1.1 403 162 - - - - 80 0.003'>>$file"
    sudo sh -c "echo  '- - - [02/Feb/2022:02:32:02 +0800] GET name.wallet.com/get_money?name=name&money=100 HTTP/1.1 403 162 - - - - 80 0.000'>>$file"
    sudo sh -c "echo  '- - - [02/Feb/2022:02:32:02 +0800] GET name.wallet.com/get_money?name=name&money=100 HTTP/1.1 403 162 - - - - 80 0.000'>>$file"
    sudo sh -c "echo  '- - - [02/Feb/2022:02:02:02 +0800] GET name.wallet.com/get_money?name=name&money=100 HTTP/1.1 403 162 - - - - 80 0.000'>>$file"
    sudo sh -c "echo  '- - - [02/Feb/2022:02:32:02 +0800] GET name.wallet.com/get_uinfo?name=name&usrid=100 HTTP/1.1 403 162 - - - - 80 0.000'>>$file"
    printf "\n"
    echo '步骤一：cat /data/logs/nginx/name.wallet.com/202202/02/access_02.log'
    printf "\n"
    cat $file
    printf "\n"
    echo "步骤二：./nginx_log.sh --domain name.wallet.com --api money --timetag '2022-02-02 02:59' --interval 30 --limit 2 --frequency 0 --switch on --mail name1@abc.cn,name1@abc.cn"
    printf "\n"
    ./nginx_log.sh --domain name.wallet.com --api money --timetag '2022-02-02 02:59' --interval 30 --limit 2 --frequency 0
    printf "\n"
}
function helps
{
    #--domain name.wallet.com --api add_money --interval 10 --limit 10 --frequency 0 --timetag '2022-02-02 02:02'
    printf "\n"
    printf "\t ______________________________________________________________________________________________________________________________\n"
    printf "\t|                |        |        |                        |                                                  |               |\n"
    printf "\t|         参数   |  含义  |  选项  |         示列           |                     说明                         |       默认    |\n"
    printf "\t|________________|________|________|________________________|__________________________________________________|_______________|\n"
    printf "\t|                |        |        |                        |                                                  |               |\n"
    printf "\t| --domain    -d |  域名  |  必选  | -d  abc.com            | 查询/data/logs/nginx/ abc.com /目录下的日志      |               |\n"
    printf "\t| --timetag   -t |  时刻  |  可选  | -t  '2022-02-02 02:02' | 查询  该  时刻以前的日志，精度为分钟，注意双引号 |    当前时刻   |\n"
    printf "\t| --interval  -i |  间隔  |  可选  | -i  10                 | 查询以前十分钟的日志                             |    1(分钟)    |\n"
    printf "\t| --api       -a |  接口  |  可选  | -a  list               | 查询含有list子串的接口                           |    所有接口   |\n"
    printf "\t| --limit     -l |  阈值  |  可选  | -l  500                | 延迟时间超过500毫秒的日志会被关注                |    1000(毫秒) |\n"
    printf "\t| --frequency -f |  频数  |  可选  | -f  2                  | 如果某个接口有2条请求的延迟超过阈值，报警        |    1(条)      |\n"
    printf "\t| --mail      -m |  邮件  |  可选  | -f  name@domain.cn     | 将运行结果以邮件的形式发送,多个收件人逗号隔开    |               |\n"
    printf "\t| --switch    -s |  开关  |  可选  | -s  on                 | 如果打开开关，那么有报警时发邮件                 |    off        |\n"
    printf "\t| --help      -h |  帮助  |  可选  | -h                     |                                                  |               |\n"
    printf "\t|________________|________|________|________________________|__________________________________________________|_______________|\n"
    printf "\t|                                                                                                                              |\n"
    printf "\t| 举例：./log.sh -d abc.com        : 统计 '前1分钟' '所有接口' 信息,如果某个接口超过 '1' 条请求大于 '1000' 毫秒，就报警        |\n"
    printf "\t| 举例：./log.sh -d abc.com -i 6   :      '前6分钟'                                                                            |\n"
    printf "\t| 举例：./log.sh -d abc.com -a list:                'list接口'                                                                 |\n"
    printf "\t| 举例：./log.sh -d abc.com -f 6   :                                                 '6'                                       |\n"
    printf "\t| 举例：./log.sh -d abc.com -l 3000:                                                                '3000'                     |\n"
    printf "\t|______________________________________________________________________________________________________________________________|\n"
    printf "\t\n"

    i=0
    while [ 1 ]
    do
         i=$[i+1]
         if [ "$i" -gt "5" ]
         then
             break
         fi
         read -p "下一条提示：[y/n]:" -t 10000 -s yes
         if [ "$yes" == 'n' ]
         then
             break
         fi
         case "$i" in
             1)
                 printf "\n"
                 printf "\t\t\t __________________________________________________________________________________\n"
                 printf "\t\t\t|                                                                                  |\n"
                 printf "\t\t\t|                                                                                  |\n"
                 printf "\t\t\t|  如果在crontab中运行，可以设置运行周期为 n 分钟，同时每次都处理前 n 分钟的日志   |\n"
                 printf "\t\t\t|                                                                                  |\n"
                 printf "\t\t\t|  设置参数 --interval n ,同时 --timetag  默认当前时刻,即crontab运行时刻           |\n"
                 printf "\t\t\t|                                                                                  |\n"
                 printf "\t\t\t|__________________________________________________________________________________|\n"
                 ;;
             2)
                 printf "\n"
                 printf "\t\t\t __________________________________________________________________________________\n"
                 printf "\t\t\t|                                                                                  |\n"
                 printf "\t\t\t|                                                                                  |\n"
                 printf "\t\t\t|  参数--limit 和 --frequency 专门用于设置报警条件. 若limit阈值较小，对请求延迟较  |\n"
                 printf "\t\t\t|                                                                                  |\n"
                 printf "\t\t\t|  敏感; 若--requency较小,能容忍的延迟次数较少; 若不想报警,只想查看接口统计信息,将 |\n"
                 printf "\t\t\t|                                                                                  |\n"
                 printf "\t\t\t|  任意一个参数设置为无限大即可                                                    |\n"
                 printf "\t\t\t|                                                                                  |\n"
                 printf "\t\t\t|__________________________________________________________________________________|\n"
                 ;;
             3)
                 printf "\n"
                 printf "\t\t\t __________________________________________________________________________________\n"
                 printf "\t\t\t|                                                                                  |\n"
                 printf "\t\t\t|                                                                                  |\n"
                 printf "\t\t\t|  参数--api 用于过滤接口，只要接口含有对应子串，就能被过滤。比如 --api get, 那么  |\n"
                 printf "\t\t\t|                                                                                  |\n"
                 printf "\t\t\t|  这些接口将被统计:get get_info time_get time_get_info,如果只想查看get接口的信息  |\n"
                 printf "\t\t\t|                                                                                  |\n"
                 printf "\t\t\t|  请这样使用 --api ' get ' ，注意get前后有空格，并用引号扩起来                    |\n"
                 printf "\t\t\t|                                                                                  |\n"
                 printf "\t\t\t|__________________________________________________________________________________|\n"
                 ;;
             4)
                 printf "\n"
                 printf "\t\t\t __________________________________________________________________________________\n"
                 printf "\t\t\t|                                                                                  |\n"
                 printf "\t\t\t|                                                                                  |\n"
                 printf "\t\t\t|  执行流程是这样的:                                                               |\n"
                 printf "\t\t\t|                                                                                  |\n"
                 printf "\t\t\t|  (1)定位nginx某个日志文件access_hour.log                                         |\n"
                 printf "\t\t\t|                                                                                  |\n"
                 printf "\t\t\t|  (2)根据timetag和interval过滤某个时间范围内日志，将结果保存在filtered_log        |\n"
                 printf "\t\t\t|                                                                                  |\n"
                 printf "\t\t\t|  (3)过滤出目标接口，保存在filtered_api文件                                       |\n"
                 printf "\t\t\t|                                                                                  |\n"
                 printf "\t\t\t|  (4)计算每个接口的: 访问次数、平均延迟、最大延迟、最小延迟、延迟分布、报警       |\n"
                 printf "\t\t\t|                                                                                  |\n"
                 printf "\t\t\t|  提示:                                                                           |\n"
                 printf "\t\t\t|       每次处理的是一个access_hour.log日志文件。如果crontab设置按小时统计日志     |\n"
                 printf "\t\t\t|                                                                                  |\n"
                 printf "\t\t\t|       并且在每小时的第0分钟运行脚本，那么将读取不到日志，不管--interval设置      |\n"
                 printf "\t\t\t|                                                                                  |\n"
                 printf "\t\t\t|       多大，因为只处理当前小时的access.log；所以，若按小时统计日志,可以设置      |\n"
                 printf "\t\t\t|                                                                                  |\n"
                 printf "\t\t\t|       每小时的第59分钟运行脚本                                                   |\n"
                 printf "\t\t\t|                                                                                  |\n"
                 printf "\t\t\t|       当nginx日志格式改变的时候，可以更改过滤脚本，只要filtered_log和            |\n"
                 printf "\t\t\t|                                                                                  |\n"
                 printf "\t\t\t|       filtered_api文件格式不变即可                                               |\n"
                 printf "\t\t\t|                                                                                  |\n"
                 printf "\t\t\t|__________________________________________________________________________________|\n"
                 printf "\n"
                 ;;
             5)
                 printf "\n"
                 printf "\t\t\t __________________________________________________________________________________\n"
                 printf "\t\t\t|                                                                                  |\n"
                 printf "\t\t\t|                                                                                  |\n"
                 printf "\t\t\t|  开发机测试数据:                                                                 |\n"
                 printf "\t\t\t|                                                                                  |\n"
                 printf "\t\t\t|  (1)   1    万条 日志，耗时  1   秒                                              |\n"
                 printf "\t\t\t|                                                                                  |\n"
                 printf "\t\t\t|  (2)   10   万条 日志，耗时  5   秒                                              |\n"
                 printf "\t\t\t|                                                                                  |\n"
                 printf "\t\t\t|  (3)   100  万条 日志，耗时  30  秒                                              |\n"
                 printf "\t\t\t|                                                                                  |\n"
                 printf "\t\t\t|  所以:                                                                           |\n"
                 printf "\t\t\t|                                                                                  |\n"
                 printf "\t\t\t|       当数据量较大时，建议crontab周期设置大些                                    |\n"
                 printf "\t\t\t|                                                                                  |\n"
                 printf "\t\t\t|       比如，以上面测试为准，每分钟日志量1万条， crontab 周期为 1 分钟，那么      |\n"
                 printf "\t\t\t|                                                                                  |\n"
                 printf "\t\t\t|       前10分钟产生日志10万条，第11分钟用于计算日志的时间为5 秒，占5/60=8.3(%%)    |\n"
                 printf "\t\t\t|                                                                                  |\n"
                 printf "\t\t\t|       前58分钟产生日志58万条，第59分钟用于计算日志的时间为18秒，占18/60=30(%%)    |\n"
                 printf "\t\t\t|                                                                                  |\n"
                 printf "\t\t\t|       一小时内用于统计日志的时间约为：(1+18)/2*60=570 秒  占                     |\n"
                 printf "\t\t\t|                                                                                  |\n"
                 printf "\t\t\t|                                    570/3600=16(%%)                                |\n"
                 printf "\t\t\t|                                                                                  |\n"
                 printf "\t\t\t|       同样，以上面测试为准，每分钟日志量1万条， crontab 周期为 1 小时，那么      |\n"
                 printf "\t\t\t|                                                                                  |\n"
                 printf "\t\t\t|       只有第59分钟计算日志，时间为18秒，占                                       |\n"
                 printf "\t\t\t|                                                                                  |\n"
                 printf "\t\t\t|                                    18/3600=0.5(%%)                                |\n"
                 printf "\t\t\t|                                                                                  |\n"
                 printf "\t\t\t|__________________________________________________________________________________|\n"
                 printf "\n"
                 ;;
         esac
     done

     read -p "运行范例：[y/n]:" -t 10000 -s yes
     if [ "$yes" == 'n' ]
     then
         printf "\n"
         exit
     fi
     printf "\n"

     example
}
function sendmail
{
    for to in ${maillist[@]}
    do
        ipadr=`ifconfig  -a| grep 'inet addr:'| grep -v '127.0.0.1' | cut -d: -f2 | awk '{ print $1}'`
        from_name="alert@nginx_log"
        email_content="$filepath"
        email_subject="service is danger :   `pwd`/$filepath    on    $ipadr"
        echo -e "To: \"${email_title}\" <${to}>\nFrom: \"${from_name}\" <${from}>\nSubject:${email_subject}\n\n`cat ${email_content}`"|/usr/sbin/sendmail -t
    done
}
    if [ "$1" == "" ]
    then
        helps
        exit
    fi
    while [ "$1" ]
    do
        case "$1" in
            --domain)
                domain=$2
                ;;
            -d)
                domain=$2
                ;;
            --api)
                api=$2
                ;;
            -a)
                api=$2
                ;;
            --interval)
                interval=$2
                ;;
            -i)
                interval=$2
                ;;
            --limit)
                limit=$2
                ;;
            -l)
                limit=$2
                ;;
            --frequency)
                frequency=$2
                ;;
            -f)
                frequency=$2
                ;;
            --timetag)
                timetag=$2
                ;;
            -t)
                timetag=$2
                ;;
            --mail)
                mail=$2
                ;;
            -m)
                mail=$2
                ;;
            --switch)
                switch=$2
                ;;
            -s)
                switch=$2
                ;;
            --help)
                helps
                exit
                ;;
            -h)
                helps
                exit
                ;;
            *)
                helps
                exit
                ;;
        esac
        shift
        shift
    done

    if [ "$api" == "" ]
    then
        api="*"
    fi
    if [ "$interval" == "" ]
    then
        interval=1
    fi
    if [ "$limit" == "" ]
    then
        limit=1000
    fi
    if [ "$frequency" == "" ]
    then
        frequency=1
    fi
    if [ "$timetag" == "" ]
    then
        timetag=`date +"%Y-%m-%d %H:%M"`
    fi
    if [ "$switch" != "on" ]
    then
        switch='off'
    fi

  OLD_IFS="$IFS"
      IFS=" "
      arr=($timetag)
      YMD=${arr[0]}
       hm=${arr[1]}
      IFS="-"
      arr=($YMD)
        Y=${arr[0]}
        M=${arr[1]}
        D=${arr[2]}
      IFS=":"
      arr=($hm)
        h=${arr[0]}
        m=${arr[1]}
      IFS=","
 maillist=($mail)
      IFS="$OLD_IFS"
 nginxlog="/data/logs/nginx/$domain/$Y$M/$D/access_$h.log"
    if ! test -e $nginxlog
    then
        printf "\nnginx log file not exist : $nginxlog..........\n\n"
        exit 0
    fi

    init_file
    clear_file
    log_filter
    api_filter

    filepath="$domain/out_file/output_$h:$m"
    output_api_message > $filepath
    cat $filepath

    if [ "$switch" == "on" ]
    then
        sendmail
    fi
