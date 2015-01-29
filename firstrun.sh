#!/bin/bash

# Regenerate the SSH host key
/bin/rm /etc/ssh/ssh_host_*
dpkg-reconfigure openssh-server

password=$(cat /srv/gitlab/config/database.yml | grep -m 1 password | sed -e 's/  password: "//g' | sed -e 's/"//g')

# ==============================================

# === Delete this section if restoring data from previous build ===

# Precompile assets
cd /home/git/gitlab
su git -c "bundle exec rake assets:precompile RAILS_ENV=production"

# Initialize MySQL
mysqladmin -u $DB_ADMIN_USER --password=$DB_ADMIN_PASS --host=$DB_HOST password $DB_ADMIN_PASS
echo "CREATE USER '$DB_USER'@'%' IDENTIFIED BY '$DB_PASS';" | \
  mysql --host=$DB_HOST --user=$DB_ADMIN_USER --password=$DB_ADMIN_PASS
echo "CREATE DATABASE IF NOT EXISTS $DB_NAME DEFAULT CHARACTER SET \
  'utf8' COLLATE 'utf8_unicode_ci';" | mysql --host=$DB_HOST --user=$DB_ADMIN_USER --password=$DB_ADMIN_PASS
echo "GRANT SELECT, LOCK TABLES, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, \
  ALTER ON $DB_NAME.* TO '$DB_USER'@'%';" | mysql \
    --host=$DB_HOST --user=$DB_ADMIN_USER --password=$DB_ADMIN_PASS

cd /home/git/gitlab
su git -c "bundle exec rake gitlab:setup force=yes RAILS_ENV=production"
sleep 5
su git -c "bundle exec rake db:seed_fu RAILS_ENV=production"

# ================================================================

# Delete firstrun script
rm /srv/gitlab/firstrun.sh
