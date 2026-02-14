# 몬스터 스프라이트 시트 생성 프롬프트

## 공통 규칙

- **스타일**: 2D top-down 3/4 view, chibi proportions, thick dark outline, flat colors, mobile game art
- **배경**: transparent background (PNG with alpha). 배경에 바둑판 무늬나 흰색을 그리지 말 것. 캐릭터만 그리고 나머지는 완전히 비워둘 것.
- **사이즈**: 256x256 per frame
- **특수 효과 제외**: 번개, 화염, 포자, 발광, 연기 등 VFX는 이미지에 넣지 않음 → Godot에서 파티클/셰이더로 구현
- **일관성**: 같은 몬스터의 5프레임은 반드시 동일 seed/style reference 사용

### 5프레임 애니메이션 구성

모든 프레임은 기본 자세(Frame 1)에서 **아주 미세하게만** 변형. 1→2→3→4→5→1 루프로 자연스러운 숨쉬기/살아있는 느낌 연출.

| 프레임 | 포즈 | 변형 정도 |
|--------|------|-----------|
| 1 | 기본 자세 (neutral) | 기준 |
| 2 | 아래로 눌림 (squash) | 높이 ~15% 감소, 폭 ~10% 증가 |
| 3 | 왼쪽으로 기울임 | 5~8도 기울기 |
| 4 | 위로 늘어남 (stretch) | 높이 ~15% 증가, 폭 ~10% 감소 |
| 5 | 오른쪽으로 기울임 | 5~8도 기울기 |

**중요**: 각 프레임은 한눈에 봐도 차이가 보여야 함. 같은 캐릭터지만 확실히 다른 포즈. 색상과 디테일은 동일하게 유지.

### 프롬프트 구조

```
[공통 스타일] + [몬스터 외형 묘사] + [미세 변형 지시] + [제외 사항]
```

---

## 1. 번개 먹은 슬라임 (★)

**저장 경로:** `resources/images/monster/slime/1.png ~ 5.png`
**드롭 아이템:** 질긴 슬라임 조각 (70%), 번개 먹은 배터리 껍질 (30%)
**Godot VFX:** 노란색 번개 이펙트 (`lightning_effect.gd`)

**몸체 묘사 (VFX 제외):**
작고 둥근 젤리 몸체. 파란 보라빛 반투명 색상. 멍한 표정의 작고 동그란 눈 두 개. 몸 표면에 노란 줄무늬(번개 자국)가 있음. 단순하고 귀여운 형태.

### Frame 1 - Base
> 2D top-down 3/4 view game sprite, transparent background, thick dark outline, flat colors, chibi style, mobile game art. A small round slime creature. Translucent blue-purple jelly body with yellow streak patterns on the surface (lightning scars). Two tiny round eyes with a dazed expression. Neutral resting pose, perfectly round shape. No glow effects, no particles, no lightning bolts. Clean solid body only.

### Frame 2 - Squash
> 2D top-down 3/4 view game sprite, transparent background, thick dark outline, flat colors, chibi style, mobile game art. A small round slime creature. Translucent blue-purple jelly body with yellow streak patterns on the surface (lightning scars). Two tiny round eyes with a dazed expression. The body is visibly squashed down: 15% shorter and 10% wider, like a flattened oval being pressed from above. No glow effects, no particles, no lightning bolts. Clean solid body only.

### Frame 3 - Tilt Left
> 2D top-down 3/4 view game sprite, transparent background, thick dark outline, flat colors, chibi style, mobile game art. A small round slime creature. Translucent blue-purple jelly body with yellow streak patterns on the surface (lightning scars). Two tiny round eyes with a dazed expression. The entire body is tilted about 5-8 degrees to the left, leaning noticeably. No glow effects, no particles, no lightning bolts. Clean solid body only.

### Frame 4 - Stretch
> 2D top-down 3/4 view game sprite, transparent background, thick dark outline, flat colors, chibi style, mobile game art. A small round slime creature. Translucent blue-purple jelly body with yellow streak patterns on the surface (lightning scars). Two tiny round eyes with a dazed expression. The body is visibly stretched upward: 15% taller and 10% narrower, like a tall oval being pulled up. No glow effects, no particles, no lightning bolts. Clean solid body only.

