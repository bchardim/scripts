# Firefox version
VER=133.0.3

# Remove RPM installed firefox
dnf remove -y firefox
rm -rf /opt/firefox
rm -rf /home/student/.mozilla
rm -rf /home/student/.cache/mozilla/firefox

# Download and install firefox from source 
curl https://download-installer.cdn.mozilla.net/pub/firefox/releases/${VER}/linux-x86_64/en-US/firefox-${VER}.tar.bz2 -o firefox-${VER}.tar.bz2
tar xjf firefox-${VER}.tar.bz2 
mv firefox /opt
ln -s /opt/firefox/firefox /usr/local/bin/firefox
rm -rf firefox*

# Configure firefox desktop icon
wget https://raw.githubusercontent.com/mozilla/sumo-kb/main/install-firefox-linux/firefox.desktop -P /usr/local/share/applications

# Configure firefox for student user
echo "pkill firefox" | at now + 15 seconds
sudo -u student sh -c "/usr/local/bin/firefox"
sleep 30
for pref in $(find /home/student/.mozilla/firefox -type f -name 'prefs.js')
do
  echo "lockPref("browser.startup.homepage", "https://www.redhat.com/en");" >> ${pref}
done

# Finish
echo $?
