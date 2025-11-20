# Zenith Chart

Zenith 플랫폼의 Dashboard/API 등 다양한 워크로드를 배포하기 위한 범용 Helm 차트입니다. news_chart와 동일한 구조를 유지하면서도 다양한 values 파일을 통해 서비스별 요구사항(서비스 타입, TargetGroupBinding, ExternalSecret, 노드 셀렉터 등)을 쉽게 조정할 수 있습니다.

## 특징
- Argo Rollouts blue/green 배포
- active/preview Service 자동 구성

## 요구 사항
- Kubernetes >= 1.27
- Argo Rollouts CRD
- AWS Load Balancer Controller (ALB 연동 시)
- External Secrets Operator (secret 연동 시)

## 설치 예시
```bash
helm upgrade --install zenith-dashboard ./zenith_chart -n zenith-dashboard \
  -f zenith_chart/examples/dashboard.values.yaml
```

## values 주요 항목
| 키 | 설명 |
| --- | --- |
| `service.type` | ClusterIP/LoadBalancer 등 서비스 타입 |
| `service.previewEnabled` | blue/green preview Service 생성 여부 |
| `rollout.strategy.blueGreen.*` | Argo Rollout 전략 옵션 |
| `externalSecret.*` | ExternalSecret 설정 (enabled=false 시 생성 안됨) |
| `targetGroupBinding.*` | ALB TargetGroupBinding 설정 |
| `autoscaling.*` | HPA 설정 |
| `pdb.*` | PodDisruptionBudget 설정 |

## 테스트
```bash
helm lint zenith_chart
```

## Argo CD 연동
`argo/zenith/api.app.yaml`, `argo/zenith/dash.app.yaml` 등 선언적 Argo CD Application 정의를 참고하면 동일한 패턴으로 프로젝트별 배포를 구성할 수 있습니다.
