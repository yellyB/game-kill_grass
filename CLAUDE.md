# Kill Grass - Godot 4.3 Idle Game

## 프로젝트 개요
풀을 베어서 돈을 모으는 방치형 모바일 게임. 플레이어가 이동하면 자동으로 범위 내 풀을 베고, 떨어진 코인을 수집하여 골드를 획득한다.

## 핵심 시스템

### 이동 방식
- 플레이어는 화면 중앙에 고정
- 월드(WorldRoot)가 플레이어 입력의 반대 방향으로 이동
- 배경은 플레이어를 따라다니며 무한하게 보임
- 입력: 키보드 (WASD/방향키), 터치 드래그, 가상 조이스틱 (모바일)

### 세션 시스템
- 세션 시간: 60초 (현재 개발용 10초, `main.gd` SESSION_TIME)
- 화면 상단 중앙에 남은 시간 표시, 10초 이하 빨간색
- 세션 종료 시 보너스 코인 +$100 ("세션 완료 보너스 +$100")
- 터치하여 메인 메뉴로 복귀
- 게임 중 "처음으로" 버튼으로 메뉴 복귀 가능 (확인 다이얼로그)

### 무한 맵 (청크 시스템)
- `grass_spawner.gd`: MultiMesh 기반 무한 풀 생성 (1 draw call)
- 풀 데이터는 Dictionary로 관리 (씬 인스턴스 없음)
- GPU 셰이더로 바람 흔들림 애니메이션 (`grass_sway.gdshader`)
- 청크 크기: 400x400
- 렌더 거리: 2 청크
- 플레이어 주변 청크만 로드, 멀어지면 언로드

### 풀 종류
| 종류 | 체력 | 드롭 | 재생시간 | 색상 | 등장 확률 |
|------|------|------|----------|------|-----------|
| 기본풀 | 4 | $1 | 22초 | 밝은 초록 | 등급 레벨 의존 |
| 강한풀 | 12 | $5 | 23초 | 청록색 | 등급 레벨 의존 |
| 완전 센풀 | 24 | $30 | 24초 | 어두운 청록 | 등급 레벨 의존 |
| 황금풀 | 60 | $100~500 | 25초 | 황금색 | 항상 2% |

### 풀 등장 확률 (풀 등급 업그레이드 기준)
- 황금풀: 모든 레벨에서 2% 고정
- Lv.0: 기본풀 100% → Lv.9: 기본풀 50%/강한풀 50%
- Lv.14: 강한풀 63%/완전 센풀 37% → Lv.27+: 완전 센풀 100%

### 코인 시스템
- 풀을 베면 해당 위치에 코인 생성 (WorldRoot 자식)
- 코인 색상: 브론즈($1~4), 실버($5~14), 골드($15+)
- 코인은 월드 좌표에 고정됨
- 자석 범위 내 접근 시 자동 끌려옴 (기본 범위 75)
- 30 거리 내에서 수집
- 수집 시 플로팅 텍스트 표시

### 무기 시스템
10단계 무기 업그레이드 (상세: `docs/무기정보.md`):
1. 낡은 낫 (single) - 기본, $0
2. 날 선 낫 (single) - $100
3. 무거운 낫 (single) - $180
4. 이중 낫 (double) - $324
5. 회전 예초낫 (spin) - $583
6. 제초 기계 (aura) - $1,050
7. 분쇄 예초기 (aura) - $1,890
8. 화염 제초기 (flame) - $3,400
9. 재앙 장치 (screen) - $5,400
10. 세계 정리자 (world) - $8,600

### 무기 비주얼
- 무기별 고유 외형 (scythe, spinner, machine, flamethrower, device, orb)
- 무기 텍스트 이미지: `resources/images/weapon/`
- 공격 애니메이션: 스윙, 회전, 펄스, 플래시 등
- 연속 애니메이션 (회전, 펄스, 불꽃 깜빡임 등)
- **중요**: 공격 애니메이션에서 스케일은 고정값(Vector2.ONE) 사용 (누적 방지)

### 업그레이드 시스템 (상세: `docs/업그레이드정보.md`)
- 비용 공식: `100 × 1.5^현재레벨`
- 풀 밀도: 최대 Lv.10, 셀 크기 감소로 풀 빽빽하게
- 수집 범위: 무제한, 레벨당 30% 증가
- 풀 등급: 무제한, 고급 풀 등장 확률 증가
- 풀 재생 속도: 최대 Lv.10, 레벨당 2초 감소

### 몬스터 시스템
- 7종 몬스터가 월드에 스폰 (`monster_spawner.gd`)
- 몬스터별 고유 스프라이트 (5프레임 애니메이션), 체력, 이동속도, 드롭 테이블
- 배회 AI: 이동/대기를 랜덤 반복
- 피격 시 빨간 플래시, 사망 시 확대→흔들림→페이드 연출
- 사망 시 드롭 테이블에 따라 아이템 드롭 (포물선 비행)
- 몬스터 종류: 슬라임, 멧돼지, 잔디 기사, 스포어 마도사, 잔디 골렘, 수정 사슴, 드래곤 배기가스
- 상세: `monster.md`

