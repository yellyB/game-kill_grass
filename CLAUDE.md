# Kill Grass - Godot 4.3 Idle Game

## 프로젝트 개요
풀을 베어서 돈을 모으는 방치형 모바일 게임. 플레이어가 이동하면 자동으로 범위 내 풀을 베고, 떨어진 코인을 수집하여 골드를 획득한다. 4개 월드를 해금하며 진행하고, 몬스터 드롭 재료로 이세계 트럭을 조립하는 것이 최종 목표.

## 핵심 시스템

### 이동 방식
- 플레이어는 화면 중앙에 고정
- 월드(WorldRoot)가 플레이어 입력의 반대 방향으로 이동
- 배경은 플레이어를 따라다니며 무한하게 보임
- 입력: 키보드 (WASD/방향키), 터치 드래그 (모바일)

### 세션 시스템
- 세션 시간: 60초 (`main.gd` SESSION_TIME)
- 화면 상단 중앙에 남은 시간 표시, 10초 이하 빨간색
- 세션 종료 시 BGM 페이드아웃 + 팡파레 효과음
- 터치하여 메인 메뉴로 복귀
- 게임 중 "처음으로" 버튼으로 메뉴 복귀 가능 (확인 다이얼로그)

### 월드 시스템
4개 월드, 각각 고유한 배경색/풀 색상/몬스터/BGM:
| 월드 | 이름 | 해금 비용 | 등장 몬스터 | 테마색 |
|------|------|-----------|-------------|--------|
| 0 | 슬라임 늪 | 무료 | 슬라임 | 어두운 초록 |
| 1 | 들판 | $3,000 | 멧돼지, 잔디 기사 | 따뜻한 갈색 |
| 2 | 마법의 숲 | $20,000 | 마도사, 수정 사슴 | 어두운 남보라 |
| 3 | 용의 봉우리 | $50,000 | 잔디 골렘, 드래곤 | 어두운 적갈색 |

- 해금 조건: 코인 + 이전 월드 상자에서 획득한 열쇠
- 월드별 풀 색상: `WORLD_GRASS_TINTS` (메시 꼭짓점) × `WORLD_GRASS_COLORS` (인스턴스별)
- 월드별 배경색: `world_root.gd` `WORLD_BG_COLORS`

### 열쇠 & 상자 시스템
- 각 월드에 상자 1개 스폰 (다음 월드 열쇠 드롭)
- 상자는 "monsters" 그룹에 소속 → 플레이어 자동공격으로 파괴
- 상자 파괴 → 열쇠(또는 아이템) 드롭 → 플레이어에게 비행 → 수집
- 마지막 월드(3)의 상자는 "졸음 약" 드롭 (최종 조립에 필요)
- 이미 열쇠를 보유하면 상자 미출현
- `CHEST_SPAWN_CHANCE = 1.0` (디버깅용 100%)

### 무한 맵 (청크 시스템)
- `grass_spawner.gd`: MultiMesh 기반 무한 풀 생성 (1 draw call)
- 풀 데이터는 Dictionary로 관리 (씬 인스턴스 없음)
- GPU 셰이더로 바람 흔들림 애니메이션 (`grass_sway.gdshader`)
- 청크 크기: 400x400, 렌더 거리: 2 청크
- 플레이어 주변 청크만 로드, 멀어지면 언로드
- 대칭 랜덤 오프셋으로 청크 경계 비가시화

### 풀 종류 (5종 + 황금풀)
| idx | 종류 | 체력 | 드롭 | 재생시간 | 색상 | 등장 확률 |
|-----|------|------|------|----------|------|-----------|
| 0 | 새싹 | 4 | $1 | 22초 | 밝은 초록 | 등급 레벨 의존 |
| 1 | 잔디 | 12 | $5 | 23초 | 청록색 | 등급 레벨 의존 |
| 2 | 여린풀 | 24 | $30 | 24초 | 어두운 청록 | 등급 레벨 의존 |
| 3 | 강한풀 | 48 | $80 | 25초 | 딥 블루 | 등급 레벨 의존 |
| 4 | 초강풀 | 96 | $200 | 26초 | 다크 블루 | 등급 레벨 의존 |
| 5 | 황금풀 | 160 | $100 | 25초 | 황금색 | 황금풀 확률 스킬 |

