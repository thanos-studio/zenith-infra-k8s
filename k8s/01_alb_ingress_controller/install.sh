#!/bin/bash

read -p "region : " region
read -p "vpc id : " vpc_id
read -p "cluster name : " cluster_name
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)

# 1. Create IAM policy for ALB Ingress Controller
aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam-policy.json

# Connect IAM Role and IRSA
eksctl create iamserviceaccount \
  --cluster $cluster_name \
  --namespace kube-system \
  --name aws-load-balancer-controller \
  --attach-policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve

# Install ALB Ingress Controller CRD
kubectl apply -f crds.yaml

# Install ALB Ingress Controller via Helm
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm upgrade -i aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$cluster_name \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=$region \
  --set vpcId=$vpc_id \
  --set enableServiceMutatorWebhook=false