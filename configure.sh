cp ./wait.sh /home/lab/ocp4/wait.sh
cp ./cert-renew-ocp4.sh /usr/local/bin/cert-renew-ocp4.sh

cat <<EOF > /etc/systemd/system/cert-renew-ocp4.service
[Unit]
Description=Monitor OpenShift Internal Certificates Auto-Renew Process for ocp4 cluster
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/cert-renew-ocp4.sh

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable cert-renew-ocp4.service
systemctl start cert-renew-ocp4.service