### Frame 5 - Tilt Right
> 2D top-down 3/4 view game sprite, transparent background, thick dark outline, flat colors, chibi style, mobile game art. A small round slime creature. Translucent blue-purple jelly body with yellow streak patterns on the surface (lightning scars). Two tiny round eyes with a dazed expression. The entire body is tilted about 5-8 degrees to the right, leaning noticeably. No glow effects, no particles, no lightning bolts. Clean solid body only.

---

## 2. 과성장 멧돼지 (★★)

**저장 경로:** `resources/images/monster/boar/1.png ~ 5.png`
**드롭 아이템:** (미정)
**Godot VFX:** 이동 시 먼지 파티클, 돌진 시 속도선

**몸체 묘사 (VFX 제외):**
비정상적으로 큰 돌연변이 멧돼지. 짙은 갈색 거친 털. 등에 초록 이끼와 풀 패치. 큰 곡선형 엄니 두 개. 빨간 성난 눈. 과장된 근육질 체형, 다리는 옆으로 벌림.

### Frame 1 - Base
> 2D top-down 3/4 view game sprite, transparent background, thick dark outline, flat colors, chibi style, mobile game art. An oversized mutant boar. Muscular body with dark brown coarse fur. Patches of green moss and grass growing on its back. Two large curved tusks. Red angry eyes. Legs splayed outward, standing still. No glow effects, no particles. Clean solid body only.

### Frame 2 - Squash
> 2D top-down 3/4 view game sprite, transparent background, thick dark outline, flat colors, chibi style, mobile game art. An oversized mutant boar. Muscular body with dark brown coarse fur. Patches of green moss and grass growing on its back. Two large curved tusks. Red angry eyes. The body is visibly crouched down: 15% shorter, legs bent more, wider low stance as if about to charge. No glow effects, no particles. Clean solid body only.

### Frame 3 - Tilt Left
> 2D top-down 3/4 view game sprite, transparent background, thick dark outline, flat colors, chibi style, mobile game art. An oversized mutant boar. Muscular body with dark brown coarse fur. Patches of green moss and grass growing on its back. Two large curved tusks. Red angry eyes. The entire body leans about 5-8 degrees to the left, weight shifted noticeably. No glow effects, no particles. Clean solid body only.

### Frame 4 - Stretch
> 2D top-down 3/4 view game sprite, transparent background, thick dark outline, flat colors, chibi style, mobile game art. An oversized mutant boar. Muscular body with dark brown coarse fur. Patches of green moss and grass growing on its back. Two large curved tusks. Red angry eyes. The body is visibly raised up: 15% taller, chest puffed out, standing more upright. No glow effects, no particles. Clean solid body only.

### Frame 5 - Tilt Right
> 2D top-down 3/4 view game sprite, transparent background, thick dark outline, flat colors, chibi style, mobile game art. An oversized mutant boar. Muscular body with dark brown coarse fur. Patches of green moss and grass growing on its back. Two large curved tusks. Red angry eyes. The entire body leans about 5-8 degrees to the right, weight shifted noticeably. No glow effects, no particles. Clean solid body only.

---

## 3. 잔디 기사 (★★★)

**저장 경로:** `resources/images/monster/knight/1.png ~ 5.png`
**드롭 아이템:** (미정)
**Godot VFX:** 투구 내부 초록 발광 셰이더, 검 궤적 트레일

**몸체 묘사 (VFX 제외):**
풀과 식물 섬유로 엮인 인간형 기사. 압축된 초록 잎과 나무껍질 갑옷. 관절 사이로 작은 꽃과 잡초. 날카로운 풀잎 검을 들고 있음. T자 형태 투구, 투구 안은 어두움(빛 없음).

