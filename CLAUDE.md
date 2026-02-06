# Kill Grass - Godot 4.3 Idle Game

## 프로젝트 개요
풀을 베어서 돈을 모으는 방치형 모바일 게임. 플레이어가 이동하면 자동으로 범위 내 풀을 베고, 떨어진 코인을 수집하여 골드를 획득한다.

## 핵심 시스템

### 이동 방식
- 플레이어는 화면 중앙에 고정
- 월드(WorldRoot)가 플레이어 입력의 반대 방향으로 이동
- 배경은 플레이어를 따라다니며 무한하게 보임

### 무한 맵 (청크 시스템)
- `grass_spawner.gd`: 청크 기반 무한 풀 생성
- 청크 크기: 400x400
- 렌더 거리: 4 청크
- 플레이어 주변 청크만 로드, 멀어지면 언로드

### 풀 종류
| 종류 | 금액 | 체력 | 색상 | 확률 |
|------|------|------|------|------|
| 일반 풀 | 1원 | 1 | 밝은 초록 | 70% |
| 질긴 풀 | 5원 | 3 | 청록색 | 25% |
| 황금 풀 | 10원 | 2 | 황금색 | 5% |

### 코인 시스템
- 풀을 베면 해당 위치에 코인 생성 (WorldRoot 자식)
- 코인은 월드 좌표에 고정됨
- 플레이어 150 거리 내 접근 시 자석 효과로 끌려옴
- 30 거리 내에서 수집

### 콤보 시스템
- 풀을 벨 때마다 콤보 +1
- 1.5초 동안 베지 않으면 콤보 리셋
- 콤보 보너스: `int(코인값 × 콤보 × 0.03)` (3% per combo)
- 코인에 저장된 콤보는 **풀을 벤 시점**의 값 사용

### 플로팅 텍스트
- 코인 수집 시 표시
- 기본 금액: 노란색 "+X"
- 콤보 보너스: 초록색 "+Y" (보너스 있을 때만)
- **중요**: `setup()`은 `add_child()` 후에 호출해야 함 (@onready 변수 초기화 필요)

### 무기 시스템
10단계 무기 업그레이드:
1. 낡은 낫 (single) - 기본
2. 날 선 낫 (single)
3. 무거운 낫 (single)
4. 이중 낫 (double) - 2개 동시 공격
5. 회전 예초낫 (spin) - 연속 회전
6. 제초 기계 (aura) - 접근 시 피해
7. 분쇄 예초기 (aura)
8. 화염 제초기 (flame)
9. 재앙 장치 (screen) - 화면 전체
10. 세계 정리자 (world) - 맵 전체

### 무기 비주얼
- 무기별 고유 외형 (scythe, spinner, machine, flamethrower, device, orb)
- 무기별 공격 애니메이션
- 연속 애니메이션 (회전, 펄스, 불꽃 깜빡임 등)
- **중요**: 공격 애니메이션에서 스케일은 고정값(Vector2.ONE) 사용 (누적 방지)

## 파일 구조

```
autoload/
  game_manager.gd    - 돈, 콤보, 업그레이드 관리
  weapon_manager.gd  - 무기 데이터 및 구매
  save_manager.gd    - 저장/불러오기
  session_manager.gd - 세션 관리

scripts/
  player.gd          - 플레이어 이동, 공격, 무기 비주얼
  grass.gd           - 풀 동작, 코인 생성
  grass_spawner.gd   - 청크 기반 풀 생성
  coin.gd            - 코인 수집, 자석 효과
  floating_text.gd   - 금액 표시 UI
  world_root.gd      - 월드 이동, 배경 처리
  hud.gd             - HUD 표시

scenes/
  core/main.tscn     - 메인 게임 씬
  world/grass.tscn   - 풀 씬 (Polygon2D 블레이드)
  world/coin.tscn    - 코인 씬
  ui/                - UI 씬들
```

## 좌표계 주의사항

WorldRoot가 이동하므로 좌표 변환 필요:
```gdscript
# 코인에서 플레이어 위치 계산 시
var player_local_pos = get_parent().to_local(player.global_position)

# 코인 생성 시 위치
var spawn_pos = grass.position + grass_spawner.position
coin.position = spawn_pos  # WorldRoot 기준 로컬 좌표
```

## 세이브 데이터 위치
macOS: `~/Library/Application Support/Godot/app_userdata/Kill Grass/savegame.json`

## 알려진 이슈 및 해결책

1. **코인이 플레이어 따라 움직임** → 코인을 WorldRoot 자식으로 추가
2. **플로팅 텍스트 값이 안 바뀜** → add_child() 후에 setup() 호출
3. **무기 스케일 누적** → 애니메이션에서 고정 스케일 값 사용
4. **콤보 보너스가 이상함** → 코인에 풀 벤 시점의 콤보 저장
