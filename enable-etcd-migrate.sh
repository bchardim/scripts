systemctl stop etcd-migration-ocp4
cp -f etcd-migrate-ocp4.sh /usr/local/bin/etcd-migrate-ocp4.sh
systemctl daemon-reload
echo $?
