# Karpenter 설치 가이드

1. `k8s/03_karpenter/1_install_karpenter.sh` 실행 후 Region, Cluster name, 설치 버전을 입력합니다. 스크립트는 IAM Role/Policy, Instance Profile, SQS Queue, Subnet/SecurityGroup 태깅 및 Helm Chart 배포를 자동화합니다.
2. 설치가 끝난 뒤 `CLUSTER_NAME`과 `AWS_ACCOUNT_ID` 환경 변수를 설정하고 아래 명령으로 기본 매니페스트를 적용하세요.

```bash
export CLUSTER_NAME=<eks-cluster-name>
export AWS_ACCOUNT_ID=<aws-account-id>
kubectl apply -f - < <(envsubst < k8s/03_karpenter/manifests/default-awsnodetemplate.yaml)
kubectl apply -f k8s/03_karpenter/manifests/default-provisioner.yaml
```

매니페스트는 예시 값이므로 리전, 서브넷, 요구 컴퓨팅 스펙에 맞게 수정 후 사용하세요.
