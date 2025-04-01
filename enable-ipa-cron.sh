echo "*/5 * * * * /usr/sbin/ipactl status; if [ \"\$?\" != \"0\" ]; then /usr/sbin/ipactl restart && echo \"\$(date) IPA restarted\" >> /tmp/ipa-status.log; fi" >> /var/spool/cron/root
