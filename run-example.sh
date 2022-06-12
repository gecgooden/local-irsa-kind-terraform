#!/bin/sh

ROLE_ARN=$(terraform -chdir=terraform output -raw iam-role | sed 's/\//\\\//')

# Replace role arn template, and apply to the cluster
cat ./example-job.yaml \
    | sed "s/<<role-arn>>/${ROLE_ARN}/" \
    | kubectl apply -f -

# Wait for the pod to complete
kubectl wait --for=condition=complete job/example-job

# Get logs to prove it worked
kubectl logs job/example-job

# Delete job
cat ./example-job.yaml \
    | sed "s/<<role-arn>>/${ROLE_ARN}/" \
    | kubectl delete -f -