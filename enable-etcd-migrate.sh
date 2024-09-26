cat << EOF > /etc/systemd/system/etcd-migration-ocp4.service
[Unit]
Description=Migrate etcd to own disk for {{ item.name }} cluster
Wants=network-online.target

[Service]
Type=oneshot
User=lab
Group=lab
ExecStart=/usr/local/bin/etcd-migration-ocp4.sh

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable etcd-migration-ocp4
systemctl stop etcd-migration-ocp4
cp -f etcd-migration-ocp4.sh /usr/local/bin/etcd-migration-ocp4.sh
cp -f etcd-mc-{0,1}.yml /home/lab/ocp4/ 
systemctl daemon-reload
echo $?
