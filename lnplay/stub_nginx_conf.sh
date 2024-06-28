#!/bin/bash

set -e
cd "$(dirname "$0")"

cat > "$NGINX_CONFIG_PATH" <<EOF
worker_processes auto;
error_log /var/log/nginx/error.log warn;

events {
    worker_connections 1024;
}

http {
    include mime.types;
    sendfile on;

EOF

if [ "$ENABLE_TLS" = true ]; then

    cat >> "$NGINX_CONFIG_PATH" <<EOF
    # global TLS settings
    ssl_prefer_server_ciphers on;
    ssl_protocols TLSv1.3;
    ssl_session_timeout 1d;
    ssl_session_cache shared:MozSSL:10m;
    ssl_session_tickets off;
    add_header Strict-Transport-Security "max-age=63072000" always;
    ssl_stapling on;
    ssl_stapling_verify on;

    ssl_certificate /certs/live/${BACKEND_FQDN}/fullchain.pem;
    ssl_certificate_key /certs/live/${BACKEND_FQDN}/privkey.pem;
    ssl_trusted_certificate /certs/live/${BACKEND_FQDN}/fullchain.pem;

    # http to https redirect.
    server {
        listen 80 default_server;
        server_name ${FRONTEND_FQDN};
        return 301

        https://\$server_name\$request_uri;
    }


EOF

fi


SSL_TAG=""
SERVICE_INTERNAL_PORT=80
if [ "$ENABLE_TLS" = true ]; then
    SSL_TAG=" ssl"
    SERVICE_INTERNAL_PORT=443
fi
if [ "$DEPLOY_CLAMS_REMOTE" = true ]; then
    cat >> "$NGINX_CONFIG_PATH" <<EOF

    # server block for clams remote
    server {
        listen ${SERVICE_INTERNAL_PORT}${SSL_TAG};
        server_name ${FRONTEND_FQDN};
        root /usr/share/nginx/html; 
        index index.html;

        error_page 404 =200 /200.html;
        error_page 403 =200 /200.html;

        location = /200.html {
            internal;
        }
    }

EOF
fi

cat >> "$NGINX_CONFIG_PATH" <<EOF
    map \$http_upgrade \$connection_upgrade {
        default upgrade;
        '' close;
    }
EOF

# write out service for CLN; style is a docker stack deploy style,
# so we will use the replication feature
for (( CLN_ID=0; CLN_ID<CLN_COUNT; CLN_ID++ )); do
    CLN_ALIAS="cln-${CLN_ID}"
    CLN_WEBSOCKET_PORT=$(( STARTING_WEBSOCKET_PORT+CLN_ID ))
    cat >> "$NGINX_CONFIG_PATH" <<EOF

    # server block for ${CLN_ALIAS} websocket
    server {
        listen ${CLN_WEBSOCKET_PORT}${SSL_TAG};

        server_name ${BACKEND_FQDN};

        location / {
            proxy_http_version 1.1;
            proxy_read_timeout 120;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "Upgrade";
            proxy_set_header Proxy "";
            proxy_set_header Host \$http_host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;

            proxy_pass http://${CLN_ALIAS}:9736;
        }
    }

EOF

done



# This section we write the out REST configuration for core lightning.
CLN_REST_PORT=
if [ "$ENABLE_CLN_REST" = true ]; then
    for (( CLN_ID=0; CLN_ID<CLN_COUNT; CLN_ID++ )); do
        CLN_ALIAS="cln-${CLN_ID}"
        CLN_REST_PORT=$(( STARTING_REST_PORT+CLN_ID ))
        cat >> "$NGINX_CONFIG_PATH" <<EOF

    # server block for ${CLN_ALIAS} REST service
    server {
        listen ${CLN_REST_PORT}${SSL_TAG};

        server_name ${BACKEND_FQDN};

        location / {
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;

            proxy_pass http://${CLN_ALIAS}:3010;

        }
    }

EOF

    done

fi

    cat >> "$NGINX_CONFIG_PATH" <<EOF
}
EOF