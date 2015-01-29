FROM ubuntu:14.04

# Run upgrades
RUN echo deb http://us.archive.ubuntu.com/ubuntu/ precise universe multiverse >> /etc/apt/sources.list;\
  echo deb http://us.archive.ubuntu.com/ubuntu/ precise-updates main restricted universe >> /etc/apt/sources.list;\
  echo deb http://security.ubuntu.com/ubuntu precise-security main restricted universe >> /etc/apt/sources.list;\
  echo udev hold | dpkg --set-selections;\
  echo initscripts hold | dpkg --set-selections;\
  echo upstart hold | dpkg --set-selections;\
  apt-get update;\
  apt-get -y upgrade

# Install dependencies
RUN apt-get install -y build-essential zlib1g-dev libyaml-dev libssl-dev libgdbm-dev libreadline-dev libncurses5-dev \
    libffi-dev curl openssh-server checkinstall libxml2-dev libxslt-dev libcurl4-openssl-dev libicu-dev sudo python \
    python-docutils python-software-properties nginx logrotate postfix git cmake libpq-dev

# Install Ruby
RUN apt-get remove ruby1.8
RUN mkdir /tmp/ruby && cd /tmp/ruby
RUN curl -L --progress http://cache.ruby-lang.org/pub/ruby/2.1/ruby-2.1.5.tar.gz | tar xz
RUN cd ruby-2.1.5 && ./configure --disable-install-rdoc && make && sudo make install

# Create Git user
RUN adduser --disabled-login --gecos 'GitLab' git


# Install GitLab Shell
RUN cd /home/git;\
su git -c "git clone https://github.com/gitlabhq/gitlab-shell.git -b v1.9.0";\
cd gitlab-shell;\
su git -c "cp config.yml.example config.yml";\
sed -i -e 's/localhost/127.0.0.1/g' config.yml;\
su git -c "./bin/install"

# Install MySQL
RUN  apt-get install -y mysql-client libmysqlclient-dev

# Redis
RUN sudo apt-get install libjemalloc1 redis-tools redis-server

# Configure redis to use sockets
RUN sudo cp /etc/redis/redis.conf /etc/redis/redis.conf.orig

# Disable Redis listening on TCP by setting 'port' to 0
RUN sed 's/^port .*/port 0/' /etc/redis/redis.conf.orig | sudo tee /etc/redis/redis.conf

# Enable Redis socket for default Debian / Ubuntu path
RUN echo 'unixsocket /var/run/redis/redis.sock' | sudo tee -a /etc/redis/redis.conf
# Grant permission to the socket to all members of the redis group
RUN echo 'unixsocketperm 770' | sudo tee -a /etc/redis/redis.conf

# Create the directory which contains the socket
RUN mkdir /var/run/redis
RUN chown redis:redis /var/run/redis
RUN chmod 755 /var/run/redis
# Persist the directory which contains the socket, if applicable
RUN if [ -d /etc/tmpfiles.d ]; then echo 'd  /var/run/redis  0755  redis  redis  10d  -' | sudo tee -a /etc/tmpfiles.d/redis.conf; fi

# Activate the changes to redis.conf
RUN sudo service redis-server restart

# Add git to the redis group
RUN sudo usermod -aG redis git

# Install GitLab
RUN cd /home/git && sudo -u git -H git clone https://gitlab.com/gitlab-org/gitlab-ce.git -b 7-6-stable gitlab

# Misc configuration stuff
RUN cd /home/git/gitlab;\
  chown -R git tmp/;\
  chown -R git log/;\
  chmod -R u+rwX log/;\
  chmod -R u+rwX tmp/;\
  su git -c "mkdir /home/git/gitlab-satellites";\
  su git -c "mkdir tmp/pids/";\
  su git -c "mkdir tmp/sockets/";\
  chmod -R u+rwX tmp/pids/;\
  chmod -R u+rwX tmp/sockets/;\
  su git -c "mkdir public/uploads";\
  chmod -R u+rwX public/uploads;\
  su git -c "cp config/unicorn.rb.example config/unicorn.rb";\
  su git -c "cp config/initializers/rack_attack.rb.example config/initializers/rack_attack.rb";\
  su git -c "git config --global user.name 'GitLab'";\
  su git -c "git config --global user.email 'gitlab@localhost'";\
  su git -c "git config --global core.autocrlf input"

RUN cd /home/git/gitlab/ && sudo gem install bundler --no-ri --no-rdoc && sudo -u git -H bundle install --deployment --without development test mysql2 aws

# Install init scripts
RUN cd /home/git/gitlab;\
  cp lib/support/init.d/gitlab /etc/init.d/gitlab;\
  update-rc.d gitlab defaults 21;\
  cp lib/support/logrotate/gitlab /etc/logrotate.d/gitlab

EXPOSE 48443
EXPOSE 48022

ADD . /srv/gitlab

RUN chmod +x /srv/gitlab/start.sh;\
  chmod +x /srv/gitlab/firstrun.sh

CMD ["/srv/gitlab/start.sh"]
