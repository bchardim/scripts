line='05 22 */2 * * /usr/bin/gitlab-ctl restart; if [ "$?" != "0" ]; then sleep 120 && /usr/bin/gitlab-ctl restart; fi'
(crontab -u $(whoami) -l; echo "$line" ) | crontab -u $(whoami) -
echo $?
