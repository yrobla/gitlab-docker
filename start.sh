#!/bin/bash

# check for needed env vars
: ${DB_ADMIN_USER?"Need to set DB admin username"}
: ${DB_ADMIN_PASS?"Need to set DB admin password"}
: ${DB_HOST?"Need to set DB host"}
: ${HOST?"Need to set host"}
: ${DB_USER?"Need to set DB user"}
: ${DB_PASS?"Need to set DB pass"}
: ${DB_NAME?"Need to set DB name"}

# start SSH
mkdir -p /var/run/sshd
/usr/sbin/sshd

# start redis
redis-server > /dev/null 2>&1 &
sleep 5

# remove PIDs created by GitLab init script
rm /home/git/gitlab/tmp/pids/*

# change nginx and gitlab configuration
sed -i -e "s/#HOST#/$HOST/g" /srv/gitlab/config/nginx
sed -i -e "s/#HOST#/$HOST/g" /srv/gitlab/config/gitlab.yml

# Copy over config files
cp /srv/gitlab/config/gitlab.yml /home/git/gitlab/config/gitlab.yml
cp /srv/gitlab/config/nginx /etc/nginx/sites-available/gitlab
ln -s /etc/nginx/sites-available/gitlab /etc/nginx/sites-enabled/gitlab
cp /srv/gitlab/config/database.yml /home/git/gitlab/config/database.yml
chown git:git /home/git/gitlab/config/database.yml && chmod o-rwx /home/git/gitlab/config/database.yml

# Link data directories to /srv/gitlab/data
rm -R /home/git/gitlab/tmp && ln -s /srv/gitlab/data/tmp /home/git/gitlab/tmp && chown -R git /srv/gitlab/data/tmp/ && chmod -R u+rwX  /srv/gitlab/data/tmp/
rm -R /home/git/.ssh && ln -s /srv/gitlab/data/ssh /home/git/.ssh && chown -R git:git /srv/gitlab/data/ssh && chmod -R 0700 /srv/gitlab/data/ssh && chmod 0700 /home/git/.ssh
chown -R git:git /srv/gitlab/data/gitlab-satellites
chown -R git:git /srv/gitlab/data/repositories && chmod -R ug+rwX,o-rwx /srv/gitlab/data/repositories && chmod -R ug-s /srv/gitlab/data/repositories/
find /srv/gitlab/data/repositories/ -type d -print0 | xargs -0 chmod g+s

# fix timeout - https://github.com/gitlabhq/gitlabhq/issues/694 
sed -i 's/^timeout .*/timeout 300/' /home/git/gitlab/config/unicorn.rb

# Change repo path in gitlab-shell config
sed -i -e 's/\/home\/git\/repositories/\/srv\/gitlab\/data\/repositories/g' /home/git/gitlab-shell/config.yml

# change database configuration
sed -i -e "s/#DB_NAME#/$DB_NAME/g" /home/git/gitlab/config/database.yml
sed -i -e "s/#DB_USER#/$DB_USER/g" /home/git/gitlab/config/database.yml
sed -i -e "s/#DB_PASS#/$DB_PASS/g" /home/git/gitlab/config/database.yml
sed -i -e "s/#DB_HOST#/$DB_HOST/g" /home/git/gitlab/config/database.yml

# Run the firstrun script
/srv/gitlab/firstrun.sh

# start gitlab
service gitlab start

# start nginx
service nginx start

sleep 5

# keep script in foreground
su git -c "touch /home/git/gitlab/log/production.log"
tail -f /home/git/gitlab/log/production.log