### 코인 시스템
- 풀을 베면 해당 위치에 코인 생성 (WorldRoot 자식)
- 코인 색상: 브론즈($1~4), 실버($5~14), 골드($15+)
- 자석 범위 내 접근 시 자동 끌려옴 (기본 범위 75)
- 수집 시 플로팅 텍스트 표시 (배치 합산)

### 무기 시스템
10단계 무기 업그레이드 (상세: `docs/무기정보.md`):
1. 나뭇가지 - 기본, $0, 공격력 1
2. 녹슨 식칼 - $50, 공격력 2
3. 피자 커터 - $350, 공격력 3
4. 전기 파리채 - $900, 공격력 4
5. 뜨거운 다리미 - $2,000, 공격력 5
6. 매우 화난 고양이 - $4,500, 공격력 7
7. 체인소 - $10,000, 공격력 9
8. 마법 지팡이 - $22,000, 공격력 10
9. 날개달린 선풍기 - $45,000, 공격력 11
10. 위성 레이저 제초기 - $90,000, 공격력 12

### 업그레이드 시스템 (상세: `docs/업그레이드정보.md`)
- 비용 공식: `100 * 1.8^현재레벨` (스킬별 추가 배율 적용)
- 풀 밀도: 최대 Lv.10, 셀 크기 감소로 풀 빽빽하게
- 풀 등급: 최대 Lv.8, 고급 풀 등장 확률 증가
- 풀 재생: 최대 Lv.2 (Lv.1=13초, Lv.2=4초)
- 풀 보상: 최대 Lv.6, 레벨당 40% 증가
- 패널티 감소: 최대 Lv.3, 몬스터 피격 시 코인 손실 감소
- 드롭률 증가: 최대 Lv.5, 기본 30%에서 최대 60%까지
- 황금풀 확률: 최대 Lv.5, 기본 0.02%에서 최대 1%까지

### 몬스터 시스템
- 7종 몬스터가 월드별로 스폰 (`monster_spawner.gd`)
- 몬스터별 고유 스프라이트 (5프레임 애니메이션), 체력, 이동속도, 드롭 테이블
- 배회 AI: 이동/대기를 랜덤 반복
- 피격 시 빨간 플래시 + 슬래시 효과음, 사망 시 확대->흔들림->페이드 + 사망 효과음
- 사망 시 드롭 테이블에 따라 아이템 드롭 (포물선 비행)
- 상세: `docs/monster.md`

### 아이템 & 제작 시스템
- **재료 아이템** (16종): 몬스터 드롭으로 획득, `GameManager.inventory`에 저장
- **부품** (6종): 재료를 조합하여 제작하는 중간 아이템
- **최종 아이템**: 이세계 트럭 (부품 6종 + 졸음 약 조립)
- 졸음 약은 아이템 목록에 표시되지 않음 (숨겨진 재료)
- 부품 6개 완성 시 최종 조립 해금, 졸음 약 없으면 힌트 표시
- 카드 색상: 주황(재료 부족) / 초록(제작 가능) / 초록+비활성(완료)
- 미발견 재료는 "?" 표시, 발견 후 이미지/이름 공개
- 제작 성공 시 효과음 재생 + 즉시 저장
- `truck_assembled` 플래그로 트럭 조립 완료 상태 저장

### 사운드 시스템
**효과음** (`resources/sounds/effect/`):
| 파일 | 트리거 | 적용 위치 |
|------|--------|-----------|
| grass_swoosh.wav | 풀 공격 | player.gd |
| pick_coin.wav | 코인 수집 | player.gd |
| monster_slash.wav | 몬스터 피격 | monster.gd |
| monster_death.wav | 몬스터 사망 | monster.gd |
| wood_box_break.wav | 상자 파괴 | chest.gd |
| pick_key.wav | 아이템/열쇠 수집 | dropped_item.gd |
| button_click.wav | 일반 버튼 클릭 | GameManager (공용) |
| confirm_button_click.wav | 확인/구매 버튼 | GameManager (공용) |
| upgrade_success.wav | 업그레이드/무기 강화 성공 | GameManager (공용) |
| unlock_world.wav | 월드 해금 | GameManager (공용) |
| item_craft_short_hammer.wav | 아이템 제작 | GameManager (공용) |
| end_session_fanfare.wav | 세션 종료 결과 화면 | main.gd |

