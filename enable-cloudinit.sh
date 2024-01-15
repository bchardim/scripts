echo "network: {config: disabled}" >> /etc/cloud/cloud.cfg
echo "network: {config: disabled}" >> /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
echo "ssh_pwauth:   1" >> /etc/cloud/cloud.cfg
for i in cloud-init cloud-config cloud-init-local cloud-final
do
   systemctl enable $i
done 