### Frame 1 - Base
> 2D top-down 3/4 view game sprite, transparent background, thick dark outline, flat colors, chibi style, mobile game art. A humanoid knight made of woven grass and plant fiber. Armor plates of compressed green leaves and bark. Small flowers and weeds sprouting from joints. Holds a sharpened grass blade sword in right hand. T-shaped helmet visor, dark inside. Standing upright, neutral pose. No glow effects, no particles. Clean solid body only.

### Frame 2 - Squash
> 2D top-down 3/4 view game sprite, transparent background, thick dark outline, flat colors, chibi style, mobile game art. A humanoid knight made of woven grass and plant fiber. Armor plates of compressed green leaves and bark. Small flowers and weeds sprouting from joints. Holds a sharpened grass blade sword in right hand. T-shaped helmet visor, dark inside. Crouching visibly: knees bent, 15% shorter, wider low stance. No glow effects, no particles. Clean solid body only.

### Frame 3 - Tilt Left
> 2D top-down 3/4 view game sprite, transparent background, thick dark outline, flat colors, chibi style, mobile game art. A humanoid knight made of woven grass and plant fiber. Armor plates of compressed green leaves and bark. Small flowers and weeds sprouting from joints. Holds a sharpened grass blade sword in right hand. T-shaped helmet visor, dark inside. The entire body leans 5-8 degrees to the left noticeably. No glow effects, no particles. Clean solid body only.

### Frame 4 - Stretch
> 2D top-down 3/4 view game sprite, transparent background, thick dark outline, flat colors, chibi style, mobile game art. A humanoid knight made of woven grass and plant fiber. Armor plates of compressed green leaves and bark. Small flowers and weeds sprouting from joints. Holds a sharpened grass blade sword in right hand. T-shaped helmet visor, dark inside. Standing taller: 15% more upright, sword arm raised slightly. No glow effects, no particles. Clean solid body only.

### Frame 5 - Tilt Right
> 2D top-down 3/4 view game sprite, transparent background, thick dark outline, flat colors, chibi style, mobile game art. A humanoid knight made of woven grass and plant fiber. Armor plates of compressed green leaves and bark. Small flowers and weeds sprouting from joints. Holds a sharpened grass blade sword in right hand. T-shaped helmet visor, dark inside. The entire body leans 5-8 degrees to the right noticeably. No glow effects, no particles. Clean solid body only.

---

## 4. 스포어 마도사 (★★★)

**저장 경로:** `resources/images/monster/mage/1.png ~ 5.png`
**드롭 아이템:** (미정)
**Godot VFX:** 부유 포자 파티클, 지팡이 끝 에너지 구슬 셰이더, 몸체 약간 상하 부유 오프셋

**몸체 묘사 (VFX 제외):**
버섯 마법사. 큰 보라+청록 점박이 버섯 갓을 모자처럼 씀. 낡은 잔디 섬유 로브. 뒤틀린 나무 지팡이 (끝에 빈 갈래 — 구슬 없음). 버섯 갓 아래 어두운 얼굴에 작은 눈 두 개.

### Frame 1 - Base
> 2D top-down 3/4 view game sprite, transparent background, thick dark outline, flat colors, chibi style, mobile game art. A mushroom mage creature. Large spotted mushroom cap hat in purple and teal. Wispy body in tattered grass-fiber robes. Holds a twisted wooden staff with forked empty tip in left hand. Two small eyes visible under the dark underside of mushroom cap. Floating pose with robes hanging down. No glow, no particles, no orbs. Clean solid body only.

### Frame 2 - Squash
> 2D top-down 3/4 view game sprite, transparent background, thick dark outline, flat colors, chibi style, mobile game art. A mushroom mage creature. Large spotted mushroom cap hat in purple and teal. Wispy body in tattered grass-fiber robes. Holds a twisted wooden staff with forked empty tip in left hand. Two small eyes visible under the dark underside of mushroom cap. Floating lower: 15% shorter, mushroom cap visibly flatter and wider. No glow, no particles, no orbs. Clean solid body only.

