#!/bin/sh
set -eu

: "${VITE_POLARIS_API_URL:=}"
: "${VITE_POLARIS_REALM:=POLARIS}"
: "${VITE_POLARIS_PRINCIPAL_SCOPE:=PRINCIPAL_ROLE:ALL}"
: "${VITE_OAUTH_TOKEN_URL:=}"
: "${VITE_POLARIS_REALM_HEADER_NAME:=Polaris-Realm}"
: "${VITE_OIDC_ISSUER_URL:=}"
: "${VITE_OIDC_CLIENT_ID:=}"
: "${VITE_OIDC_REDIRECT_URI:=}"
: "${VITE_OIDC_SCOPE:=openid profile email}"
: "${NGINX_TLS_CERT_PATH:=/etc/nginx/tls/tls.crt}"
: "${NGINX_TLS_KEY_PATH:=/etc/nginx/tls/tls.key}"

{
    printf '%s\n' '// Runtime configuration generated from environment variables'
    printf '%s\n' 'window.APP_CONFIG = {'
    printf "  VITE_POLARIS_API_URL: '%s',\n" "$VITE_POLARIS_API_URL"
    printf "  VITE_POLARIS_REALM: '%s',\n" "$VITE_POLARIS_REALM"
    printf "  VITE_POLARIS_PRINCIPAL_SCOPE: '%s',\n" "$VITE_POLARIS_PRINCIPAL_SCOPE"
    printf "  VITE_OAUTH_TOKEN_URL: '%s',\n" "$VITE_OAUTH_TOKEN_URL"
    printf "  VITE_POLARIS_REALM_HEADER_NAME: '%s',\n" "$VITE_POLARIS_REALM_HEADER_NAME"
    printf "  VITE_OIDC_ISSUER_URL: '%s',\n" "$VITE_OIDC_ISSUER_URL"
    printf "  VITE_OIDC_CLIENT_ID: '%s',\n" "$VITE_OIDC_CLIENT_ID"
    printf "  VITE_OIDC_REDIRECT_URI: '%s',\n" "$VITE_OIDC_REDIRECT_URI"
    printf "  VITE_OIDC_SCOPE: '%s'\n" "$VITE_OIDC_SCOPE"
    printf '%s\n' '};'
} >/var/www/polaris/config.js

CERT_PRESENT=false
KEY_PRESENT=false

[ -r "$NGINX_TLS_CERT_PATH" ] && CERT_PRESENT=true
[ -r "$NGINX_TLS_KEY_PATH" ] && KEY_PRESENT=true

if [ "$CERT_PRESENT" = "true" ] && [ "$KEY_PRESENT" = "true" ]; then
    printf '%s\n' 'include /usr/share/polaris-console/nginx/tls.conf;' >/tmp/nginx-conf.d/runtime-server.conf
elif [ "$CERT_PRESENT" = "false" ] && [ "$KEY_PRESENT" = "false" ]; then
    printf '%s\n' 'include /usr/share/polaris-console/nginx/http.conf;' >/tmp/nginx-conf.d/runtime-server.conf
else
    echo 'TLS configuration is incomplete: both /etc/nginx/tls/tls.crt and /etc/nginx/tls/tls.key must be present and readable to enable TLS' >&2
    exit 1
fi

exec nginx -g 'daemon off;'
