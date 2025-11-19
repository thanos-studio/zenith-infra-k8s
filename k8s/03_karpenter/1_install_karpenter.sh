#!/bin/bash
set -euo pipefail

REQUIRED_CMDS=(aws eksctl kubectl helm)
for cmd in "${REQUIRED_CMDS[@]}"; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "error: '$cmd' 명령이 필요합니다." >&2
    exit 1
  fi
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)"
IAM_DIR="$SCRIPT_DIR/iam"
MANIFEST_DIR="$SCRIPT_DIR/manifests"

read -r -p "region : " AWS_REGION
if [[ -z "${AWS_REGION// }" ]]; then
  echo "error: region 값을 입력하세요." >&2
  exit 1
fi

read -r -p "cluster name : " CLUSTER_NAME
if [[ -z "${CLUSTER_NAME// }" ]]; then
  echo "error: cluster name 값을 입력하세요." >&2
  exit 1
fi

DEFAULT_VERSION="${KARPENTER_VERSION:-v0.36.2}"
read -r -p "karpenter version [${DEFAULT_VERSION}] : " KARPENTER_VERSION_INPUT
if [[ -n "${KARPENTER_VERSION_INPUT// }" ]]; then
  KARPENTER_VERSION="$KARPENTER_VERSION_INPUT"
else
  KARPENTER_VERSION="$DEFAULT_VERSION"
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
if [[ -z "${AWS_ACCOUNT_ID// }" ]]; then
  echo "error: AWS Account ID를 가져오지 못했습니다." >&2
  exit 1
fi

CLUSTER_ENDPOINT=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" --query 'cluster.endpoint' --output text)
OIDC_ISSUER=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" --query 'cluster.identity.oidc.issuer' --output text)
OIDC_PROVIDER=$(echo "$OIDC_ISSUER" | sed 's|https://||')
if [[ -z "${CLUSTER_ENDPOINT// }" ]] || [[ -z "${OIDC_PROVIDER// }" ]]; then
  echo "error: 클러스터 정보를 확인할 수 없습니다." >&2
  exit 1
fi

NODE_ROLE_NAME="KarpenterNodeRole-${CLUSTER_NAME}"
INSTANCE_PROFILE_NAME="KarpenterNodeInstanceProfile-${CLUSTER_NAME}"
CONTROLLER_ROLE_NAME="KarpenterControllerRole-${CLUSTER_NAME}"
CONTROLLER_POLICY_NAME="KarpenterControllerPolicy-${CLUSTER_NAME}"
CONTROLLER_POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${CONTROLLER_POLICY_NAME}"
NODE_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${NODE_ROLE_NAME}"
CONTROLLER_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${CONTROLLER_ROLE_NAME}"
SQS_QUEUE_NAME="karpenter-${CLUSTER_NAME}"

function ensure_policy_attachment() {
  local role_name="$1"
  local policy_arn="$2"
  if ! aws iam list-attached-role-policies --role-name "$role_name" --query 'AttachedPolicies[].PolicyArn' --output text | tr '\t' '\n' | grep -qx "$policy_arn" 2>/dev/null; then
    aws iam attach-role-policy --role-name "$role_name" --policy-arn "$policy_arn"
  fi
}

function ensure_instance_profile() {
  local profile_name="$1"
  local role_name="$2"
  if ! aws iam get-instance-profile --instance-profile-name "$profile_name" >/dev/null 2>&1; then
    aws iam create-instance-profile --instance-profile-name "$profile_name"
  fi
  if ! aws iam get-instance-profile --instance-profile-name "$profile_name" --query 'InstanceProfile.Roles[].RoleName' --output text | tr '\t' '\n' | grep -qx "$role_name" 2>/dev/null; then
    aws iam add-role-to-instance-profile --instance-profile-name "$profile_name" --role-name "$role_name"
  fi
}

function ensure_identity_mapping() {
  local mappings
  mappings=$(eksctl get iamidentitymapping --cluster "$CLUSTER_NAME" --region "$AWS_REGION" 2>/dev/null || true)
  if grep -q "$NODE_ROLE_ARN" <<<"$mappings"; then
    return
  fi
  eksctl create iamidentitymapping \
    --cluster "$CLUSTER_NAME" \
    --region "$AWS_REGION" \
    --arn "$NODE_ROLE_ARN" \
    --username "system:node:{{EC2PrivateDNSName}}" \
    --group system:bootstrappers \
    --group system:nodes
}

# 1. Ensure OIDC provider is associated
eksctl utils associate-iam-oidc-provider \
  --cluster "$CLUSTER_NAME" \
  --region "$AWS_REGION" \
  --approve >/dev/null

