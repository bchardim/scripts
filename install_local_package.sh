sudo sed -i 's/SUCCESS=0/SUCCESS=0; PKG_ENV=prod/mg' /usr/local/sbin/dynolabs-update.sh
sudo systemctl restart dynolabs-update.service
source .venv/labs/bin/activate && pip list | grep rht && deactivate && echo $?
