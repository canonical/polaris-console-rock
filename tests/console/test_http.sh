#!/usr/bin/env bash
# Copyright 2026 Canonical Ltd.
# See LICENSE file for licensing details.

set -eu

source ./tests/utils/k8s_utils.sh

NAMESPACE="test-console-http"
LOCAL_PORT=18080
BASE_URL="http://127.0.0.1:${LOCAL_PORT}"

export NAMESPACE
IMAGE="$(just get-oci)"
export IMAGE

deploy_console() {
    echo "Deploying polaris-console without TLS certificates..."
    envsubst '${NAMESPACE} ${IMAGE}' <tests/console/http.yaml.templ | kubectl apply -f -
    kubectl rollout status --timeout=120s deploy/polaris-console -n "$NAMESPACE"
}

echo "##################################"
echo "DEPLOY POLARIS CONSOLE (HTTP MODE)"
echo "##################################"
(
    setup_namespace "$NAMESPACE" &&
        deploy_console
) || tear_down_failure "$NAMESPACE"

echo "##################################"
echo "NGINX SERVES HEALTH ENDPOINT"
echo "##################################"
(
    start_port_forward "$NAMESPACE" "$LOCAL_PORT" 8080 http &&
        [ "$(curl -sf "$BASE_URL/health")" = "healthy" ]
) || {
    stop_port_forward
    tear_down_failure "$NAMESPACE"
}

echo "##################################"
echo "HTTP CONFIGURATION APPLIED (NO TLS CERTIFICATES)"
echo "##################################"
(
    assert_active_config "$NAMESPACE" polaris-console "listen 8080;" "listen 8443 ssl;"
) || {
    stop_port_forward
    tear_down_failure "$NAMESPACE"
}

stop_port_forward
tear_down "$NAMESPACE"