### Frame 3 - Tilt Left
> 2D top-down 3/4 view game sprite, transparent background, thick dark outline, flat colors, chibi style, mobile game art. A mushroom mage creature. Large spotted mushroom cap hat in purple and teal. Wispy body in tattered grass-fiber robes. Holds a twisted wooden staff with forked empty tip in left hand. Two small eyes visible under the dark underside of mushroom cap. The entire body tilts 5-8 degrees to the left noticeably, mushroom cap angled. No glow, no particles, no orbs. Clean solid body only.

### Frame 4 - Stretch
> 2D top-down 3/4 view game sprite, transparent background, thick dark outline, flat colors, chibi style, mobile game art. A mushroom mage creature. Large spotted mushroom cap hat in purple and teal. Wispy body in tattered grass-fiber robes. Holds a twisted wooden staff with forked empty tip in left hand. Two small eyes visible under the dark underside of mushroom cap. Floating higher: 15% taller, mushroom cap visibly more elongated and narrow. No glow, no particles, no orbs. Clean solid body only.

### Frame 5 - Tilt Right
> 2D top-down 3/4 view game sprite, transparent background, thick dark outline, flat colors, chibi style, mobile game art. A mushroom mage creature. Large spotted mushroom cap hat in purple and teal. Wispy body in tattered grass-fiber robes. Holds a twisted wooden staff with forked empty tip in left hand. Two small eyes visible under the dark underside of mushroom cap. The entire body tilts 5-8 degrees to the right noticeably, mushroom cap angled. No glow, no particles, no orbs. Clean solid body only.

---

## 5. 잔디 골렘 (★★★★)

**저장 경로:** `resources/images/monster/golem/1.png ~ 5.png`
**드롭 아이템:** (미정)
**Godot VFX:** 핵 발광 펄스 셰이더, 걸을 때 땅 진동 이펙트, 눈 발광

**몸체 묘사 (VFX 제외):**
압축된 흙, 돌, 두꺼운 잔디로 된 거대한 골렘. 빽빽한 초록 잔디가 몸을 털처럼 덮음. 군데군데 돌과 흙 노출. 가슴에 어두운 보라색 원형 핵 자리(빛 없이 색상만). 뿌리로 감싼 바위 주먹. 바위 얼굴에 작고 깊은 눈구멍.

### Frame 1 - Base
> 2D top-down 3/4 view game sprite, transparent background, thick dark outline, flat colors, chibi style, mobile game art. A massive golem of compacted earth, rocks, and thick grass. Dense green grass covers the body like fur, with exposed stone and dirt patches. Dark purple circular core socket in the chest (no glow, just dark purple color). Heavy boulder fists wrapped in roots. Small deep-set eye sockets in a rocky face. Standing upright, neutral pose. No glow, no particles. Clean solid body only.

### Frame 2 - Squash
> 2D top-down 3/4 view game sprite, transparent background, thick dark outline, flat colors, chibi style, mobile game art. A massive golem of compacted earth, rocks, and thick grass. Dense green grass covers the body like fur, with exposed stone and dirt patches. Dark purple circular core socket in the chest. Heavy boulder fists wrapped in roots. Small deep-set eye sockets in a rocky face. Hunching down visibly: 15% shorter, shoulders hunched, fists closer to the ground. No glow, no particles. Clean solid body only.

### Frame 3 - Tilt Left
> 2D top-down 3/4 view game sprite, transparent background, thick dark outline, flat colors, chibi style, mobile game art. A massive golem of compacted earth, rocks, and thick grass. Dense green grass covers the body like fur, with exposed stone and dirt patches. Dark purple circular core socket in the chest. Heavy boulder fists wrapped in roots. Small deep-set eye sockets in a rocky face. The entire body leans 5-8 degrees to the left noticeably. No glow, no particles. Clean solid body only.

### Frame 4 - Stretch
> 2D top-down 3/4 view game sprite, transparent background, thick dark outline, flat colors, chibi style, mobile game art. A massive golem of compacted earth, rocks, and thick grass. Dense green grass covers the body like fur, with exposed stone and dirt patches. Dark purple circular core socket in the chest. Heavy boulder fists wrapped in roots. Small deep-set eye sockets in a rocky face. Standing taller: 15% more upright, fists raised slightly. No glow, no particles. Clean solid body only.

