#!/bin/bash

echo "=== Argo Rollouts 설치 ==="

echo "1. Argo Rollouts ns 생성"
kubectl create namespace argo-rollouts --dry-run=client -o yaml | kubectl apply -f -

echo "2. Argo Rollouts 설치"
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

echo "3. 설치 상태 확인"
sleep 10 && kubectl get pods -n argo-rollouts

echo ""
echo "CRD 확인:"
kubectl get crd | grep rollout

echo ""
echo "=== Argo Rollouts 설치 완료 ==="