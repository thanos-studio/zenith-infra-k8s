# News Chart

Argo Rollouts 기반 blue/green 배포로 `zenith-news` 워크로드를 배포하기 위한 Helm 차트입니다. 서비스의 active/preview 이중 서비스, ALB TargetGroupBinding, ExternalSecret 연동을 기본 제공하며 PDB/HPA/프로브 등의 안정성 설정을 모두 values에서 관리할 수 있습니다.

## 특징
- Argo Rollouts (blue/green) + active/preview Service 자동 생성
- ExternalSecret 연동으로 AWS Secrets Manager/Parameter Store 기반 구성값 주입
- TargetGroupBinding 리소드로 AWS ALB 연동

## 요구 사항
- Kubernetes >= 1.27
- Argo Rollouts CRD 설치 완료
- AWS Load Balancer Controller (TargetGroupBinding 사용 시)
- External Secrets Operator (secret 연동 시)

## 설치 예시
```bash
helm upgrade --install news ./news_chart -n zenith-news \
  -f news_chart/examples/example.vaules.yaml
```

## values 주요 항목
| 키 | 설명 |
| --- | --- |
| `namespace` | 리소스가 배포될 네임스페이스. 미지정 시 `--namespace` 값 사용 |
| `rollout.strategy.blueGreen.*` | blue/green 동작 옵션 (auto promotion 등) |
| `service.previewEnabled` | preview Service 생성 여부 |
| `externalSecret.*` | ExternalSecret 활성화 및 데이터 매핑 |
| `targetGroupBinding.*` | ALB TargetGroupBinding 설정 (사용 시 `targetGroupARN` 필수) |
| `pdb.*` | PodDisruptionBudget 설정 |
| `autoscaling.*` | HPA 관련 옵션 |

## 테스트
```bash
helm lint news_chart
```

## 배포 파이프라인 예시
Argo CD 사용 시 `argo/news/news.app.yaml`, `argo/news/news.values.yaml` 파일을 참조하면 동일 설정으로 선언적 배포가 가능합니다.
