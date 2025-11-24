# Zenith Infra on Kubernetes
Helm charts, Argo CD apps, and bootstrap manifests that describe how the Zenith platform is provisioned on top of Kubernetes with Argo Rollouts, External Secrets Operator, and the AWS Load Balancer Controller.

## Repository Layout
| Path | Description |
| --- | --- |
| `k8s/` | Cluster bootstrap assets (namespaces, AWS Load Balancer Controller, External Secrets Operator, Karpenter, Argo CD, Argo Rollouts). Subdirectories are ordered to match the recommended installation flow. |
| `news_chart/` | Opinionated Helm chart for the public Zenith News service (blue/green rollout, ExternalSecret + TargetGroupBinding enabled by default). |
| `zenith_chart/` | Reusable Helm chart for the Zenith API/Dashboard services. Mirrors the News chart but keeps most integrations optional. |
| `argo/` | Argo CD `Application` manifests plus pinned values files that render the charts in a GitOps workflow. |
| `news_chart/examples/`, `zenith_chart/examples/` | Sample `values.yaml` files that document common overrides per workload. |

## Components & Prerequisites
- Kubernetes 1.27+ cluster with Helm 3.13+ and kubectl access.
- AWS integrations: IAM roles for service accounts, AWS Load Balancer Controller (TargetGroupBinding CRD), and (optionally) Karpenter node provisioning.
- Argo Rollouts CRD installed (see `k8s/05_argo_rollouts/0_install_argo_rollouts.sh`).
- External Secrets Operator (ESO) installed and configured with access to AWS Secrets Manager/Parameter Store (`k8s/02_external_secrets_operator/`).
- Argo CD (CLI + controller) for GitOps-driven deployments (`k8s/04_argocd/`).

## Quick Start
1. **Bootstrap cluster addons**
   ```bash
   # 0) namespaces & shared resources
   kubectl apply -f k8s/00_inital

   # 1) AWS Load Balancer Controller (CRDs, IAM, Helm install)
   ./k8s/01_alb_ingress_controller/install.sh

   # 2) External Secrets Operator
   ./k8s/02_external_secrets_operator/1_install_external_secrets_operator.sh
   kubectl apply -f k8s/02_external_secrets_operator/2_pre_external_secrets.yaml

   # 3) (Optional) Karpenter capacity + IAM
   ./k8s/03_karpenter/1_install_karpenter.sh

   # 4) Argo CD and ingress
   ./k8s/04_argocd/1_install_argocd.sh
   kubectl apply -f k8s/04_argocd/2_argocd_ingress.yaml

   # 5) Argo Rollouts CRD/controller
   ./k8s/05_argo_rollouts/0_install_argo_rollouts.sh
   ```
   Adjust IAM/Helm parameters inside each script before running in your environment.

2. **Deploy with Helm (direct)**
   ```bash
   helm upgrade --install news ./news_chart \
     -n zenith-news -f news_chart/examples/example.values.yaml

   helm upgrade --install zenith-dashboard ./zenith_chart \
     -n zenith-dashboard -f zenith_chart/examples/dashboard.values.yaml
   ```
   Override the sample values with your image tags, TargetGroup ARNs, probes, and secret mappings.

3. **Adopt GitOps with Argo CD**
   ```bash
   argocd repo add https://github.com/thanos-studio/zenith-infra-k8s \
     --username <github-id> --password <token>

   argocd app create -f argo/news/news.app.yaml
   argocd app create -f argo/zenith/api.app.yaml
   argocd app create -f argo/zenith/dash.app.yaml
   ```
   Each `Application` renders the repository chart with the corresponding `argo/**.values.yaml` file; secrets, image tags, and ALB bindings are maintained declaratively via Git.

## Helm Chart Highlights
- **Argo Rollouts Blue/Green**: Both charts emit a `Rollout` object with active/preview services, optional auto-promotion, and scale-down delays that are configurable under `rollout.strategy.blueGreen`.
- **ExternalSecret Integration**: Enable with `externalSecret.enabled=true`. Provides templated `ExternalSecret` and wires the generated secret into the main container via `envFrom`.
- **AWS TargetGroupBinding**: Toggle using `targetGroupBinding.enabled`. When enabled, the chart emits the CR needed by the AWS Load Balancer Controller to register pods with an existing ALB target group.
- **Operational Guardrails**: Native support for HPA (`autoscaling.*`), PodDisruptionBudget (`pdb.*`), resource requests/limits, tolerations, and node selectors.

## Customizing Values
- Use the root `values.yaml` in each chart as the baseline and layer environment-specific overrides either via Helm CLI (`-f custom.values.yaml`) or Argo CD value files.
- `news_chart` ships with ExternalSecret and TargetGroupBinding enabled by default for the production workflow.
- `zenith_chart` keeps integrations optional so the same template can power the API (ClusterIP, no preview service) and Dashboard (public LoadBalancer) via different value files.
- Example knobs:
  - `service.previewEnabled=false` to disable preview services for workloads that do not use blue/green verification.
  - `externalSecret.data[]` to source credentials from AWS Secrets Manager/SSM.
  - `autoscaling.targetMemoryUtilizationPercentage` to enable HPA memory based scaling (set alongside CPU).

## Development & Validation
- Lint templates locally before pushing:
  ```bash
  helm lint news_chart
  helm lint zenith_chart
  ```
- Keep secrets and AWS identifiers out of the repository; place them inside External Secrets stores instead.
- For new workloads:
  1. Copy `zenith_chart/examples/*.values.yaml`.
  2. Adjust image, ports, scaling, secrets, and target groups.
  3. Create a matching Argo CD `Application` under `argo/<service>/`.

## Troubleshooting
- **Rollout stuck in preview**: check `kubectl argo rollouts get rollout <release>` and verify preview service endpoints are reachable; adjust `autoPromotionSeconds`.
- **ALB target group has no healthy targets**: ensure `targetGroupBinding.targetGroupARN` matches an existing group and that the service port aligns with the rollout container port.
- **Secrets missing**: confirm the ESO `ClusterSecretStore`/`SecretStore` referenced in `externalSecret.secretStoreRef` exists and has IAM permissions to fetch the remote keys.
