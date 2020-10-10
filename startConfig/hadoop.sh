#!/bin/sh

# 安装必要环境
sudo yum install -y epel-release
sudo yum install -y psmisc nc net-tools rsync vim lrzsz ntp libzstd openssl-static tree iotop git

# 修改主机名称
sudo hostnamectl --static set-hostname hadoop101

# 配置主机名称映射
sudo vim /etc/hosts
# 添加

sudo vim /etc/hosts
: <<EOF
192.168.1.100 hadoop100
192.168.1.101 hadoop101
192.168.1.102 hadoop102
192.168.1.103 hadoop103
192.168.1.104 hadoop104
192.168.1.105 hadoop105
192.168.1.106 hadoop106
192.168.1.107 hadoop107
EOF

# 关闭防火墙
sudo systemctl stop firewalld
sudo systemctl disable firewalld
# 创建用户
sudo useradd atguigu
sudo passwd atguigu
# 重启
reboot
# 配置atguigu用户具有root权限
vi sudo
# 修改/etc/sudoers文件，找到91行，在root下面添加一行
vim /tec/sudoers
: <<EOF
## Allow root to run any commands anywhere
root    ALL=(ALL)     ALL
atguigu   ALL=(ALL)     ALL
EOF
# 在/opt目录下创建文件夹, 修改module、software文件夹的所有者
sudo mkdir /opt/module /opt/software
sudo chown atguigu:atguigu /opt/module /opt/software
# 卸载现有JDK
rpm -qa | grep -i java | xargs -n1 sudo rpm -e --nodeps
# 解压JDK到/opt/module目录下
tar -zxvf jdk-8u212-linux-x64.tar.gz -C /opt/module/
# 配置JDK环境变量，然后重启
sudo vim /etc/profile.d/my_env.sh
echo "#JAVA_HOME
export JAVA_HOME=/opt/module/jdk1.8.0_212
export PATH=\$PATH:\$JAVA_HOME/bin
" >> /etc/profile.d/my_env.sh
# 让修改后的文件生效
source /etc/profile
java -version
# hadoop 解压
tar -zxvf hadoop-3.1.3.tar.gz -C /opt/module/
# 获取 Hadoop 安装路径， 打开 /etc/profile.d/my_env.sh 文件， 添加 Hadoop 路径
echo "##HADOOP_HOME
export HADOOP_HOME=/opt/module/hadoop-3.1.3
export PATH=\$PATH:\$HADOOP_HOME/bin
export PATH=\$PATH:\$HADOOP_HOME/sbin
" >> /etc/profile.d/my_env.sh
# 让修改后的文件生效
source /etc/profile
# etc目录全称：Editable Text Configuration

# hadoop 本地运行模式测试
makdir wcinput
cd wcinput
echo "
hadoop yarn
hadoop mapreduce
atguigu
atguigu
" >> wcinput
cd opt/module/hadoop-3.1.3
hadoop jar share/hadoop/mapreduce/hadoop-mapreduce-examples-3.1.3.jar wordcount wcinput wcoutput
cat wcoutput/part-r-00000
# 服务器文件拷贝
:<<EOF
scp -r  $pdir/$fname $user@hadoop$host:$pdir/$fname
EOF
scp -r /opt/module  root@hadoop102:/opt/module
sudo scp /etc/profile root@hadoop102:/etc/profile
sudo chown atguigu:atguigu -R /opt/module
source /etc/profile

