#!/usr/bin/env bash
# Copyright 2026 Canonical Ltd.
# See LICENSE file for licensing details.

set -eu

source ./tests/utils/k8s_utils.sh

NAMESPACE="test-console-tls"
LOCAL_PORT=18443
BASE_URL="https://127.0.0.1:${LOCAL_PORT}"

export NAMESPACE
IMAGE="$(just get-oci)"
export IMAGE

deploy_console() {
    echo "Deploying polaris-console with TLS certificates..."
    envsubst '${NAMESPACE} ${IMAGE}' <tests/console/tls.yaml.templ | kubectl apply -f -
    kubectl rollout status --timeout=120s deploy/polaris-console -n "$NAMESPACE"
}

check_served_certificate() {
    echo "Checking served certificate..."
    echo | openssl s_client -connect "127.0.0.1:${LOCAL_PORT}" \
        -servername polaris-console.test 2>/dev/null |
        openssl x509 -noout -subject | grep -qF "polaris-console.test" || return 1
}

echo "##################################"
echo "DEPLOY POLARIS CONSOLE (TLS MODE)"
echo "##################################"
(
    setup_namespace "$NAMESPACE" &&
        create_tls_secret "$NAMESPACE" console-tls &&
        deploy_console
) || tear_down_failure "$NAMESPACE"

echo "##################################"
echo "NGINX SERVES HTTPS HEALTH ENDPOINT"
echo "##################################"
(
    start_port_forward "$NAMESPACE" "$LOCAL_PORT" 8443 https &&
        [ "$(curl -sfk "$BASE_URL/health")" = "healthy" ] &&
        check_served_certificate
) || {
    stop_port_forward
    tear_down_failure "$NAMESPACE"
}

echo "##################################"
echo "TLS CONFIGURATION APPLIED (CERTIFICATES PROVIDED)"
echo "##################################"
(
    assert_active_config "$NAMESPACE" polaris-console "listen 8443 ssl;" "listen 8080;"
) || {
    stop_port_forward
    tear_down_failure "$NAMESPACE"
}

stop_port_forward
tear_down "$NAMESPACE"
