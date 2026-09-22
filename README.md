# N-RPG / 누알피지 · 2026-09-22 안정화판

누알피지는 브라우저에서 사용하는 TRPG 세션 도구입니다.

## 함께 사용하는 방법

참여자 중 한 명만 설치·배포하면 됩니다. GM과 PL은 **동일한 누알피지 주소/서버**를 함께 사용합니다. 다른 참여자는 별도 설치가 필요 없습니다. 서로 독립적으로 설치한 서버끼리는 방과 초대코드가 공유되지 않으므로 사이트 주소와 초대코드를 함께 전달하세요.

## 신규 설치

`INSTALL.txt`와 `setup-helper.html`을 함께 열어 진행합니다. 마법사는 Supabase 설정과 Cloudflare 업로드용 앱 ZIP 생성을 안내합니다. 신규 설치 SQL은 앱 객체가 없는 새 전용 프로젝트에서만 실행하세요. 기존 설치본에는 실행하지 않습니다.

### Realtime 준비 확인

일부 신규 Supabase 프로젝트는 Realtime 관리 객체가 아직 준비되지 않았을 수 있습니다. 마법사 2단계 또는 `REALTIME_READINESS.sql`의 읽기 전용 진단을 먼저 실행하세요.

- `messages_ready`와 `send_ready`가 모두 true이면 설치 SQL을 실행합니다. `topic_present`와 함수 수는 참고 정보입니다. 현재 설치 SQL은 `realtime.topic()`을 직접 요구하지 않습니다.
- 필수 준비 확인에 실패하면 **같은 프로젝트의 Dashboard → Realtime → Inspector → 임시 채널 Listen → Listening 확인 → 연결 종료 → 재진단** 순서로 확인하세요. 채널 이름에는 개인정보를 넣지 않습니다.
- 이 연결 후 객체가 준비된 실환경 사례가 있지만, 모든 신규 프로젝트에 반드시 필요한 절차이거나 Supabase가 공식 보장한 초기화 방법은 아닙니다. 계속 누락되거나 연결에 실패하면 설치를 중단하고 프로젝트 상태를 확인하세요.
- Realtime 관리 스키마·함수를 수동 생성하거나 권한을 완화하지 마세요. 설치 사전검사를 제거하지 않습니다.

배포 후에는 GM 방의 `방 코드 → 설치 연결 진단`과 독립된 브라우저에서의 PL 참여를 확인하세요. 로비 표시만으로 설치 완료를 판단하지 않습니다.

## 기존 설치 업데이트

기존 프로젝트와 배포 주소를 유지하고, 먼저 DB와 배포 파일을 백업하세요. 설치된 버전에 따라 절차가 다릅니다.

|현재 설치본|적용 순서|
|---|---|
|공개 기준 커밋 `9046b2125a6ae7aeb3c2ada8e2c1afbef51ecb24`|[UPDATE-GUIDE.ko.md](UPDATE-GUIDE.ko.md): 백업 → `STABILIZATION_UPDATE.sql` → `jpp1e-assets` → 새 앱 ZIP을 기존 Pages에 배포 → 확인|
|2026-09-20 안정화판|[FOLLOWUP-UPDATE.ko.md](FOLLOWUP-UPDATE.ko.md): 백업 → `MAPSHEET_FIX_UPDATE.sql` → `jpp1e-assets` → 맵 숨김/재공개 시 시트 유지 확인. 앱 런타임은 동일하므로 앱 ZIP 교체 불필요|

다른 버전이나 커스텀 설치본은 지원 여부를 먼저 확인하세요. 버전 검사 오류가 나면 중단하고 검사문을 지우지 마세요. 기존 설치자는 신규 설치 SQL·새 프로젝트 생성·Auth·푸시/VAPID 설정을 반복하지 않습니다.

## 연결되지 않을 때 · Supabase Free 프로젝트

Supabase Free 프로젝트는 장기간 사용되지 않으면 일시정지될 수 있습니다. 설치자가 Dashboard에서 해당 프로젝트 상태를 확인하고, 필요한 경우 **현재 Dashboard 안내에 따라 다시 활성화**하세요. 준비가 끝나면 누알피지를 새로고침하고 연결 진단을 실행합니다. 참여자의 재설치나 앱 새로고침만으로 프로젝트가 활성화되지는 않습니다.

재활성화 가능 여부·기간·방법은 [Supabase 현재 안내](https://supabase.com/docs/guides/platform/free-project-pausing)와 프로젝트 화면을 확인하세요. 고정 기간을 전제로 하지 않습니다. 초기 설치 SQL 재실행으로 해결하지 마세요.

## 배포 파일

- `setup-helper.html`, `INSTALL.txt`: 신규 설치 마법사와 안내
- `readable-source/`: 마법사에 내장된 최종 런타임·SQL·Edge 원문과 자산
- 두 업데이트 안내 및 SQL: 위 설치 버전별 적용 경로
- `REALTIME_READINESS.sql`: 읽기 전용 준비 진단
- `TROUBLESHOOTING.md`: 오류 진단 안내

이번 후속 수정은 맵 숨김 시 PL 시트가 함께 사라지던 문제와 Realtime 준비 안내에 한정됩니다. 맵/시트 수정은 사용자 독립 Chrome 환경에서 실환경 재검증됐습니다. PL 입장 RPC는 변경하지 않았습니다.

Windows에서 ZIP 내 파일이 누락되면 ZIP 속성의 차단 해제 후 새 폴더에 풀어주세요. 비밀 키·관리 키·재접속 코드 등을 공개하지 마세요. 이용 조건은 `LICENSE`, 제3자 구성요소 고지는 `THIRD_PARTY_NOTICES.md`를 확인하세요.
