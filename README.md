# N-RPG / 누알피지

누알피지는 브라우저에서 사용할 수 있는 TRPG 세션 도구입니다.

GM과 플레이어가 온라인 방에 접속해 캐릭터와 세션 정보를 공유하고, 브라우저에서 세션을 진행할 수 있도록 제작되었습니다.

## 시작하기

처음 설치하는 경우 `setup-helper.html`을 실행하세요.

설치 마법사가 Supabase 프로젝트 설정부터 필요한 설치 과정을 순서대로 안내합니다. 화면의 안내와 `INSTALL.txt`를 함께 확인하면서 진행하는 것을 권장합니다.

설치 과정에서는 새 전용 Supabase 프로젝트를 사용하세요. 설치 마법사에 포함된 clean-install SQL은 기존 누알피지 데이터베이스의 업그레이드용이 아닙니다.

## 룰 시스템

누알피지는 특정 상용 TRPG 룰 시스템을 내장하지 않는 범용 세션 도구입니다. 판정이 필요한 경우 자유 주사위 기능을 사용하고, 각 테이블의 룰은 사용자가 직접 운용합니다.

## 설치

1. `INSTALL.txt`를 열어 둡니다.
2. `setup-helper.html`을 브라우저에서 실행합니다.
3. 안내에 따라 Supabase 프로젝트를 생성하고 설정합니다.
4. 설치 마법사가 제공하는 SQL을 Supabase SQL Editor에서 실행합니다.
5. 이후 화면의 안내에 따라 필요한 설정을 완료합니다.
6. 설치 마법사에서 Cloudflare 업로드용 ZIP을 생성합니다.
7. 생성된 파일을 안내된 배포 절차에 따라 업로드합니다.

설치가 완료되면 배포된 누알피지 페이지에 접속해 로비가 정상적으로 표시되는지 확인하세요.

## 이미 설치한 누알피지 업데이트하기

이미 설치를 완료한 사용자는 Supabase 프로젝트를 새로 만들거나 설치 SQL을 다시 실행하지 않습니다. 기존 방, 캐릭터, 로그 등의 데이터는 그대로 유지됩니다.

1. 최신 `setup-helper.html`을 다운로드해 브라우저에서 실행합니다.
2. 기존 누알피지에서 사용하던 Supabase `Project URL`과 `Publishable Key`를 설치 마법사 첫 입력란에 그대로 입력합니다.
3. 신규 설치용 Supabase SQL, Auth, Edge Function, VAPID 설정 단계는 다시 실행하지 않습니다.
4. 설치 마법사의 `Cloudflare 업로드 ZIP 만들기` 버튼으로 최신 `누알피지_Cloudflare_업로드.zip`을 생성합니다.
5. Cloudflare Dashboard에서 기존 누알피지가 올라가 있는 **같은 Pages 프로젝트**를 엽니다. 새 Pages 프로젝트를 만들지 않습니다.
6. 기존 프로젝트에서 `Create a new deployment`를 선택하고, 생성한 ZIP을 **Production** 배포로 업로드합니다.
7. 기존에 사용하던 누알피지 주소로 접속해 업데이트가 반영되었는지 확인합니다.

이 업데이트 방식은 설치 마법사로 처음 설치한 누알피지의 공통 업데이트 절차입니다. `config.js`는 기존 Project URL과 Publishable Key로 새로 생성되므로 별도로 수정할 필요가 없습니다.

## Windows 사용자 주의사항

Windows에서는 인터넷에서 받은 ZIP 파일 내부의 일부 JavaScript 파일을 보안 기능이 차단하는 경우가 있습니다.

압축을 푼 뒤 파일이 누락되거나 누알피지에서 설치 설정 오류가 나타난다면, 원본 ZIP 파일을 우클릭한 뒤 `속성`에서 `차단 해제`를 적용하고 새 폴더에 다시 압축을 풀어주세요.

## 오류가 발생했을 때

먼저 `TROUBLESHOOTING.md`를 확인해주세요.

AI에게 오류 진단을 요청하는 경우 다음 자료를 함께 제공하면 원인 파악에 도움이 됩니다.

- 실제 오류 메시지
- 브라우저 개발자 도구 Console에 표시된 오류
- 현재 사용 중인 누알피지 파일
- `TROUBLESHOOTING.md`

Supabase의 secret key, service-role key, VAPID private key, 데이터베이스 비밀번호 등 비밀값은 공개하거나 다른 사람에게 전달하지 마세요.

## 배포 파일

- `setup-helper.html` : 누알피지 설치 마법사
- `INSTALL.txt` : 설치 안내
- `TROUBLESHOOTING.md` : 오류 진단 및 확인된 해결 사례
- `SHA256SUMS.txt` : 배포 파일 무결성 확인용 체크섬
- `LICENSE` : 라이선스
- `THIRD_PARTY_NOTICES.md` : 제3자 구성요소 및 라이선스 고지

## 라이선스

이 프로젝트의 이용 조건은 `LICENSE`를 확인해주세요.

제3자 구성요소에 관한 내용은 `THIRD_PARTY_NOTICES.md`를 확인해주세요.
