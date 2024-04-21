#!/bin/sh

set -ex

nginx -c /etc/nginx/nginx.conf -g 'daemon off;'