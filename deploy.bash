#!/usr/bin/env bash

ns="holvi"


uninstall() {
    kubectl -n $ns delete -f holvi.yaml
    kubectl -n $ns delete secret holvi-keys holvi-certs
    kubectl -n $ns delete pvc -l vault_cr=holvi
    kubectl -n $ns delete -f hop.yaml
    kubectl        delete ns $ns
}

if [[ $1 = "-r" ]]; then
    printf "%s\n" "Redeploying..."
    uninstall
    sleep 1
elif [[ $1 = "-u" ]]; then
    printf "%s\n" "Removing..."
    uninstall
    exit 0
elif [[ $1 = "-h" ]]; then
    printf "%s\n\n" "Usage: ./deploy.bash [options]"
    printf "%s\n" "The script will deploy holvi when no options are provided"
    printf "%s\n" "Other options:"
    printf "\t%s\t%s\n" "-r" "Redeploy holvi"
    printf "\t%s\t%s\n" "-u" "Uninstall holvi"
    printf "\t%s\t%s\n" "-h" "This help prompt"
    exit 0
else
    printf "%s\n" "Deploying..."
fi

kubectl apply -f https://raw.githubusercontent.com/banzaicloud/bank-vaults/main/operator/deploy/crd.yaml

kubectl create ns $ns

# Create TLS secret
kubectl -n $ns create secret generic holvi-certs \
    --from-file=tls.crt=certs/holvi.pem --from-file=tls.key=certs/holvi-key.pem --from-file=ca.crt=certs/root.pem

# Create operator
kubectl -n $ns apply -f hop.yaml

# Create holvi
kubectl -n $ns apply -f holvi.yaml