### Frame 5 - Tilt Right
> 2D top-down 3/4 view game sprite, transparent background, thick dark outline, flat colors, chibi style, mobile game art. A massive golem of compacted earth, rocks, and thick grass. Dense green grass covers the body like fur, with exposed stone and dirt patches. Dark purple circular core socket in the chest. Heavy boulder fists wrapped in roots. Small deep-set eye sockets in a rocky face. The entire body leans 5-8 degrees to the right noticeably. No glow, no particles. Clean solid body only.

---

## 6. 수정 사슴 (★★★★)

**저장 경로:** `resources/images/monster/deer/1.png ~ 5.png`
**드롭 아이템:** (미정)
**Godot VFX:** 프리즘 무지개빛 셰이더, 뿔 끝 글로우, 걸을 때 잔상 트레일

**몸체 묘사 (VFX 제외):**
청백색 수정으로 된 우아한 사슴. 반투명한 결정질 몸체(밝은 하늘색~흰색). 들쭉날쭉한 수정 파편 뿔. 하얀 눈. 가늘고 긴 다리, 수정 발굽. 몸에 결정 면(facet) 패턴.

### Frame 1 - Base
> 2D top-down 3/4 view game sprite, transparent background, thick dark outline, flat colors, chibi style, mobile game art. An elegant deer made of pale blue-white crystal. Faceted crystalline body with visible flat planes and edges. Jagged crystal shard antlers. White calm eyes. Slender legs with crystal hooves. Standing still, neutral pose. No glow, no rainbow effects, no particles. Clean solid body with facet patterns only.

### Frame 2 - Squash
> 2D top-down 3/4 view game sprite, transparent background, thick dark outline, flat colors, chibi style, mobile game art. An elegant deer made of pale blue-white crystal. Faceted crystalline body with visible flat planes and edges. Jagged crystal shard antlers. White calm eyes. Slender legs with crystal hooves. Crouching visibly: legs bent, 15% shorter, head dipped down. No glow, no rainbow effects, no particles. Clean solid body with facet patterns only.

### Frame 3 - Tilt Left
> 2D top-down 3/4 view game sprite, transparent background, thick dark outline, flat colors, chibi style, mobile game art. An elegant deer made of pale blue-white crystal. Faceted crystalline body with visible flat planes and edges. Jagged crystal shard antlers. White calm eyes. Slender legs with crystal hooves. The entire body leans 5-8 degrees to the left noticeably. No glow, no rainbow effects, no particles. Clean solid body with facet patterns only.

### Frame 4 - Stretch
> 2D top-down 3/4 view game sprite, transparent background, thick dark outline, flat colors, chibi style, mobile game art. An elegant deer made of pale blue-white crystal. Faceted crystalline body with visible flat planes and edges. Jagged crystal shard antlers. White calm eyes. Slender legs with crystal hooves. Standing taller: neck extended, 15% taller, head raised high. No glow, no rainbow effects, no particles. Clean solid body with facet patterns only.

### Frame 5 - Tilt Right
> 2D top-down 3/4 view game sprite, transparent background, thick dark outline, flat colors, chibi style, mobile game art. An elegant deer made of pale blue-white crystal. Faceted crystalline body with visible flat planes and edges. Jagged crystal shard antlers. White calm eyes. Slender legs with crystal hooves. The entire body leans 5-8 degrees to the right noticeably. No glow, no rainbow effects, no particles. Clean solid body with facet patterns only.

---

## 7. 드래곤 배기가스 (★★★★★)

**저장 경로:** `resources/images/monster/dragon/1.png ~ 5.png`
**드롭 아이템:** (미정)
**Godot VFX:** 연기 파티클, 화염 파티클, 몸체 균열 발광 셰이더, 꼬리 연기 트레일

