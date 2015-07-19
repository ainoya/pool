FROM prevsio/pool-base
MAINTAINER mookjp

WORKDIR /tmp

RUN export PATH=$PATH:/usr/local/bin

# Update docker
RUN curl -s https://get.docker.com/builds/Linux/x86_64/docker-latest -o /usr/bin/docker &&\
    chmod +x /usr/bin/docker

RUN curl -sL https://github.com/docker/compose/releases/download/1.3.3/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose
RUN chmod +x /usr/local/bin/docker-compose

# hostname settings
ADD provisioning/network /etc/sysconfig/network
ADD provisioning/hosts /etc/sysconfig/hosts

# Add Apache settings
ADD provisioning/httpd.conf /etc/httpd/conf/httpd.conf
ADD provisioning/mruby.conf /etc/httpd/conf.d/mruby.conf

# Add supervisor configuration file
ADD provisioning/supervisord.conf /etc/supervisord.conf

# Add container-limitation configuration gile
ADD provisioning/cron/limit_containers /etc/cron.d/limit_containers

# Add mod_mruby handler to manage request

COPY ./handlers /app/handlers
COPY ./build-screen/dist /app/handlers/resources/build-screen

# Add util scripts for handling containers
ADD scripts /app/scripts
RUN chmod +x /app/scripts/starter && chmod +x /app/scripts/limit_containers &&\
    mkdir -p /var/log/supervisor &&\
    mkdir -p /var/log/builder &&\
    mkdir -p /app/images &&\
    touch /app/images/ids &&\
    mkdir -p /root/.ssh &&\
    mkdir -p /var/www/.ssh

ADD keys /app/keys
ADD /provisioning/ssh_config /var/www/.ssh/config
ADD /provisioning/ssh_config /root/.ssh/config

RUN chown -R apache. /var/www/.ssh &&\
    chmod 600 /var/www/.ssh/config /root/.ssh/config &&\
    chmod 700 /var/www/.ssh /root/.ssh

# Add config files
ADD config /app/config

# Add test files
ADD tests /app/tests

# Add apache to pool and docker group to access /app
# as hook.rb has to access application's repository in it
# and to access docker sock file
RUN groupadd pool &&\
    usermod -G docker,pool apache &&\
    chgrp --recursive pool /app &&\
    chmod --recursive g+rwx /app

# Install build-srver
COPY builder/Gemfile /tmp/bundle/
COPY builder/Gemfile.lock /tmp/bundle/
COPY builder/builder.gemspec /tmp/bundle/
COPY builder/lib/builder/version.rb /tmp/bundle/lib/builder/version.rb

WORKDIR /tmp/bundle
RUN /usr/local/bin/bundle install --without development test && rm -rf /tmp/bundle

# Set target preview repository
ENV PREVIEW_REPOSITORY_URL https://github.com/ainoya/pool-compose-example.git
ENV MAX_CONTAINERS 10
ENV GIT_COMMIT_ID_CACHE_EXPIRE 10
ENV POOL_BASE_DOMAIN pool.dev
ENV GITHUB_BOT false

# add docker-compose

EXPOSE 80 8080

RUN echo 'gem: --no-document' >> ~/.gemrc
COPY builder/pkg /tmp/pkg
WORKDIR /tmp/pkg
RUN /usr/local/bin/gem install builder-0.0.1.gem && rm -rf /tmp/pkg

WORKDIR /app
CMD \
    /app/scripts/starter &&\
    tail -F /var/log/httpd/error_log & \
    tail -F /var/log/builder/build_server.log
