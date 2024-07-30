systemctl stop etcd-migration-ocp4
cp -f etcd-migration-ocp4.sh /usr/local/bin/etcd-migration-ocp4.sh
systemctl daemon-reload
echo $?
