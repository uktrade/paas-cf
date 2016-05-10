#!/bin/sh
set -u
set -e
echo "Setting up concourse basic auth as ${CONCOURSE_ATC_USER}: ${CONCOURSE_ATC_PASSWORD}"
sed "s/--basic-auth-username.*/--basic-auth-username \'${CONCOURSE_ATC_USER}\' \\\/" -i /etc/init/concourse-web.conf
sed "s/--basic-auth-password.*/--basic-auth-password \'${CONCOURSE_ATC_PASSWORD}\' \\\/" -i /etc/init/concourse-web.conf
service concourse-web restart