# xsync集群分发脚本
cd /home/atguigu
vim xsync
:<<EOF
#!/bin/bash
#1. 判断参数个数
if [ $# -lt 1 ]
then
  echo Not Enough Arguement!
  exit;
fi
#2. 遍历集群所有机器
for host in hadoop102 hadoop103 hadoop104
do
  echo ====================  $host  ====================
  #3. 遍历所有目录，挨个发送
  for file in $@
  do
    #4 判断文件是否存在
    if [ -e $file ]
    then
      #5. 获取父目录
      pdir=$(cd -P $(dirname $file); pwd)
      #6. 获取当前文件的名称
      fname=$(basename $file)
      ssh $host "mkdir -p $pdir"
      rsync -av $pdir/$fname $host:$pdir
    else
      echo $file does not exists!
    fi
  done
done
EOF
# 修改脚本 xsync 具有执行权限
chmod +x xsync
# 将脚本移动到/bin中，以便全局调用
sudo mv xsync /bin/
# 测试脚本
sudo xsync /bin/xsync

# 生成公钥和私钥
ssh-keygen -t rsa
# 将公钥拷贝到要免密登录的目标机器上
ssh-copy-id hadoop102
ssh-copy-id hadoop103
ssh-copy-id hadoop104

# 更新 hadoop 下各个应用的 xml 配置文件，然后分发到各个服务器
xsync /opt/module/hadoop-3.1.3/etc/hadoop/
# 查看文件分发情况
cat /opt/module/hadoop-3.1.3/etc/hadoop/core-site.xml

# 配置集群 worker
echo "hadoop102
hadoop103
hadoop104
" >> /opt/module/hadoop-3.1.3/etc/hadoop/workers
# 分发到各个服务器
xsync /opt/module/hadoop-3.1.3/etc/hadoop/

# 第一次，启动集群
hdfs namenode -format
sbin/start-dfs.sh
sbin/start-yarn.sh

# word count 测试
# 上传文件到集群
hadoop fs -mkdir -p /user/atguigu/input
hadoop fs -put $HADOOP_HOME/wcinput/wc.input /user/atguigu/input
hadoop fs -put  /opt/software/hadoop-3.1.3.tar.gz  /
# 查看HDFS文件存储路径
pwd /opt/module/hadoop-3.1.3/data/tmp/dfs/data/current/BP-938951106-192.168.10.107-1495462844069/current/finalized/subdir0/subdir0
# 查看HDFS在磁盘存储文件内容
cat blk_1073741825
# 下载
bin/hadoop fs -get /hadoop-3.1.3.tar.gz ./
# 执行wordcount程序
hadoop jar share/hadoop/mapreduce/hadoop-mapreduce-examples-3.1.3.jar wordcount /user/atguigu/input /user/atguigu/output

# 开始、停止集群
# 服务组件逐一启动/停止
hdfs --daemon start/stop namenode/datanode/secondarynamenode
yarn --daemon start/stop  resourcemanager/nodemanager
# 整体启动/停止
start-dfs.sh/stop-dfs.sh
start-yarn.sh/stop-yarn.sh

# 配置历史服务器，分发配置
xsync $HADOOP_HOME/etc/hadoop/mapred-site.xml
# 在hadoop102启动历史服务器
mapred --daemon start historyserver
# 查看历史服务器是否启动
jps
http://hadoop102:19888/jobhistory

# 配置日志聚集，分发配置
xsync $HADOOP_HOME/etc/hadoop/yarn-site.xml

# 关闭NodeManager 、ResourceManager和HistoryServer
# 在103上执行： stop-yarn.sh
# 在102上执行： mapred --daemon stop historyserver
# 启动NodeManager 、ResourceManage、Timelineserver和HistoryServer
# 在103上执行：start-yarn.sh
# 在103上执行：yarn --daemon start timelineserver
# 在102上执行：mapred --daemon start historyserver
# 删除HDFS上已经存在的输出文件
hdfs dfs -rm -R /user/atguigu/output
# 执行WordCount程序
hadoop jar  $HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.1.3.jar wordcount /user/atguigu/input /user/atguigu/output

:<<EOF
1）时间服务器配置（必须root用户）
（1）在所有节点关闭ntp服务和自启动
sudo systemctl stop ntpd
sudo systemctl disable ntpd
（2）修改ntp配置文件
vim /etc/ntp.conf
修改内容如下
a）修改1（授权192.168.1.0-192.168.1.255网段上的所有机器可以从这台机器上查询和同步时间）
#restrict 192.168.1.0 mask 255.255.255.0 nomodify notrap
为restrict 192.168.1.0 mask 255.255.255.0 nomodify notrap
	b）修改2（集群在局域网中，不使用其他互联网上的时间）
server 0.centos.pool.ntp.org iburst
server 1.centos.pool.ntp.org iburst
server 2.centos.pool.ntp.org iburst
server 3.centos.pool.ntp.org iburst
为
#server 0.centos.pool.ntp.org iburst
#server 1.centos.pool.ntp.org iburst
#server 2.centos.pool.ntp.org iburst
#server 3.centos.pool.ntp.org iburst
c）添加3（当该节点丢失网络连接，依然可以采用本地时间作为时间服务器为集群中的其他节点提供时间同步）
server 127.127.1.0
fudge 127.127.1.0 stratum 10
（3）修改/etc/sysconfig/ntpd 文件
vim /etc/sysconfig/ntpd
增加内容如下（让硬件时间与系统时间一起同步）
SYNC_HWCLOCK=yes
（4）重新启动ntpd服务
systemctl start ntpd
（5）设置ntpd服务开机启动
systemctl enable ntpd
2）其他机器配置（必须root用户）
（1）在其他机器配置10分钟与时间服务器同步一次
crontab -e
编写定时任务如下：
*/10 * * * * /usr/sbin/ntpdate hadoop102
（2）修改任意机器时间
date -s "2017-9-11 11:11:11"
（3）十分钟后查看机器是否与时间服务器同步
date
说明：测试的时候可以将10分钟调整为1分钟，节省时间。
EOF
