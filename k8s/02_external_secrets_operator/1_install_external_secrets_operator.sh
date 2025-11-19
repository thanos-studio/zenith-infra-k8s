#!/bin/bash
set -euo pipefail

for cmd in aws helm kubectl; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "error: '$cmd' 명령이 필요합니다." >&2
    exit 1
  fi
done

read -r -p "role name : " role_name
if [[ -z "${role_name// }" ]]; then
  role_name="zenith-prod-zenith-eks-external-secrets-operator-role"
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
if [[ -z "$AWS_ACCOUNT_ID" ]]; then
  exit 1
fi

# 1. Add helm repository
helm repo add external-secrets https://charts.external-secrets.io --force-update
helm repo update

# 2. Create namespace with webhook exclusion label
kubectl create namespace external-secrets --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace external-secrets elbv2.k8s.aws/pod-readiness-gate-inject=disabled --overwrite

# 3. Install External Secrets Operator
helm upgrade --install external-secrets external-secrets/external-secrets \
  --namespace external-secrets \
  --set installCRDs=true \
  --set serviceAccount.create=true \
  --set serviceAccount.name=external-secrets-sa \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=arn:aws:iam::$AWS_ACCOUNT_ID:role/$role_name

# 3. uninstall External Secrets Operator
# helm uninstall external-secrets -n external-secrets
