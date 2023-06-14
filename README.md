# Minimalistic Vault Operator demo using Vault-Operator from Banzaicloud

This repository contains an example application, Holvi, which consists of a [Vault operator](https://github.com/bank-vaults/vault-operator) and 3-replica [Vault](https://github.com/hashicorp/vault) cluster using Integrated Storage (Raft) backend.

This is just a playground to try out different kinds of operator things. For example, the application is configured to reside within a single namespace and tries to minimize the RBAC permissions requested from Kubernetes.

## Files

* `.holvi.env`, helper file for Vault CLI usage (via port-forward)
* `certs.yaml`, manifest that generates development certificates using [certyaml](https://github.com/tsaarni/certyaml)
* `deploy.bash`, deploys the application in the `holvi` namespace
* `enable-k8s-auth.bash`, enable [Kubernetes Auth Method](https://developer.hashicorp.com/vault/docs/auth/kubernetes)
* `enable-pki.bash`, enable [PKI Secret Engine](https://developer.hashicorp.com/vault/docs/secrets/pki), importing the locally-generated CA certificate
* `holvi.yaml`, the manifests related to Holvi (the Vault cluster)
* `hop.yaml`, the manifests related to HOP (Holvi Operator)
* `serviceaccount-foo.yaml`, service account that can utilize Kubernetes Auth Method

## Deploying

### Prerequisites

* Kubernetes cluster, e.g. [kind](https://kind.sigs.k8s.io/)
* [certyaml](https://github.com/tsaarni/certyaml)
* [vault CLI](https://developer.hashicorp.com/vault/downloads)
* [yq](https://github.com/mikefarah/yq)

### Basic steps

Generate the development certificates

    mkdir -p certs && certyaml -d certs

Deploy the application

    ./deploy.bash
    watch -n1 -- kubectl -n holvi get po

Start port-forwarding (in a separate window)

    kubectl -n holvi port-forward svc/holvi 8200

Set up Vault CLI

    source .holvi.env

Check that everything works

    vault status

    # Output
    # ...
    # Key                     Value
    # ---                     -----
    # Seal Type               shamir
    # Initialized             true
    # Sealed                  false
    # Total Shares            5
    # Threshold               3
    # Version                 1.12.3
    # ...

Now you can play around with Vault, try for example

    vault secrets list
    vault secrets enable kv
    vault kv put kv/secret foo=bar
    vault kv get kv/secret

Enable Kubernetes Auth method and try to login

    ./enable-k8s-auth.bash


    # Optional; create a service account and try to login

    kubectl -n holvi apply -f serviceaccount-foo.yaml

    jwt="$(kubectl -n holvi get secrets foo --template='{{.data.token}}' | base64 -d)"
    token="$(vault write auth/kubernetes/login role=demo jwt="$jwt" -format=json | jq -r .auth.client_token)"; echo "$token"
    VAULT_TOKEN="$token" vault token lookup

Enable PKI secret engine, import the locally generated CA (requires Vault 1.11.0+)

    ./enable-pki.bash


    # Optional; generate a certificate and verify the chain with the local root CA
    # This should work since we imported the CA

    cert="$(vault write -format=json pki/issue/holvi common_name="holvi" ttl="24h" | jq -r .data.certificate)"; echo "$cert"
    openssl verify -CAfile certs/root.pem <<< "$cert"


### Working with local images in `kind`

    git clone git@github.com:banzaicloud/bank-vaults.git && cd bank-vaults

    # Compile bank-vaults
    DOCKER_TAG=holvi make docker          && kind load docker-image ghcr.io/banzaicloud/bank-vaults:holvi

    git clone git@github.com:bank-vaults/vault-operator.git && cd vault-operator

    # Compile operator
    # (Since vault-operator is being re-organized there's high likelyhood that these commands will change)
    make container-image
    img_hash=$(docker image ls | head -n2 | sort | head -n1 | awk '{print $3}')
    docker tag "${img_hash}" ghcr.io/bank-vaults/vault-operator:holvi
    kind load docker-image ghcr.io/bank-vaults/vault-operator:holvi


### Changing Images

**Vault** - In `holvi.yaml`, look for the Vault custom resource, field name `spec.image`.

**bank-vaults** - In `holvi.yaml`, look for the Vault custom resource, field name `spec.bankVaultsImage`.

**vault-operator** - In `hop.yaml`, look for the Deployment resource, field name `spec.template.spec.containers[0].image`.

### More than 3 replicas

Three should be enough for demo purposes, but if you want more there are minor changes needed:

- Edit `certs.yaml` to include more subject alternative names, then re-generate the certificates.
- In `hop.yaml`, add more permissions against services and pods (look for holvi-0, holvi-1, holvi-2).


### Redeployment

Complete redeployment is easy, just do

    ./deploy.bash -r

This will clean the namespace and start over.

In case you want to just do minor updates, you can apply the manifests directly, e.g.

    kubectl -n holvi apply -f holvi.yaml