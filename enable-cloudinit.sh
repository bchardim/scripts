echo "network: {config: disabled}" >> /etc/cloud/cloud.cfg
echo "network: {config: disabled}" > /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
echo "ssh_pwauth:   1" >> /etc/cloud/cloud.cfg
cloud-init clean --log
systemctl enable cloud-init.service
systemctl enable cloud-config.service
systemctl enable cloud-init-local.service
systemctl enable cloud-final.service
rm -rf /tmp/callback.sh
rm -rf /var/lib/cloud/instance
rm -rf /var/lib/cloud/instances
rm -rf /var/lib/cloud/data
rm -rf /var/lib/cloud/sem/config_scripts_per_once.once
rm -rf /var/log/cloud-init.log
rm -rf /var/log/cloud-init-output.log
echo $?
