#!/bin/bash

# Argo install
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Change password
#kubectl exec -it -n argocd deployment/argocd-server -- /bin/bash
#argocd login localhost:8080
#argocd account update-password

# ArgoCD Ingress 배포
# kubectl apply -f ../argo/argo-ingress.yaml

# ArgoCD Patch
# 만약 ArgoCD Ingress가 삭제되지 않는 경우 아래 명령어로 실행
# kubectl patch ingress gj2025-argo-internal-nlb -n argocd -p '{"metadata":{"finalizers":[]}}' --type=merge

# ArgoCD 로그인 문제 해결
# kubectl patch configmap argocd-cm -n argocd --type merge -p '{"data":{"url":"<your-external-nlb-url>"}}'
# kubectl patch configmap argocd-cmd-params-cm -n argocd --type merge -p '{"data":{"server.insecure":"true"}}'
# kubectl rollout restart deployment/argocd-server -n argocd