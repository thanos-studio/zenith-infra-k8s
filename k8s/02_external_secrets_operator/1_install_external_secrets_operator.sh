#!/bin/bash

read -p "namespace : " namespace
read -p "role name : " role_name
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)

# 1. Add helm repository
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

# 2. Install External Secrets Operator
helm install external-secrets external-secrets/external-secrets \
  --namespace $namespace \
  --create-namespace \
  --set installCRDs=true \
  --set serviceAccount.create=true \
  --set serviceAccount.name=external-secrets-sa \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=arn:aws:iam::$AWS_ACCOUNT_ID:role/$role_name