### 아이템 & 제작 시스템
- **재료 아이템** (16종): 몬스터 드롭으로 획득, `GameManager.inventory`에 저장
- **부품** (6종): 재료를 조합하여 제작하는 중간 아이템
  - 개념상 바퀴 🛞, 폭발하는 엔진 코어 🔥, 충격 무시 범퍼 🛡
  - 이세계 내비게이션 🧠, 강화 유리 모듈 🪟, 운전기사 👤
- **최종 아이템**: 이세계 트럭 🚛 (부품 6종을 모두 필요 수량만큼 모아 조립)
- 미발견 재료는 "?" 표시, 발견 후 이미지/이름 공개
- 제작 성공 시 즉시 저장 (`SaveManager.save_game()`)
- UI: `scripts/item_panel.gd` (재료 4열 → 부품 2열 → 최종 조립 카드)

### HUD 아이템 알림
- 아이템 획득 시 화면 우측 상단(돈 아래)에 아이템명 표시
- 1.5초 표시 후 0.5초간 페이드아웃
- 폰트 크기 72, 황금색, 검정 아웃라인

## 파일 구조

```
autoload/
  game_manager.gd    - 돈, 업그레이드, 인벤토리, 풀 데이터 관리
  weapon_manager.gd  - 무기 데이터 및 구매
  save_manager.gd    - 저장/불러오기
  session_manager.gd - 세션 관리 (시작/종료/메뉴 복귀)

scripts/
  main.gd            - 게임 세션 관리, 타이머, 세션 종료
  main_menu.gd       - 메인 메뉴 UI
  player.gd          - 플레이어 이동, 자동 공격, 무기 비주얼
  grass.gd           - 풀 동작 (개별 씬용)
  grass_spawner.gd   - MultiMesh 기반 청크 풀 생성/관리
  coin.gd            - 코인 수집, 자석 효과
  floating_text.gd   - 금액 표시 UI
  world_root.gd      - 월드 이동, 배경 처리
  hud.gd             - HUD 표시 + 아이템 획득 알림
  upgrade_panel.gd   - 업그레이드 패널 UI
  weapon_shop.gd     - 무기 상점 UI
  item_panel.gd      - 아이템/제작 패널 UI
  monster.gd         - 몬스터 동작, AI, 사망/드롭
  monster_spawner.gd - 몬스터 스폰 (7종, 가중치 기반)
  dropped_item.gd    - 드롭 아이템 (포물선 비행, 자석 수집)
  virtual_joystick.gd - 가상 조이스틱 (모바일)
  game_camera.gd     - 카메라

scenes/
  core/main.tscn     - 메인 게임 씬
  world/grass.tscn   - 풀 씬
  world/coin.tscn    - 코인 씬
  world/monster.tscn  - 몬스터 씬
  world/dropped_item.tscn - 드롭 아이템 씬
  ui/main_menu.tscn  - 메인 메뉴
  ui/hud.tscn        - HUD
  ui/upgrade_panel.tscn - 업그레이드 패널
  ui/weapon_shop.tscn   - 무기 상점
  ui/item_panel.tscn    - 아이템/제작 패널
  ui/virtual_joystick.tscn - 가상 조이스틱
  ui/floating_text.tscn - 플로팅 텍스트

resources/
  shaders/grass_sway.gdshader - 풀 흔들림 GPU 셰이더
  images/weapon/     - 무기 이미지 (1~10단계)
  images/monster/    - 몬스터 스프라이트 (7종, 각 5프레임)
  images/items/      - 드롭 아이템 이미지 (16종)

docs/
  기획서.md          - 전체 게임 기획서
  무기정보.md        - 무기 상세 정보
  업그레이드정보.md  - 업그레이드 상세 정보
```

## 좌표계 주의사항

WorldRoot가 이동하므로 좌표 변환 필요:
```gdscript
# 코인에서 플레이어 위치 계산 시
var player_local_pos = get_parent().to_local(player.global_position)

# 공격 범위 계산 시 (grass_spawner 로컬 좌표)
var local_attack_center = attack_center - grass_spawner.global_position
```

## 세이브 데이터 위치
macOS: `~/Library/Application Support/Godot/app_userdata/Kill Grass/savegame.json`

## 알려진 이슈 및 해결책

1. **코인이 플레이어 따라 움직임** → 코인을 WorldRoot 자식으로 추가
2. **플로팅 텍스트 값이 안 바뀜** → add_child() 후에 setup() 호출
3. **무기 스케일 누적** → 애니메이션에서 고정 스케일 값 사용
4. **풀 렌더링 성능** → MultiMesh + GPU 셰이더로 해결 (씬 인스턴스 제거)
5. **Tween "Target object freed" 경고** → `queue_free()` 대신 `remove_child()` + `queue_free()` 사용
6. **제작 중 UI 다중 갱신** → `_crafting` 플래그로 `inventory_changed` 시그널 억제