# 2. Create controller IAM policy if needed
if ! aws iam get-policy --policy-arn "$CONTROLLER_POLICY_ARN" >/dev/null 2>&1; then
  aws iam create-policy \
    --policy-name "$CONTROLLER_POLICY_NAME" \
    --policy-document "file://${IAM_DIR}/karpenter-controller-policy.json"
fi

# 3. Create controller role for the Karpenter service account
if ! aws iam get-role --role-name "$CONTROLLER_ROLE_NAME" >/dev/null 2>&1; then
  TMP_TRUST_POLICY=$(mktemp)
  cat <<EOF_TRUST > "$TMP_TRUST_POLICY"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/${OIDC_PROVIDER}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${OIDC_PROVIDER}:aud": "sts.amazonaws.com",
          "${OIDC_PROVIDER}:sub": "system:serviceaccount:karpenter:karpenter"
        }
      }
    }
  ]
}
EOF_TRUST
  aws iam create-role \
    --role-name "$CONTROLLER_ROLE_NAME" \
    --assume-role-policy-document "file://$TMP_TRUST_POLICY"
  rm -f "$TMP_TRUST_POLICY"
fi
ensure_policy_attachment "$CONTROLLER_ROLE_NAME" "$CONTROLLER_POLICY_ARN"

# 4. Create node role + instance profile
if ! aws iam get-role --role-name "$NODE_ROLE_NAME" >/dev/null 2>&1; then
  aws iam create-role \
    --role-name "$NODE_ROLE_NAME" \
    --assume-role-policy-document "file://${IAM_DIR}/karpenter-node-role-trust-policy.json"
fi
NODE_POLICIES=(
  arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
  arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy
  arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
  arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
)
for policy in "${NODE_POLICIES[@]}"; do
  ensure_policy_attachment "$NODE_ROLE_NAME" "$policy"
done
ensure_instance_profile "$INSTANCE_PROFILE_NAME" "$NODE_ROLE_NAME"

# 5. Allow nodes to join the cluster
ensure_identity_mapping

# 6. Create interruption queue if it does not exist
SQS_QUEUE_URL=$(aws sqs get-queue-url --queue-name "$SQS_QUEUE_NAME" --region "$AWS_REGION" --query 'QueueUrl' --output text 2>/dev/null || true)
if [[ -z "${SQS_QUEUE_URL// }" ]]; then
  SQS_QUEUE_URL=$(aws sqs create-queue --queue-name "$SQS_QUEUE_NAME" --region "$AWS_REGION" --query 'QueueUrl' --output text)
fi

# 7. Tag subnets & security groups for discovery
SUBNET_IDS=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" --query 'cluster.resourcesVpcConfig.subnetIds' --output text)
if [[ -n "${SUBNET_IDS// }" ]]; then
  for subnet_id in $SUBNET_IDS; do
    aws ec2 create-tags --region "$AWS_REGION" --resources "$subnet_id" --tags Key=karpenter.sh/discovery,Value="$CLUSTER_NAME"
  done
fi
SG_IDS=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" --query 'cluster.resourcesVpcConfig.securityGroupIds' --output text)
if [[ -n "${SG_IDS// }" ]]; then
  for sg_id in $SG_IDS; do
    aws ec2 create-tags --region "$AWS_REGION" --resources "$sg_id" --tags Key=karpenter.sh/discovery,Value="$CLUSTER_NAME"
  done
fi

# 8. Install Karpenter via Helm
helm repo add karpenter https://charts.karpenter.sh --force-update >/dev/null
helm repo update >/dev/null

helm upgrade --install karpenter karpenter/karpenter \
  --namespace karpenter \
  --create-namespace \
  --version "$KARPENTER_VERSION" \
  --set serviceAccount.create=true \
  --set serviceAccount.name=karpenter \
  --set serviceAccount.annotations."eks\\.amazonaws\\.com/role-arn"="$CONTROLLER_ROLE_ARN" \
  --set settings.aws.clusterName="$CLUSTER_NAME" \
  --set settings.aws.clusterEndpoint="$CLUSTER_ENDPOINT" \
  --set settings.aws.interruptionQueueName="$SQS_QUEUE_NAME" \
  --set settings.aws.defaultInstanceProfile="$INSTANCE_PROFILE_NAME"

cat <<EOF

Karpenter 설치가 완료되었습니다.
아래 명령으로 기본 AWSNodeTemplate/Provisioner를 배포할 수 있습니다:

  export CLUSTER_NAME="$CLUSTER_NAME"
  export AWS_ACCOUNT_ID="$AWS_ACCOUNT_ID"
  kubectl apply -f - < <(envsubst < "$MANIFEST_DIR/default-awsnodetemplate.yaml")
  kubectl apply -f "$MANIFEST_DIR/default-provisioner.yaml"

필요에 따라 manifests 디렉터리의 YAML을 수정한 뒤 적용하세요.
EOF
