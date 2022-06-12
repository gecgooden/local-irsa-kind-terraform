#!/bin/sh

if [[ $(kind get clusters | grep kind) ]]; then
    echo "Cluster already exists"
    exit 0
fi

# Get keys from Secrets manager
aws secretsmanager get-secret-value --secret-id local-oidc/public-key --query 'SecretString' | jq -rc '.' > local-keys/public-key.pub
aws secretsmanager get-secret-value --secret-id local-oidc/private-key --query 'SecretString' | jq -rc '.' > local-keys/private-key.key

cat <<EOF | kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes: 
- role: control-plane
  extraMounts:
  - containerPath: /etc/kubernetes/oidc
    hostPath: $(pwd)/local-keys
    readOnly: true
kubeadmConfigPatches:
- |
  apiVersion: kubeadm.k8s.io/v1beta2
  kind: ClusterConfiguration
  apiServer:
    extraArgs:
      api-audiences: "sts.amazonaws.com"
      service-account-key-file: "/etc/kubernetes/pki/sa.pub"
      service-account-key-file: "/etc/kubernetes/oidc/public-key.pub"
      service-account-signing-key-file: "/etc/kubernetes/oidc/private-key.key"
      service-account-issuer: "https://$(terraform -chdir=terraform output -raw bucket_hostname)"
    extraVolumes:
    - name: "oidc"
      hostPath: "/etc/kubernetes/oidc"
      mountPath: "/etc/kubernetes/oidc"

EOF