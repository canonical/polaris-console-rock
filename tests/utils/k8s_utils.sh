#!/usr/bin/env bash
# Copyright 2026 Canonical Ltd.
# See LICENSE file for licensing details.

# Check that kubectl is in the PATH and that it is properly configured to access the
# K8s cluster.
if ! kubectl get ns >>/dev/null; then
    echo "Error: The K8s cluster has not been configured properly. Exiting..."
    exit 1
fi

setup_namespace() {
    # Create test namespace.
    #
    # Arguments:
    # $1: Namespace to run the tests in
    namespace=$1

    echo "Setting up test namespace $namespace"
    kubectl create namespace "$namespace"
}

tear_down() {
    # Tear down test namespace.
    #
    # Arguments:
    # $1: Namespace
    namespace=$1

    echo "Tearing down resources"
    if kubectl get namespace "$namespace" >/dev/null 2>&1; then
        echo "Deleting namespace $namespace..."
        kubectl delete namespace "$namespace" --wait=true
        echo "Cleanup complete."
    else
        echo "Namespace $namespace already gone."
    fi
}

tear_down_failure() {
    # Tear down and exit 1.
    #
    # Arguments:
    # $1: Namespace
    tear_down "$1"
    exit 1
}

create_tls_secret() {
    # Generate a self-signed certificate and create a TLS secret with tls.crt and tls.key.
    #
    # Arguments:
    # $1: Namespace
    # $2: Secret name
    namespace=$1
    secret=$2

    workdir=$(mktemp -d)
    openssl req -x509 -newkey rsa:2048 -nodes \
        -keyout "$workdir/tls.key" -out "$workdir/tls.crt" \
        -days 1 -subj "/CN=polaris-console.test" \
        -addext "subjectAltName=DNS:polaris-console.test"
    kubectl -n "$namespace" create secret tls "$secret" \
        --cert="$workdir/tls.crt" --key="$workdir/tls.key"
    rm -rf "$workdir"
}

start_port_forward() {
    # Port-forward to the console service and wait until /health answers.
    #
    # Arguments:
    # $1: Namespace
    # $2: Local port
    # $3: Service port
    # $4: Scheme (http|https)
    namespace=$1
    local_port=$2
    service_port=$3
    scheme=$4

    kubectl port-forward -n "$namespace" svc/polaris-console \
        "$local_port:$service_port" >/dev/null 2>&1 &
    PF_PID=$!

    echo "Waiting for port-forward $local_port -> $service_port ($scheme)..."
    for _ in $(seq 1 30); do
        if curl -sf -k -o /dev/null "$scheme://127.0.0.1:$local_port/health"; then
            return 0
        fi
        sleep 1
    done
    echo "Error: port-forward never became ready"
    return 1
}

stop_port_forward() {
    # Stop the port-forward started by start_port_forward.
    if [ -n "${PF_PID:-}" ] && kill -0 "$PF_PID" 2>/dev/null; then
        kill "$PF_PID"
    fi
}

assert_active_config() {
    # Dump the running nginx configuration and check which server block was applied.
    #
    # Arguments:
    # $1: Namespace
    # $2: Deployment name
    # $3: Directive expected in the active config
    # $4: Directive expected NOT to be in the active config
    namespace=$1
    deployment=$2
    expected=$3
    unexpected=$4

    echo "Checking active nginx configuration..."
    config=$(kubectl exec -n "$namespace" "deploy/$deployment" -- /usr/sbin/nginx -T 2>/dev/null) || return 1
    echo "$config" | grep -qF "$expected" || {
        echo "Error: '$expected' not in active config"
        return 1
    }
    if echo "$config" | grep -qF "$unexpected"; then
        echo "Error: '$unexpected' unexpectedly present in active config"
        return 1
    fi
}
