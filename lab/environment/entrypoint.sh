#!/bin/sh
set -e
: "${COLOR:=steelblue}"   # default so the page renders even when COLOR isn't set
envsubst '${COLOR}' < /usr/share/nginx/html/index.html.template > /usr/share/nginx/html/index.html
exec nginx -g 'daemon off;'
