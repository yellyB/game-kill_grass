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

## 파일 구조

```
autoload/
  game_manager.gd    - 돈, 업그레이드, 풀 데이터 관리
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
  hud.gd             - HUD 표시
  upgrade_panel.gd   - 업그레이드 패널 UI
  weapon_shop.gd     - 무기 상점 UI
  virtual_joystick.gd - 가상 조이스틱 (모바일)
  game_camera.gd     - 카메라

scenes/
  core/main.tscn     - 메인 게임 씬
  world/grass.tscn   - 풀 씬
  world/coin.tscn    - 코인 씬
  ui/main_menu.tscn  - 메인 메뉴
  ui/hud.tscn        - HUD
  ui/upgrade_panel.tscn - 업그레이드 패널
  ui/weapon_shop.tscn   - 무기 상점
  ui/virtual_joystick.tscn - 가상 조이스틱
  ui/floating_text.tscn - 플로팅 텍스트

resources/
  shaders/grass_sway.gdshader - 풀 흔들림 GPU 셰이더
  images/weapon/     - 무기 이미지 (1~10단계)

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
