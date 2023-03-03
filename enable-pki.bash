#!/usr/bin/env bash

cert_dir="./certs"
[[ -d $cert_dir ]] || { echo "$cert_dir does not exist, did you generate the certs?" ; exit 1; }

create_ca() {
    vault secrets enable pki
    vault secrets tune -max-lease-ttl=43800h pki

    vault write pki/config/urls \
        issuing_certificates="$VAULT_ADDR/v1/pki/ca" \
        crl_distribution_points="$VAULT_ADDR/v1/pki/crl"

    # Import our local root CA
    cat certs/root.pem certs/root-key.pem > certs/root-bundle.pem
    vault write pki/issuers/import/bundle pem_bundle=@certs/root-bundle.pem

    vault write pki/roles/holvi \
        issuer_ref="$(vault read -field=default pki/config/issuers)" \
        allow_any_name=true \
        max_ttl="720h"
}

[[ $(vault secrets list | grep pki/) ]] || create_ca

