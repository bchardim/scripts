sed -i 's/SUCCESS=0/SUCCESS=0; PKG_ENV=prod/mg' /usr/local/sbin/dynolabs-update.sh
systemctl restart dynolabs-update.service
su - student -c 'source .venv/labs/bin/activate && pip list | grep rht && deactivate && echo $?'
