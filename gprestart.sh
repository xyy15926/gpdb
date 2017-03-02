#!/bin/bash
#使用 -r 参数 为快速 init, 自动创建testDB数据库。（包含退出现有gp程序和删除临时文件)
#使用 -c 参数 在修改过 mdw 代码且 make && make install 通过后，执行本脚本分发二进制包到所有slave节点重新init。自动创建testDB数据库。
#-r -c 参数不能混用, 请确认 pg的安装路径以及configure文件中的端口号 和脚本中的相符合，否则请修改后再运行。
#脚本默认打开了日志的 DUBUG 级别，同时为了方便测试哈希，关闭了嵌套链接


if [ x$1 != x ] && [ "$*"  == "-r" ]; then
	gpstop -a
	gpssh -f /home/gpadmin/conf/hostlist -v -e 'ps x|grep -E '\''postgres|psql'\'' |grep -v "grep"|awk '\''{print "kill -9",$1}'\''|sh; (lsof -i:40000 ; lsof -i:40001 ;lsof -i:40002 ;lsof -i:40003 ; lsof -i:2345)|grep -v "PID"|awk '\''{print "kill -9",$2}'\''|sh' # kill pg on-run for each seg by killing PID and port ocvupation
	gpssh -f /home/gpadmin/conf/hostlist -v -e ' rm -rf /home/gpadmin/gpdata/gp*/*;rm -rf /tmp/.s.PGS*'
	gpinitsystem -c ~/conf/gpinitsystem_config -a				## re-inint
	echo "host all all 127.0.0.1/32 trust" >> $MASTER_DATA_DIRECTORY/pg_hba.conf  #For tcp-h
	gpconfig -c enable_nestloop -v off       #脚本默认打开了日志的 DUBUG 级别，同时为了方便测试哈希，关闭了嵌套链接
	echo "client_min_messages = debug5" >> $MASTER_DATA_DIRECTORY/postgresql.conf
	echo "log_min_messages = debug5" >> $MASTER_DATA_DIRECTORY/postgresql.conf
	echo "log_connections = on" >> $MASTER_DATA_DIRECTORY/postgresql.conf
	echo -e "log_min_error_statement = debug5\nlog_disconnections = on\nlog_duration = on\ndebug_print_slice_table = on\ndebug_print_plan = on" >> $MASTER_DATA_DIRECTORY/postgresql.conf
	gpssh -f /home/gpadmin/conf/seg_hosts -v -e 'echo -e "client_min_messages = debug5\nlog_min_messages = debug5\nlog_connections = on" |tee -a /home/gpadmin/gpdata/gpd*/*/postgresql.conf'
	gpssh -f /home/gpadmin/conf/seg_hosts -v -e 'echo -e "log_min_error_statement = debug5\nlog_disconnections = on\nlog_duration = on\ndebug_print_slice_table = on\ndebug_print_plan = on" |tee -a  /home/gpadmin/gpdata/gpd*/*/postgresql.conf'
	gpstop -u
  	createdb -E utf-8 testDB
	rm -rf /home/gpadmin/gpdata/materi*
	echo "Just re-inited! We have created testDB for you, you can use 'psql' to enter it now!"
elif [ x$1 != x ] && [ "$*"  == "-c" ]; then
	gpstop -a
	cd /home/gpadmin
	gtar -cvf /home/gpadmin/gp.tar  gpdb                                  #make .tar file to dispatch
	gpscp -f /home/gpadmin/conf/seg_hosts /home/gpadmin/gp.tar =:/home/gpadmin
	gpssh -f /home/gpadmin/conf/seg_hosts -v -e 'ps x|grep -E '\''postgres|psql'\'' |grep -v "grep"|awk '\''{print "kill -9",$1}'\''|sh; (lsof -i:40000 ; lsof -i:40001 ;lsof -i:40002 ;lsof -i:40003 ;lsof -i:2345)|grep -v "PID"|awk '\''{print "kill -9",$2}'\''|sh '   #dispatch and kill pg on-run for slave-segs
	gpssh -f /home/gpadmin/conf/seg_hosts -v -e 'rm -rf /home/gpadmin/gpdb;rm -rf /home/gpadmin/gpdata/gp*/*;gtar -xvf  /home/gpadmin/gp.tar;rm -rf /tmp/.s.PGS*;rm -rf /home/gpadmin/gp.tar'   #dispatch and kill pg on-run for slave-segs
	ps x|grep -E 'postgres|psql' |grep -v "grep"|awk '{print "kill -9",$1}'|sh
	lsof -i :2345|grep -v "PID"|awk '{print "kill -9",$2}'|sh
	rm -rf /home/gpadmin/gpdata/gp*/*
	rm -rf /tmp/.s.PGS*
	rm -rf /home/gpadmin/gp.tar
	gpinitsystem -c ~/conf/gpinitsystem_config -a
	echo "host all all 127.0.0.1/32 trust" >> $MASTER_DATA_DIRECTORY/pg_hba.conf
	gpconfig -c enable_nestloop -v off
	echo "client_min_messages = debug5" >> $MASTER_DATA_DIRECTORY/postgresql.conf
	echo "log_min_messages = debug5" >> $MASTER_DATA_DIRECTORY/postgresql.conf
	echo "log_connections = on" >> $MASTER_DATA_DIRECTORY/postgresql.conf
	echo -e "log_min_error_statement = debug5\nlog_disconnections = on\nlog_duration = on\ndebug_print_slice_table = on\ndebug_print_plan = on" >> $MASTER_DATA_DIRECTORY/postgresql.conf
	gpssh -f /home/gpadmin/conf/seg_hosts -v -e 'echo -e "client_min_messages = debug5\nlog_min_messages = debug5\nlog_connections = on" |tee -a  /home/gpadmin/gpdata/gpd*/*/postgresql.conf'
	gpssh -f /home/gpadmin/conf/seg_hosts -v -e 'echo -e "log_min_error_statement = debug5\nlog_disconnections = on\nlog_duration = on\ndebug_print_slice_table = on\ndebug_print_plan = on" |tee -a /home/gpadmin/gpdata/gpd*/*/postgresql.conf'
	gpstop -u
	createdb -E utf-8 testDB
	rm -rf /home/gpadmin/gpdata/materi*
	echo "Evering thing is new. We have created testDB for you, you can use 'psql' to enter it now!"
else
	echo "Please re-run this .sh file with arguments."
	echo "  XXX -r means JUST RE-INIT"
	echo "  XXX -c means DISPATCH and RE-INIT # make sure you have make install in Mdw"
fi
