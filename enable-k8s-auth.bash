#!/usr/bin/env bash

vault auth list | grep -q kubernetes
mount_exits=$?

[[ $mount_exits = 0 ]] && echo "warn: kubernetes auth backend already exists"
[[ $mount_exits = 1 ]] && vault auth enable kubernetes


vault write auth/kubernetes/config kubernetes_host="https://kubernetes.default.svc:443"

# Any service account from any namespace can authenticate towards `demo`
vault write auth/kubernetes/role/demo    \
    bound_service_account_names=*        \
    bound_service_account_namespaces=*   \
    policies=default                     \
    ttl=1h
