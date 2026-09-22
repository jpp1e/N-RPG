# Third-Party Notices

누알피지는 다음 오픈소스 라이브러리, 폰트 및 외부 서비스를 사용합니다.

## html2canvas

- 버전: 1.4.1
- 라이선스: MIT License
- 사용 범위: 브라우저 화면을 Canvas로 렌더링하여 PDF 및 백업 기능 구현
- 배포 시: 원 프로젝트의 저작권 및 MIT License 고지 유지
- 원 프로젝트: [niklasvh/html2canvas 1.4.1](https://github.com/niklasvh/html2canvas/tree/v1.4.1)

## jsPDF

- 버전: 2.5.1
- 라이선스: MIT License
- 사용 범위: 브라우저에서 PDF 파일 생성
- 배포 시: 원 프로젝트의 저작권 및 MIT License 고지 유지
- 원 프로젝트: [parallax/jsPDF 2.5.1](https://github.com/parallax/jsPDF/tree/v2.5.1)

## @supabase/supabase-js

- 버전: 2.57.4
- 라이선스: MIT License
- 사용 범위: 브라우저에서 Supabase Auth 및 관련 클라이언트 기능 사용, jpp1e-push Edge Function에서 Supabase 클라이언트 사용
- 배포 시: 원 프로젝트의 MIT License 및 저작권 고지 유지
- 원 프로젝트: [supabase/supabase-js 2.57.4](https://github.com/supabase/supabase-js/tree/v2.57.4)

## @supabase/server

- 버전: 1.5.3
- 라이선스: MIT License
- 사용 범위: jpp1e-assets Edge Function에서 Supabase 서버 기능 사용 (`jsr:@supabase/server@1.5.3`)
- 배포 시: 원 프로젝트의 MIT License 및 저작권 고지 유지
- 원 프로젝트: [@supabase/server 1.5.3 (JSR)](https://jsr.io/@supabase/server/1.5.3)

## web-push

- 버전: 3.6.7
- 라이선스: Mozilla Public License 2.0 (MPL-2.0)
- 사용 범위: Web Push / VAPID 알림 전송
- 형태: 패키지 의존성으로 사용
- 재배포 시: MPL-2.0이 적용되는 코드와 그 수정본에는 해당 라이선스 조건이 유지됩니다. 실행 형태로 배포할 때는 해당 소스 코드를 받을 수 있는 방법도 안내해야 합니다. MPL 코드가 포함되지 않은 별도 파일의 독립적인 자체 코드까지 자동으로 MPL-2.0이 적용되지는 않습니다. 자세한 조건은 [MPL-2.0 원문](https://www.mozilla.org/en-US/MPL/2.0/)과 [공식 FAQ](https://www.mozilla.org/en-US/MPL/2.0/FAQ/)를 확인하세요.
- 원 프로젝트: [web-push-libs/web-push 3.6.7](https://github.com/web-push-libs/web-push/tree/v3.6.7)

## Pretendard

- 라이선스: SIL Open Font License 1.1
- 사용 범위: 한국어 및 UI 표시용 웹폰트
- 배포 시: 폰트 파일을 재배포하는 경우 원 저작권 고지와 SIL OFL 1.1 전문을 함께 제공하고 해당 조건 유지
- 원 프로젝트: [orioncactus/pretendard](https://github.com/orioncactus/pretendard), [라이선스 원문](https://github.com/orioncactus/pretendard/blob/main/LICENSE)

## SUIT

- 라이선스: SIL Open Font License 1.1
- 사용 범위: UI 표시용 웹폰트
- 배포 시: 폰트 파일을 재배포하는 경우 원 저작권 고지와 SIL OFL 1.1 전문을 함께 제공하고 해당 조건 유지
- 원 프로젝트: [sun-typeface/SUIT](https://github.com/sun-typeface/SUIT), [라이선스 원문](https://github.com/sun-typeface/SUIT/blob/master/LICENSE)

## 외부 서비스

다음 항목은 오픈소스 코드 라이선스와 별도로 각 서비스 제공자의 이용약관이 적용됩니다.

### YouTube IFrame Player API

누알피지의 BGM 기능은 사용자가 지정한 YouTube 콘텐츠를 재생하기 위해 YouTube IFrame Player API를 사용할 수 있습니다.

YouTube 콘텐츠를 누알피지에서 기술적으로 재생할 수 있다는 사실은 해당 콘텐츠를 복제, 재배포, 방송 또는 상업적으로 사용할 권리를 부여하지 않습니다.

사용자는 자신의 콘텐츠 이용 방식이 YouTube 및 해당 콘텐츠 권리자의 조건을 준수하는지 확인해야 합니다.

### Supabase

누알피지는 설치자가 만든 Supabase 프로젝트를 통해 Database, Authentication, Storage, Realtime, Edge Functions 기능을 사용할 수 있습니다.

Supabase 호스팅 서비스의 이용에는 Supabase의 서비스 약관이 별도로 적용됩니다. Supabase의 오픈소스 SDK와 호스팅 서비스의 이용조건은 서로 구분됩니다.

### Cloudflare Pages

누알피지는 Cloudflare Pages에 올려 인터넷 주소로 사용할 수 있습니다.

Cloudflare Pages 이용에는 Cloudflare의 해당 서비스 약관이 적용됩니다.

### CDN

일부 프런트엔드 라이브러리는 공개 CDN을 통해 제공될 수 있습니다. CDN은 라이브러리 전달 수단이며 각 라이브러리 자체의 라이선스는 원 프로젝트의 라이선스를 따릅니다.

## 재배포 시 고지

누알피지와 함께 배포되거나 외부에서 불러오는 제3자 구성 요소에는 각 원 프로젝트의 저작권, 라이선스 및 이용 조건이 각각 적용됩니다. 자세한 조건은 각 원 프로젝트의 라이선스를 확인해 주세요.

이 문서는 구성 요소와 적용 조건을 안내하는 목록이며, 각 구성 요소의 저작권 고지와 라이선스 전문을 대신하지 않습니다. 재배포할 때는 원본에 포함된 고지와 라이선스 전문도 해당 조건에 맞게 유지해야 합니다.
