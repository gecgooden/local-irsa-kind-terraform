# Local IRSA using kind and terraform

IAM Roles for Service Accounts (IRSA) is a feature of AWS EKS where you can utilise Kubernetes service accounts to authenticate against AWS IAM and consume AWS APIs (eg S3). See the documentation here: 

This repo is an example of setting up the required AWS infrastructure with [terraform](), provisioning a local kubernetes cluster with [kind]() and then deploying the required components in the cluster with [helm]().

## Requirements

Install the following pieces of software
- Docker
- Kind
- Terraform
- go
- Helm
- AWS CLI

The steps below assume that you have an AWS account created, and you have the AWS CLI configured (eg through access keys in environment variables)

## Running

### Deploy infrastructure with Terraform

Provision the AWS infrastructure with:

```
$ terraform -chdir=terraform apply
```

This will output a variable `iam-role` that will be needed later to test the implementation

### Create the kubernetes cluster

Provision the Kubenetes cluster in `kind` with:

```
$ ./build-cluster.sh
```

### Deploy cert-manager

The pod-identity-webhook needs to be able to create and manage self signed certificates, this is being done with [cert-manager]().

Install this using:
```
$ helm repo add jetstack https://charts.jetstack.io
$ helm repo update
$ helm upgrade -i cert-manager \
    jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.8.0 \
  --set installCRDs=true
```

### Deploy `pod-identity-webhook`

```
$ helm upgrade -i pod-identity-webhook \
    ./pod-identity-webhook \
    --namespace kube-system
```

### Test

There is an example Job definition provided ([example-job.yaml](./example-job.yaml)), which can be applied with the following shell script:

```
$ ./run-example.sh
```

### Teardowm

Once you're done testing, you should remember to delete the resources.

Do this by running:

```
$ kind delete cluster
$ terraform -chdir=terraform destroy
```