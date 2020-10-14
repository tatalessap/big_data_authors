#! /bin/bash
cd /home/ubuntu
sudo apt-get update -y > /dev/null
echo "---> Update completato"
sudo apt-get upgrade -y > /dev/null
echo "---> Upgrade completato"

PUBLIC_DNS=$( curl http://169.254.169.254/latest/meta-data/public-hostname )
PEM_FILE=$( ls .ssh | grep ".pem" )

# Hadoop setup
echo "######################### Inizio installazione java e Hadoop #########################"
sudo apt-get install -y openjdk-8-jdk > /dev/null
wget -q https://www-us.apache.org/dist/hadoop/common/hadoop-2.7.7/hadoop-2.7.7.tar.gz > /dev/null
sudo tar zxf hadoop-2.7.7.tar.gz > /dev/null
sudo mv ./hadoop-2.7.7/ /home/ubuntu/hadoop
rm hadoop-2.7.7.tar.gz

echo >> /home/ubuntu/.profile
echo export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64 >> /home/ubuntu/.profile
echo export PATH='$PATH':'$JAVA_HOME'/bin >> /home/ubuntu/.profile
echo export HADOOP_HOME=/home/ubuntu/hadoop >> /home/ubuntu/.profile
echo export PATH='$PATH':/home/ubuntu/hadoop/bin >> /home/ubuntu/.profile
echo export HADOOP_CONF_DIF=/home/ubuntu/hadoop/etc/hadoop >> /home/ubuntu/.profile

source /home/ubuntu/.profile
echo "######################## Installazione di Hadoop completata ###########################"

# Aggiornamento file config della cartella .ssh
echo Host namenode >> /home/ubuntu/.ssh/config
echo HostName namenode >> /home/ubuntu/.ssh/config
echo User ubuntu >> /home/ubuntu/.ssh/config
echo IdentityFile /home/ubuntu/.ssh/$PEM_FILE >> /home/ubuntu/.ssh/config
echo >> /home/ubuntu/.ssh/config

echo Host datanode1 >> /home/ubuntu/.ssh/config
echo HostName namenode >> /home/ubuntu/.ssh/config
echo User ubuntu >> /home/ubuntu/.ssh/config
echo IdentityFile /home/ubuntu/.ssh/$PEM_FILE >> /home/ubuntu/.ssh/config
echo >> /home/ubuntu/.ssh/config

echo Host datanode2 >> /home/ubuntu/.ssh/config
echo HostName datanode1 >> /home/ubuntu/.ssh/config
echo User ubuntu >> /home/ubuntu/.ssh/config
echo IdentityFile /home/ubuntu/.ssh/$PEM_FILE >> /home/ubuntu/.ssh/config
echo >> /home/ubuntu/.ssh/config

echo Host datanode3 >> /home/ubuntu/.ssh/config
echo HostName datanode2 >> /home/ubuntu/.ssh/config
echo User ubuntu >> /home/ubuntu/.ssh/config
echo IdentityFile /home/ubuntu/.ssh/$PEM_FILE >> /home/ubuntu/.ssh/config
echo >> /home/ubuntu/.ssh/config

echo Host datanode4 >> /home/ubuntu/.ssh/config
echo HostName datanode3 >> /home/ubuntu/.ssh/config
echo User ubuntu >> /home/ubuntu/.ssh/config
echo IdentityFile /home/ubuntu/.ssh/$PEM_FILE >> /home/ubuntu/.ssh/config

# Creazione file template da modificare in seguito
echo | sudo tee -a /etc/hosts > /dev/null
echo "IP.MA.ST.ER namenode" | sudo tee -a /etc/hosts > /dev/null
echo "IP.MA.ST.ER datanode1" | sudo tee -a /etc/hosts > /dev/null
echo "IP.SL.AV.E1 datanode2" | sudo tee -a /etc/hosts > /dev/null
echo "IP.SL.AV.E2 datanode3" | sudo tee -a /etc/hosts > /dev/null

# Creazione chiavi ssh
ssh-keygen -qq -f /home/ubuntu/.ssh/id_rsa -t rsa -P ''
cat /home/ubuntu/.ssh/id_rsa.pub >> /home/ubuntu/.ssh/authorized_keys
#---> ssh datanode2 'cat >> /home/ubuntu/.ssh/authorized_keys'< /home/ubuntu/.ssh/id_rsa.pub
#---> ssh datanode3 'cat >> /home/ubuntu/.ssh/authorized_keys'< /home/ubuntu/.ssh/id_rsa.pub
#---> ssh datanode4 'cat >> /home/ubuntu/.ssh/authorized_keys'< /home/ubuntu/.ssh/id_rsa.pub

# Configurazione files Hadoop
sed -i 's+${JAVA_HOME}+/usr/lib/jvm/java-8-openjdk-amd64+g' $HADOOP_CONF_DIF/hadoop-env.sh

## Rimozione di 1 riga dalla fine del file core-site.xml e poi scrittura
sed -i '$d' $HADOOP_CONF_DIF/core-site.xml
echo "<property>" >> $HADOOP_CONF_DIF/core-site.xml
echo "<name>fs.defaultFS</name>" >> $HADOOP_CONF_DIF/core-site.xml
echo "<value>hdfs://$PUBLIC_DNS:9000</value>" >> $HADOOP_CONF_DIF/core-site.xml
echo "</property>" >> $HADOOP_CONF_DIF/core-site.xml
echo "</configuration>" >> $HADOOP_CONF_DIF/core-site.xml

## Rimozione di 4 righe dalla fine del file yarn-site.xml e poi scrittura
sed -i '$d' $HADOOP_CONF_DIF/yarn-site.xml
sed -i '$d' $HADOOP_CONF_DIF/yarn-site.xml
sed -i '$d' $HADOOP_CONF_DIF/yarn-site.xml
sed -i '$d' $HADOOP_CONF_DIF/yarn-site.xml
echo "<property>" >> $HADOOP_CONF_DIF/yarn-site.xml
echo "<name>yarn.nodemanager.aux-services</name>" >> $HADOOP_CONF_DIF/yarn-site.xml
echo "<value>mapreduce_shuffle</value>" >> $HADOOP_CONF_DIF/yarn-site.xml
echo "</property>" >> $HADOOP_CONF_DIF/yarn-site.xml
echo "<property>" >> $HADOOP_CONF_DIF/yarn-site.xml
echo "<name>yarn.resourcemanager.hostname</name>" >> $HADOOP_CONF_DIF/yarn-site.xml
echo "<value>namenode</value>" >> $HADOOP_CONF_DIF/yarn-site.xml
echo "</property>" >> $HADOOP_CONF_DIF/yarn-site.xml
echo "</configuration>" >> $HADOOP_CONF_DIF/yarn-site.xml

## Creazione dal template del file mapred-site.xml
sudo cp $HADOOP_CONF_DIF/mapred-site.xml.template $HADOOP_CONF_DIF/mapred-site.xml

## Rimozione di 2 righe dalla fine del file mapred-site.xml e poi scrittura
sudo sed -i '$d' $HADOOP_CONF_DIF/mapred-site.xml
sudo sed -i '$d' $HADOOP_CONF_DIF/mapred-site.xml
echo "<property>" | sudo tee -a $HADOOP_CONF_DIF/mapred-site.xml > /dev/null
echo "<name>mapreduce.jobtracker.address</name>" | sudo tee -a $HADOOP_CONF_DIF/mapred-site.xml > /dev/null
echo "<value>namenode:54311</value>" | sudo tee -a $HADOOP_CONF_DIF/mapred-site.xml > /dev/null
echo "</property>" | sudo tee -a $HADOOP_CONF_DIF/mapred-site.xml > /dev/null
echo "<property>" | sudo tee -a $HADOOP_CONF_DIF/mapred-site.xml > /dev/null
echo "<name>mapreduce.framework.name</name>" | sudo tee -a $HADOOP_CONF_DIF/mapred-site.xml > /dev/null
echo "<value>yarn</value>" | sudo tee -a $HADOOP_CONF_DIF/mapred-site.xml > /dev/null
echo "</property>" | sudo tee -a $HADOOP_CONF_DIF/mapred-site.xml > /dev/null
echo "</configuration>" | sudo tee -a $HADOOP_CONF_DIF/mapred-site.xml > /dev/null

# Configurazione Hadoop solo master
sudo sed -i '$d' $HADOOP_CONF_DIF/hdfs-site.xml
sudo sed -i '$d' $HADOOP_CONF_DIF/hdfs-site.xml
echo "<property>" | sudo tee -a $HADOOP_CONF_DIF/hdfs-site.xml > /dev/null
echo "<name>dfs.replication</name>" | sudo tee -a $HADOOP_CONF_DIF/hdfs-site.xml > /dev/null
echo "<value>2</value>" | sudo tee -a $HADOOP_CONF_DIF/hdfs-site.xml > /dev/null
echo "</property>" | sudo tee -a $HADOOP_CONF_DIF/hdfs-site.xml > /dev/null
echo "<property>" | sudo tee -a $HADOOP_CONF_DIF/hdfs-site.xml > /dev/null
echo "<name>dfs.namenode.name.dir</name>" | sudo tee -a $HADOOP_CONF_DIF/hdfs-site.xml > /dev/null
echo "<value>file:///home/ubuntu/hadoop/data/hdfs/namenode</value>" | sudo tee -a $HADOOP_CONF_DIF/hdfs-site.xml > /dev/null
echo "</property>" | sudo tee -a $HADOOP_CONF_DIF/hdfs-site.xml > /dev/null
echo "<property>" | sudo tee -a $HADOOP_CONF_DIF/hdfs-site.xml > /dev/null
echo "<name>dfs.datanode.data.dir</name>" | sudo tee -a $HADOOP_CONF_DIF/hdfs-site.xml > /dev/null
echo "<value>file:///home/ubuntu/hadoop/data/hdfs/datanode</value>" | sudo tee -a $HADOOP_CONF_DIF/hdfs-site.xml > /dev/null
echo "</property>" | sudo tee -a $HADOOP_CONF_DIF/hdfs-site.xml > /dev/null
echo "</configuration>" | sudo tee -a $HADOOP_CONF_DIF/hdfs-site.xml > /dev/null

sudo mkdir -p $HADOOP_HOME/data/hdfs/namenode

echo "namenode" | sudo tee -a $HADOOP_CONF_DIF/masters > /dev/null

sudo sed -i '$d' $HADOOP_CONF_DIF/slaves
echo "datanode1" | sudo tee -a $HADOOP_CONF_DIF/slaves > /dev/null
echo "datanode2" | sudo tee -a $HADOOP_CONF_DIF/slaves > /dev/null
echo "datanode3" | sudo tee -a $HADOOP_CONF_DIF/slaves > /dev/null
echo "datanode4" | sudo tee -a $HADOOP_CONF_DIF/slaves > /dev/null
echo "datanode5" | sudo tee -a $HADOOP_CONF_DIF/slaves > /dev/null
echo "datanode6" | sudo tee -a $HADOOP_CONF_DIF/slaves > /dev/null
echo "######################### Hadoop Settato #########################"

sudo chown -R ubuntu $HADOOP_HOME

#---> hdfs namenode -format
#---> $HADOOP_HOME/sbin/start-dfs.sh
#---> $HADOOP_HOME/sbin/start-yarn.sh
#---> $HADOOP_HOME/sbin/mr-jobhistory-daemon.sh start historyserver

# Spark setup
# Spark setup

wget -q https://downloads.apache.org/spark/spark-2.4.7/spark-2.4.7-bin-hadoop2.7.tgz > /dev/null
tar xzf spark-2.4.7-bin-hadoop2.7.tgz > /dev/null
sudo mv ./spark-2.4.7-bin-hadoop2.7 /home/ubuntu/spark
rm spark-2.4.7-bin-hadoop2.7.tgz
sudo cp spark/conf/spark-env.sh.template spark/conf/spark-env.sh

echo export SPARK_MASTER_HOST=\"$PUBLIC_DNS\" | sudo tee -a spark/conf/spark-env.sh > /dev/null
echo export HADOOP_CONF_DIR=\"home/ubuntu/hadoop/conf\" | sudo tee -a spark/conf/spark-env.sh > /dev/null
echo export PYSPARK_PYTHON=python3 | sudo tee -a spark/conf/spark-env.sh > /dev/null
echo "######################### Spark Settato #########################"

# Setupping progetto e librerie

sudo apt-get update -y > /dev/null
sudo apt-get install -y python3-pip > /dev/null

echo "---> Installazione libreria Pyspark"
sudo pip3 --no-cache-dir install pyspark > /dev/null
echo "---> Installazione libreria Pandas"
sudo pip3 --no-cache-dir install pandas > /dev/null
echo "---> Installazione libreria SkLearn"
sudo pip3 --no-cache-dir install sklearn > /dev/null
echo "---> Installazione libreria Statistics"
sudo pip3 --no-cache-dir install statistics > /dev/null

sudo pip3 install matplotlib
sudo pip3 install pickle5 
sudo pip3 install 
sudo pip3 install scipy


sudo apt install awscli -y 

sudo sudo apt install gedit -y

aws s3 sync s3://authorscovid/ /home/ubuntu/ #get s3 folder

wget http://dl.bintray.com/spark-packages/maven/graphframes/graphframes/0.8.1-spark2.4-s_2.11/graphframes-0.8.1-spark2.4-s_2.11.jar

mv graphframes-0.8.1-spark2.4-s_2.11.jar spark/jars

wget http://dl.bintray.com/spark-packages/maven/graphframes/graphframes/0.8.1-spark2.4-s_2.11/graphframes-0.8.1-spark2.4-s_2.11.jar

#sudo spark/bin/spark-shell --packages graphframes:graphframes:0.8.1-spark2.4-s_2.11

#sudo spark/bin/pyspark --packages graphframes:graphframes:0.7.0-spark2.3-s_2.11

echo "######################### Macchina pronta #########################"
