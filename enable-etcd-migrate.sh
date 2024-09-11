systemctl stop etcd-migration-ocp4
cp -f etcd-migration-ocp4.sh /usr/local/bin/etcd-migration-ocp4.sh
cp -f etcd-mc-{0|1}.yml /home/lab/ocp4/ 
systemctl daemon-reload
echo $?
