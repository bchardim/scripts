systemctl stop etcd-migration-ocp4
cp -f enable-etcd-migrate.sh /usr/local/bin/etcd-migrate-ocp4.sh
systemctl daemon-reload
echo $?
