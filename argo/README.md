# Argo CD Apps

이 디렉터리는 Zenith 인프라의 Helm 차트를 Argo CD로 배포하기 위한 Application 매니페스트와 chart values를 보관합니다.

## 구조
```
argo/
├── news/
│   ├── news.app.yaml       # news_chart를 배포하는 Argo Application
│   └── news.values.yaml    # news_chart에 적용할 Helm values
└── zenith/
    ├── api.app.yaml        # zenith_chart (API 프로파일)
    ├── api.values.yaml
    ├── dash.app.yaml       # zenith_chart (Dashboard 프로파일)
    └── dash.values.yaml
```

## 사용 방법
1. 먼저 Argo CD에 Git repo가 private인 경우 인증 정보를 등록합니다.
   ```bash
   argocd repo add https://github.com/thanos-studio/zenith-infra-k8s \
     --username <github-id> --password <token>
   ```
2. 각 앱을 생성합니다.
   ```bash
   argocd app create -f argo/news/news.app.yaml
   argocd app create -f argo/zenith/api.app.yaml
   argocd app create -f argo/zenith/dash.app.yaml
   ```
3. 동기화 및 상태 확인
   ```bash
   argocd app sync news
   argocd app get news
   ```

## values 커스터마이징
- `argo/news/news.values.yaml`, `argo/zenith/*.values.yaml` 파일을 수정해 이미지 태그, TargetGroup ARN, secret 매핑 등을 환경에 맞게 조정합니다.
- Argo CD는 해당 파일을 기준으로 Helm 렌더링을 수행하므로 values만 수정해도 배포 파이프라인 전체가 업데이트됩니다.

## 주의 사항
- ExternalSecret/TargetGroupBinding 등을 사용하려면 해당 CRD와 컨트롤러가 클러스터에 설치되어 있어야 합니다.
- 프로젝트별 네임스페이스는 Argo CD `syncPolicy.syncOptions`에 `CreateNamespace=true`가 설정되어 있으므로, 사전 생성 없이도 앱 생성 시 자동으로 만들어집니다.