**배경음** (`resources/sounds/`):
| 파일 | 재생 위치 |
|------|-----------|
| bgm_main.wav | 메인 메뉴 (루프) |
| bgm_world_1~4.wav | 월드별 BGM (1초 딜레이 후 루프, 세션 종료 시 페이드아웃) |

- 공용 SFX는 `GameManager`에 AudioStreamPlayer로 관리
- queue_free되는 노드의 효과음은 root에 부착하여 재생 보장

### HUD 아이템 알림
- 아이템 획득 시 화면 우측 상단(돈 아래)에 아이템명 표시
- 열쇠 획득 시 시안색 알림
- 1.5초 표시 후 0.5초간 페이드아웃

### 프롤로그 시스템
- 최초 실행 시 자동 재생되는 스토리 슬라이드쇼
- 5컷 이미지+텍스트 슬라이드, 탭으로 진행, 건너뛰기 가능
- `prologue_seen` 플래그로 1회만 표시 (SaveManager 연동)
- 슬라이드 3에서 화면 흔들림 효과

### 디버그 기능
메인 메뉴 하단에 디버그 버튼 (debug build only):
- 초기화: 모든 데이터 리셋
- +$100000: 돈 추가
- 아이템+10: 모든 재료 10개씩 추가

## 파일 구조