**몸체 묘사 (VFX 제외):**
뱀처럼 긴 드래곤 실루엣. 짙은 회색~검은색 몸체, 몸 표면에 주황-빨간 갈라진 균열 무늬(용암 패턴). 날카로운 뿔, 작은 날개. 주황색 눈. 가장자리는 불규칙하게 찢어진 형태(연기 느낌이지만 고체로 표현).

### Frame 1 - Base
> 2D top-down 3/4 view game sprite, transparent background, thick dark outline, flat colors, chibi style, mobile game art. A serpentine dragon with a dark gray-black body. Surface has orange-red crack patterns resembling lava veins. Sharp horns on the head, small tattered wings. Orange fierce eyes. Ragged torn edges on the body silhouette (smoke-like shape but drawn as solid). Coiled neutral pose. No smoke, no fire, no glow effects, no particles. Clean solid body with crack patterns only.

### Frame 2 - Squash
> 2D top-down 3/4 view game sprite, transparent background, thick dark outline, flat colors, chibi style, mobile game art. A serpentine dragon with a dark gray-black body. Surface has orange-red crack patterns resembling lava veins. Sharp horns on the head, small tattered wings. Orange fierce eyes. Ragged torn edges on the body silhouette. Coiled tighter: 15% more compact, body compressed lower. No smoke, no fire, no glow effects, no particles. Clean solid body with crack patterns only.

### Frame 3 - Tilt Left
> 2D top-down 3/4 view game sprite, transparent background, thick dark outline, flat colors, chibi style, mobile game art. A serpentine dragon with a dark gray-black body. Surface has orange-red crack patterns resembling lava veins. Sharp horns on the head, small tattered wings. Orange fierce eyes. Ragged torn edges on the body silhouette. The entire body sways 5-8 degrees to the left noticeably. No smoke, no fire, no glow effects, no particles. Clean solid body with crack patterns only.

### Frame 4 - Stretch
> 2D top-down 3/4 view game sprite, transparent background, thick dark outline, flat colors, chibi style, mobile game art. A serpentine dragon with a dark gray-black body. Surface has orange-red crack patterns resembling lava veins. Sharp horns on the head, small tattered wings. Orange fierce eyes. Ragged torn edges on the body silhouette. Uncoiled upward: 15% more expanded, head raised higher, wings spread slightly. No smoke, no fire, no glow effects, no particles. Clean solid body with crack patterns only.

### Frame 5 - Tilt Right
> 2D top-down 3/4 view game sprite, transparent background, thick dark outline, flat colors, chibi style, mobile game art. A serpentine dragon with a dark gray-black body. Surface has orange-red crack patterns resembling lava veins. Sharp horns on the head, small tattered wings. Orange fierce eyes. Ragged torn edges on the body silhouette. The entire body sways 5-8 degrees to the right noticeably. No smoke, no fire, no glow effects, no particles. Clean solid body with crack patterns only.

---

## Godot 구현 가이드

### 애니메이션 조합

```
기본 루프: Frame 1 → 2 → 3 → 4 → 5 → 1 (숨쉬기 + 미세 흔들림)
  - 눌림 → 왼쪽 기울임 → 늘어남 → 오른쪽 기울임 → 반복
  - 모든 상태(idle/이동)에서 동일한 루프 사용
  - 이동 시 sprite.flip_h로 좌우 반전만 추가
피격: 현재 프레임에서 Godot tween으로 흰색 플래시 + 넉백
사망: 현재 프레임에서 Godot tween으로 축소 + 페이드아웃
```

### VFX 구현 목록 (Godot)

| 몬스터 | 파티클 | 셰이더 |
|--------|--------|--------|
| 슬라임 | 전기 스파크 | 몸체 전기 글로우 |
| 멧돼지 | 돌진 먼지 | - |
| 기사 | - | 투구 내부 발광, 검 트레일 |
| 마도사 | 부유 포자 | 지팡이 에너지 구슬 |
| 골렘 | 걷기 진동 파편 | 핵 펄스 발광, 눈 발광 |
| 수정 사슴 | - | 프리즘 무지개, 뿔 글로우, 잔상 트레일 |
| 드래곤 | 연기, 화염 | 균열 발광, 꼬리 연기 트레일 |