```
autoload/
  game_manager.gd    - 돈, 업그레이드, 인벤토리, 열쇠, SFX 관리
  weapon_manager.gd  - 무기 데이터 및 구매
  save_manager.gd    - 저장/불러오기
  session_manager.gd - 세션 관리 (시작/종료/메뉴 복귀)

scripts/
  main.gd            - 게임 세션 관리, 타이머, BGM, 세션 종료
  main_menu.gd       - 메인 메뉴 UI, 월드 선택, 메뉴 BGM
  player.gd          - 플레이어 이동, 자동 공격, 무기 비주얼, SFX
  grass_spawner.gd   - MultiMesh 기반 청크 풀 생성/관리, 월드별 풀 색상
  coin.gd            - 코인 수집, 자석 효과
  floating_text.gd   - 금액 표시 UI
  world_root.gd      - 월드 이동, 배경 처리, 월드별 배경색
  hud.gd             - HUD 표시 + 아이템/열쇠 획득 알림
  upgrade_panel.gd   - 업그레이드 패널 UI
  weapon_shop.gd     - 무기 상점 UI
  item_panel.gd      - 아이템/제작 패널 UI (재료->부품->최종 조립)
  monster.gd         - 몬스터 동작, AI, 사망/드롭
  monster_spawner.gd - 몬스터/상자 스폰 (월드별 몬스터 매핑)
  dropped_item.gd    - 드롭 아이템 (포물선 비행, 자석 수집, 열쇠/약 지원)
  chest.gd           - 상자 (파괴 시 열쇠/아이템 드롭)
  effects/lightning_effect.gd      - 슬라임 번개 이펙트
  effects/dust_cloud_effect.gd     - 멧돼지 먼지구름 이펙트
  effects/spark_effect.gd          - 잔디 기사 금속 스파크 이펙트
  effects/spore_effect.gd          - 마도사 포자 이펙트
  effects/crystal_shimmer_effect.gd - 수정 사슴 반짝임 이펙트
  effects/rock_debris_effect.gd    - 잔디 골렘 바위 파편 이펙트
  effects/fire_wisp_effect.gd      - 드래곤 화염 이펙트
  prologue.gd        - 프롤로그 슬라이드쇼
  info_panel.gd      - 정보 패널 UI
  pause_menu.gd      - 일시정지 메뉴
  virtual_joystick.gd - 가상 조이스틱 (미사용, 터치 드래그로 대체)
  game_camera.gd     - 카메라

scenes/
  core/main.tscn       - 메인 게임 씬
  core/player.tscn     - 플레이어 씬
  core/game_camera.tscn - 카메라 씬
  world/world_root.tscn     - 월드 루트
  world/grass_spawner.tscn  - 풀 스포너
  world/coin.tscn           - 코인
  world/monster.tscn        - 몬스터
  world/dropped_item.tscn   - 드롭 아이템
  world/chest.tscn          - 상자
  effects/lightning_effect.tscn      - 번개 이펙트 씬
  effects/dust_cloud_effect.tscn     - 먼지구름 이펙트 씬
  effects/spark_effect.tscn          - 금속 스파크 이펙트 씬
  effects/spore_effect.tscn          - 포자 이펙트 씬
  effects/crystal_shimmer_effect.tscn - 수정 반짝임 이펙트 씬
  effects/rock_debris_effect.tscn    - 바위 파편 이펙트 씬
  effects/fire_wisp_effect.tscn      - 화염 이펙트 씬
  ui/main_menu.tscn         - 메인 메뉴
  ui/hud.tscn               - HUD
  ui/upgrade_panel.tscn     - 업그레이드 패널
  ui/weapon_shop.tscn       - 무기 상점
  ui/item_panel.tscn        - 아이템/제작 패널
  ui/info_panel.tscn        - 정보 패널
  ui/pause_menu.tscn        - 일시정지 메뉴
  ui/virtual_joystick.tscn  - 가상 조이스틱 (미사용)
  ui/floating_text.tscn     - 플로팅 텍스트

resources/
  grass_data.gd                    - 풀 데이터 리소스 클래스
  shaders/grass_sway.gdshader      - 풀 흔들림 GPU 셰이더
  shaders/electric_glow.gdshader   - 전기 글로우 셰이더
  sounds/                          - 배경음 + 효과음
  images/weapon/                   - 무기 이미지 (1~10단계)
  images/monster/                  - 몬스터 스프라이트 (7종, 각 5프레임)
  images/items/                    - 드롭 아이템 이미지 (16종)

docs/
  기획서.md            - 전체 게임 기획서
  무기정보.md          - 무기 상세 정보
  업그레이드정보.md    - 업그레이드 상세 정보
  plan.md              - 전체 기획 방향
  detail_plan.md       - MVP 단계별 계획
  weapon.md            - 무기 컨셉/감성 설계
  monster.md           - 몬스터 종류/드롭/용도
  upgrade_tree.md      - 업그레이드 트리 설계
  monster_prompts.md   - 몬스터 스프라이트 생성 프롬프트
```

## 좌표계 주의사항

WorldRoot가 이동하므로 좌표 변환 필요:
```gdscript
# 코인에서 플레이어 위치 계산 시
var player_local_pos = get_parent().to_local(player.global_position)

# 공격 범위 계산 시 (grass_spawner 로컬 좌표)
var local_attack_center = attack_center - grass_spawner.global_position
```

## 세이브 데이터
- 위치: `~/Library/Application Support/Godot/app_userdata/Kill Grass/savegame.json`
- 저장 항목: money, upgrades, inventory, discovered_items, weapon_level, unlocked_worlds, owned_keys, truck_assembled, selected_world

## 알려진 이슈 및 해결책

1. **코인이 플레이어 따라 움직임** -> 코인을 WorldRoot 자식으로 추가
2. **플로팅 텍스트 값이 안 바뀜** -> add_child() 후에 setup() 호출
3. **무기 스케일 누적** -> 애니메이션에서 고정 스케일 값 사용
4. **풀 렌더링 성능** -> MultiMesh + GPU 셰이더로 해결 (씬 인스턴스 제거)
5. **Tween "Target object freed" 경고** -> `queue_free()` 대신 `remove_child()` + `queue_free()` 사용
6. **제작 중 UI 다중 갱신** -> `_crafting` 플래그로 `inventory_changed` 시그널 억제
7. **queue_free 후 사운드 재생** -> AudioStreamPlayer를 root에 부착, finished 시 queue_free
