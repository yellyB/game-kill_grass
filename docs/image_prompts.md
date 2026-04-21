# 이미지 생성 프롬프트 모음

## 슬라임 스프라이트 시트

### 설정
- 그리드: 4x2 (4열 2행)
- 프레임 크기: 256x256px
- 총 이미지 크기: 1024x512px
- 배경: 투명 (PNG with alpha)

### 프레임 구성
| # | 위치 | 용도 | 설명 |
|---|------|------|------|
| 1 | Row1-1 | idle 기본 | 둥근 기본 형태 |
| 2 | Row1-2 | 왼쪽 기울임 | 5도 왼쪽 기울기 |
| 3 | Row1-3 | idle 기본 | 1번과 동일 |
| 4 | Row1-4 | 오른쪽 기울임 | 5도 오른쪽 기울기 |
| 5 | Row2-1 | 피격 찌그러짐 | >< 눈, 입 벌림, 30% 납작 |
| 6 | Row2-2 | 피격 반동 | 어질어질한 눈, 복귀 |
| 7 | Row2-3 | (빈칸) | |
| 8 | Row2-4 | (빈칸) | |

### 애니메이션 시퀀스
- idle/걷기: 1 → 2 → 1 → 4 → (반복)
- 피격: 5 → 6 → idle 복귀

### 프롬프트

> Sprite sheet of a cute slime monster for a 2D mobile idle game.
>
> The sprite sheet contains 8 frames arranged in a 4x2 grid (4 columns, 2 rows). Each frame is 256x256 pixels, so the total image size is 1024x512 pixels. Transparent background (PNG with alpha). Frames are evenly spaced with no gaps or overlap.
>
> CRITICAL — Centering and Separation: Every frame's character must be fully contained within its 256x256 cell with at least 30 pixels of padding on ALL sides (left, right, top, bottom). No part of the character should touch or extend beyond any cell edge. Characters must NOT bleed into adjacent cells. Each frame must be completely independent and isolated within its own cell. Draw each character small enough to fit comfortably inside the cell with clear empty space around it.
>
> Character design: A small, round jelly slime creature. Medium blue-purple translucent body — not too dark, not too pale. A balanced violet-blue tone that is semi-transparent and glossy, bright enough that black eyes are clearly visible against it. Glossy gel-like surface with a white highlight/reflection spot on top. Yellow jagged streak patterns across the body (lightning scars). Two small solid black round eyes with a dazed, sleepy expression. Tiny pink blush marks under each eye. Thick dark outline. Chibi proportions, flat cel-shaded colors, mobile game art style. 3/4 top-down view.
>
> Row 1 (Frames 1-4): Gentle wobbling walk animation loop (1→2→3→4→1):
> - Frame 1 (Neutral): Default round dome shape at rest. Perfectly symmetrical, sitting on the ground.
> - Frame 2 (Slight lean left): Body leans very slightly to the left, about 5 degrees only. The left side is just barely wider. A very subtle, gentle weight shift. Almost the same as frame 1 but with a tiny leftward tilt.
> - Frame 3 (Neutral): Same as frame 1. Back to center, perfectly round and symmetrical.
> - Frame 4 (Slight lean right): Body leans very slightly to the right, about 5 degrees only. Mirror of frame 2. A very subtle, gentle weight shift. Almost the same as frame 1 but with a tiny rightward tilt.
>
> Row 2 (Frames 5-6: Hit reaction, Frames 7-8: empty):
> - Frame 5 (Hit squash): Body violently squashed — about 30% shorter and 25% wider than neutral. Eyes squeezed shut tight (><), mouth open in a small "o" shape. Pained, shocked expression. Flattened as if smacked from above.
> - Frame 6 (Hit rebound): Body snaps back to roughly neutral height. Eyes still scrunched with a dazed/dizzy look. Slight wobble shape. Recovering from the hit.
> - Frames 7-8: Leave completely empty (transparent).
>
> Important: The wobble in frames 1-4 should be very subtle — the slime should look almost the same in all four idle frames, with only a barely noticeable gentle sway. All frames must have identical medium blue-purple colors, lightning scar patterns, and art style. Frames 1-4 share the same dazed/sleepy face. Frames 5-6 have a pained/shocked face. No VFX — no glow, no lightning bolts, no particles. Clean solid body only.

---

## 공통 스프라이트 시트 규칙

모든 몬스터는 아래 동일한 형식을 따릅니다:

- **그리드**: 4x2 (4열 2행), 총 8칸
- **프레임 크기**: 256x256px / **총 이미지**: 1024x512px
- **배경**: 투명 (PNG with alpha)
- **패딩**: 모든 프레임 셀 내 30px 이상 여백, 잘림 없을 것
- **중요**: 캐릭터는 반드시 각 셀 안에 완전히 들어가야 함. 인접 셀로 넘치면 안 됨
- **Row 1 (1-4)**: idle 애니메이션 (기본 → 왼쪽 기울임 → 기본 → 오른쪽 기울임)
- **Row 2 (5-6)**: 피격 애니메이션, **(7-8)**: 빈칸
- **idle 기울기**: 5도 (미세한 흔들림)
- **피격 Frame 5**: 30% 납작 + 25% 넓어짐, 고통스러운 표정 (><), 입 벌림
- **피격 Frame 6**: 원래 높이로 복귀, 어질어질한 표정
- **스타일**: 2D top-down 3/4 view, thick dark outline, flat cel-shaded colors, chibi proportions, mobile game art
- **VFX 제외**: 발광, 파티클, 연기, 화염 등은 이미지에 넣지 않음

---

## 멧돼지 스프라이트 시트

### 프롬프트

> Sprite sheet of an oversized mutant boar monster for a 2D mobile idle game.
>
> The sprite sheet contains 8 frames arranged in a 4x2 grid (4 columns, 2 rows). Each frame is 256x256 pixels, so the total image size is 1024x512 pixels. Transparent background (PNG with alpha). Frames are evenly spaced with no gaps or overlap.
>
> CRITICAL — Centering and Separation: Every frame's character must be fully contained within its 256x256 cell with at least 30 pixels of padding on ALL sides (left, right, top, bottom). No part of the character should touch or extend beyond any cell edge. Characters must NOT bleed into adjacent cells. Each frame must be completely independent and isolated within its own cell. Draw each character small enough to fit comfortably inside the cell with clear empty space around it.
>
> Character design: An oversized mutant boar. Muscular body with dark brown coarse fur. Patches of green moss and grass growing on its back and shoulders. Two large curved tusks protruding from the mouth. Red angry eyes. Exaggerated muscular build with legs splayed outward. Thick dark outline. Chibi proportions, flat cel-shaded colors, mobile game art style. 3/4 top-down view.
>
> Row 1 (Frames 1-4): Stomping walk animation loop (1→2→3→4→1). The boar always faces the same direction (forward/front-facing) in all frames. Only the legs and body height change to create a heavy stomping walk:
> - Frame 1 (Neutral): Standing still, front-facing. Legs splayed, body at normal height.
> - Frame 2 (Left stomp): Left front leg raised slightly, right front leg planted. Body dips down very slightly on the right side (~5%). A heavy, lumbering step. Face still looking straight forward.
> - Frame 3 (Neutral): Same as frame 1. Both legs planted, body level. Passing through neutral.
> - Frame 4 (Right stomp): Right front leg raised slightly, left front leg planted. Body dips down very slightly on the left side (~5%). Mirror leg pose of frame 2. Face still looking straight forward.
>
> Row 2 (Frames 5-6: Hit reaction, Frames 7-8: empty):
> - Frame 5 (Hit squash): Body crouches down violently — about 30% shorter and 25% wider. Eyes squeezed shut tight in pain, mouth open showing tusks. Pained expression. Legs buckled, flattened as if slammed from above. Still facing forward.
> - Frame 6 (Hit rebound): Body snaps back to roughly neutral height. Eyes still scrunched with a dazed/stunned look. Still facing forward. Recovering from the hit.
> - Frames 7-8: Leave completely empty (transparent).
>
> Important: The boar must face the SAME direction (front-facing) in ALL 6 frames. Never show the boar turning or looking left/right. All frames must have identical dark brown fur colors, moss patches, tusks, and art style. Frames 1-4 share the same angry face. Frames 5-6 have a pained face. No glow effects, no dust, no particles. Clean solid body only.

---

## 잔디 기사 스프라이트 시트

### 프롬프트

> Sprite sheet of a grass knight monster for a 2D mobile idle game.
>
> The sprite sheet contains 8 frames arranged in a 4x2 grid (4 columns, 2 rows). Each frame is 256x256 pixels, so the total image size is 1024x512 pixels. Transparent background (PNG with alpha). Frames are evenly spaced with no gaps or overlap.
>
> CRITICAL — Centering and Separation: Every frame's character must be fully contained within its 256x256 cell with at least 30 pixels of padding on ALL sides (left, right, top, bottom). No part of the character should touch or extend beyond any cell edge. Characters must NOT bleed into adjacent cells. Each frame must be completely independent and isolated within its own cell. Draw each character small enough to fit comfortably inside the cell with clear empty space around it.
>
> Character design: A humanoid knight made of woven grass and plant fiber. Armor plates of compressed green leaves and bark. Small flowers and weeds sprouting from joints and gaps in the armor. Holds a sharpened grass blade sword in right hand. T-shaped helmet visor with dark empty interior (no face visible). Thick dark outline. Chibi proportions, flat cel-shaded colors, mobile game art style. 3/4 top-down view.
>
> Row 1 (Frames 1-4): Walking animation loop (1→2→3→4→1). The head and torso stay stable — only the arms and legs move to create a shuffling walk cycle:
> - Frame 1 (Neutral): Standing upright, neutral pose. Both arms at sides, sword in right hand pointing down. Legs straight, feet together.
> - Frame 2 (Left step): Left leg steps forward, right leg back. Left arm (free hand) swings slightly forward, right arm (sword) swings slightly back. Head and torso remain perfectly upright and unchanged.
> - Frame 3 (Neutral): Same as frame 1. Both legs together, arms at sides. Passing through neutral.
> - Frame 4 (Right step): Right leg steps forward, left leg back. Right arm (sword) swings slightly forward, left arm swings slightly back. Mirror of frame 2. Head and torso remain perfectly upright and unchanged.
>
> Row 2 (Frames 5-6: Hit reaction, Frames 7-8: empty):
> - Frame 5 (Hit stagger): Body crouches down — about 20% shorter, knees bent, wider stance. Helmet visor cracks slightly or dents inward, the dark T-shaped opening distorts a bit. Sword arm drops. Leaves scatter slightly from armor edges. Staggered, recoiling pose.
> - Frame 6 (Hit recover): Body snaps back upright. Helmet visor still slightly bent/damaged looking. Sword raised back up but loosely. Recovering stance.
> - Frames 7-8: Leave completely empty (transparent).
>
> Important: In frames 1-4, the head, helmet, and torso must stay stable and upright — only limbs move. All frames must have identical green leaf armor, bark textures, flower details, and art style. No glow effects, no particles, no sword trails. Clean solid body only.

---

## 마도사 스프라이트 시트

### 프롬프트

> Sprite sheet of a mushroom mage monster for a 2D mobile idle game.
>
> The sprite sheet contains 8 frames arranged in a 4x2 grid (4 columns, 2 rows). Each frame is 256x256 pixels, so the total image size is 1024x512 pixels. Transparent background (PNG with alpha). Frames are evenly spaced with no gaps or overlap.
>
> CRITICAL — Centering and Separation: Every frame's character must be fully contained within its 256x256 cell with at least 30 pixels of padding on ALL sides (left, right, top, bottom). No part of the character should touch or extend beyond any cell edge. Characters must NOT bleed into adjacent cells. Each frame must be completely independent and isolated within its own cell. Draw each character small enough to fit comfortably inside the cell with clear empty space around it.
>
> Character design: A mushroom mage creature. Large spotted mushroom cap hat in purple and teal colors. Wispy body in tattered grass-fiber robes. Holds a twisted wooden staff with forked empty tip in left hand. Two small eyes visible under the dark underside of mushroom cap. Floating pose with robes hanging down. Thick dark outline. Chibi proportions, flat cel-shaded colors, mobile game art style. 3/4 top-down view.
>
> Row 1 (Frames 1-4): Gentle wobbling float animation loop (1→2→3→4→1):
> - Frame 1 (Neutral): Default floating pose, mushroom cap level, robes hanging straight down.
> - Frame 2 (Slight lean left): Entire body and mushroom cap tilt very slightly to the left, about 5 degrees only. Staff tilts with the body. Almost the same as frame 1.
> - Frame 3 (Neutral): Same as frame 1. Back to center, level and symmetrical.
> - Frame 4 (Slight lean right): Entire body and mushroom cap tilt very slightly to the right, about 5 degrees only. Mirror of frame 2.
>
> Row 2 (Frames 5-6: Hit reaction, Frames 7-8: empty):
> - Frame 5 (Hit squash): Body drops lower, mushroom cap flattens — about 30% shorter and wider. Eyes squeezed shut under the cap, robes crumpled. Pained, compressed pose as if pushed down from above.
> - Frame 6 (Hit rebound): Body bounces back up to floating height. Eyes still scrunched, mushroom cap slightly wobbly. Recovering.
> - Frames 7-8: Leave completely empty (transparent).
>
> Important: The wobble in frames 1-4 should be very subtle. All frames must have identical purple-teal mushroom cap, robe texture, staff design, and art style. No glow, no particles, no orbs, no spores. Clean solid body only.

---

## 수정 사슴 스프라이트 시트

### 프롬프트

> Sprite sheet of a crystal deer monster for a 2D mobile idle game.
>
> The sprite sheet contains 8 frames arranged in a 4x2 grid (4 columns, 2 rows). Each frame is 256x256 pixels, so the total image size is 1024x512 pixels. Transparent background (PNG with alpha). Frames are evenly spaced with no gaps or overlap.
>
> CRITICAL — Centering and Separation: Every frame's character must be fully contained within its 256x256 cell with at least 30 pixels of padding on ALL sides (left, right, top, bottom). No part of the character should touch or extend beyond any cell edge. Characters must NOT bleed into adjacent cells. Each frame must be completely independent and isolated within its own cell. Draw each character small enough to fit comfortably inside the cell with clear empty space around it.
>
> Character design: An elegant deer made of pale blue-white crystal. Faceted crystalline body with visible flat planes and edges. Jagged crystal shard antlers. White calm eyes. Slender legs with crystal hooves. Body has geometric facet patterns on the surface. Thick dark outline. Chibi proportions, flat cel-shaded colors, mobile game art style. 3/4 top-down view.
>
> Row 1 (Frames 1-4): Gentle wobbling walk animation loop (1→2→3→4→1):
> - Frame 1 (Neutral): Standing still, neutral pose. Head level, legs straight.
> - Frame 2 (Slight lean left): Entire body leans very slightly to the left, about 5 degrees only. Head and antlers tilt with the body. Almost the same as frame 1.
> - Frame 3 (Neutral): Same as frame 1. Back to center, perfectly symmetrical.
> - Frame 4 (Slight lean right): Entire body leans very slightly to the right, about 5 degrees only. Mirror of frame 2.
>
> Row 2 (Frames 5-6: Hit reaction, Frames 7-8: empty):
> - Frame 5 (Hit squash): Body crouches down — about 25% shorter, legs bent, head dipped. Crystal facets on body appear slightly cracked. Eyes shut tight in pain. Recoiling from impact.
> - Frame 6 (Hit rebound): Body springs back to neutral height. Eyes still partially shut, dazed expression. Slight wobble. Cracks no longer visible, recovering.
> - Frames 7-8: Leave completely empty (transparent).
>
> Important: The wobble in frames 1-4 should be very subtle. All frames must have identical pale blue-white crystal colors, facet patterns, antler shapes, and art style. No glow, no rainbow effects, no particles. Clean solid body with facet patterns only.

---

## 잔디 골렘 스프라이트 시트

### 프롬프트

> Sprite sheet of a grass golem monster for a 2D mobile idle game.
>
> The sprite sheet contains 8 frames arranged in a 4x2 grid (4 columns, 2 rows). Each frame is 256x256 pixels, so the total image size is 1024x512 pixels. Transparent background (PNG with alpha). Frames are evenly spaced with no gaps or overlap.
>
> CRITICAL — Centering and Separation: Every frame's character must be fully contained within its 256x256 cell with at least 30 pixels of padding on ALL sides (left, right, top, bottom). No part of the character should touch or extend beyond any cell edge. Characters must NOT bleed into adjacent cells. Each frame must be completely independent and isolated within its own cell. Draw each character small enough to fit comfortably inside the cell with clear empty space around it.
>
> Character design: A massive golem made of compacted earth, rocks, and thick grass. Dense green grass covers the body like fur, with exposed stone and dirt patches. Dark purple circular core socket in the chest (no glow, just dark purple color). Heavy boulder fists wrapped in roots. Small deep-set eye sockets in a rocky face. Thick dark outline. Chibi proportions, flat cel-shaded colors, mobile game art style. 3/4 top-down view.
>
> Row 1 (Frames 1-4): Gentle wobbling walk animation loop (1→2→3→4→1):
> - Frame 1 (Neutral): Standing upright, neutral pose. Fists at sides.
> - Frame 2 (Slight lean left): Entire body leans very slightly to the left, about 5 degrees only. Fists shift with the body. Almost the same as frame 1.
> - Frame 3 (Neutral): Same as frame 1. Back to center, standing upright.
> - Frame 4 (Slight lean right): Entire body leans very slightly to the right, about 5 degrees only. Mirror of frame 2.
>
> Row 2 (Frames 5-6: Hit reaction, Frames 7-8: empty):
> - Frame 5 (Hit squash): Body hunches down — about 25% shorter, shoulders raised, fists closer to the ground. Small rock fragments visible near the body edges. Eyes narrowed in pain. Staggered, defensive pose.
> - Frame 6 (Hit rebound): Body straightens back up. Eyes still squinting, slightly off-balance. Rock fragments gone, recovering.
> - Frames 7-8: Leave completely empty (transparent).
>
> Important: The wobble in frames 1-4 should be very subtle. All frames must have identical green grass coverage, stone patches, purple core, and art style. No glow, no particles, no debris flying. Clean solid body only.

---

## 드래곤 스프라이트 시트

### 프롬프트

> Sprite sheet of a smoke dragon monster for a 2D mobile idle game.
>
> The sprite sheet contains 8 frames arranged in a 4x2 grid (4 columns, 2 rows). Each frame is 256x256 pixels, so the total image size is 1024x512 pixels. Transparent background (PNG with alpha). Frames are evenly spaced with no gaps or overlap.
>
> CRITICAL — Centering and Separation: Every frame's character must be fully contained within its 256x256 cell with at least 30 pixels of padding on ALL sides (left, right, top, bottom). No part of the character should touch or extend beyond any cell edge. Characters must NOT bleed into adjacent cells. Each frame must be completely independent and isolated within its own cell. Draw each character small enough to fit comfortably inside the cell with clear empty space around it.
>
> Character design: A serpentine dragon with a dark gray-black body. Surface has orange-red crack patterns resembling lava veins. Sharp horns on the head. Small tattered wings. Orange fierce eyes. Ragged torn edges on the body silhouette (smoke-like shape but drawn as solid). Coiled body shape. Thick dark outline. Chibi proportions, flat cel-shaded colors, mobile game art style. 3/4 top-down view.
>
> Row 1 (Frames 1-4): Gentle wobbling idle animation loop (1→2→3→4→1):
> - Frame 1 (Neutral): Coiled neutral pose. Wings folded, body relaxed.
> - Frame 2 (Slight lean left): Entire body sways very slightly to the left, about 5 degrees only. Head and wings tilt with the body. Almost the same as frame 1.
> - Frame 3 (Neutral): Same as frame 1. Back to center, coiled and symmetrical.
> - Frame 4 (Slight lean right): Entire body sways very slightly to the right, about 5 degrees only. Mirror of frame 2.
>
> Row 2 (Frames 5-6: Hit reaction, Frames 7-8: empty):
> - Frame 5 (Hit squash): Body coils tighter and compresses down — about 25% more compact. Wings crumple inward. Eyes shut tight, mouth open showing teeth. Orange cracks on body glow brighter (drawn as thicker/wider orange-red lines, not actual glow effect). Pained, defensive coil.
> - Frame 6 (Hit rebound): Body uncoils slightly back to neutral size. Eyes still scrunched, dazed. Wings partially spread. Orange crack lines return to normal thickness. Recovering.
> - Frames 7-8: Leave completely empty (transparent).
>
> Important: The wobble in frames 1-4 should be very subtle. All frames must have identical dark gray-black body, orange-red crack patterns, horn shapes, wing design, and art style. No smoke, no fire, no glow effects, no particles. Clean solid body with crack patterns only.

---

## 플레이어 캐릭터 스프라이트 시트

### 설정
- 그리드: 6x2 (6열 2행)
- 프레임 크기: 128x128px
- 총 이미지 크기: 768x256px
- 배경: 투명 (PNG with alpha)

### 프레임 구성
| # | 위치 | 용도 | 설명 |
|---|------|------|------|
| 1 | Row1-1 | idle | 정면 기본 자세 |
| 2 | Row1-2 | walk_a | 정면 걷기 A |
| 3 | Row1-3 | walk_b | 정면 걷기 B |
| 4 | Row1-4 | attack1 | 정면 공격1 (팔 옆으로) |
| 5 | Row1-5 | attack2 | 정면 공격2 (팔 위로) |
| 6 | Row1-6 | hit | 정면 피격 |
| 7 | Row2-1 | idle_back | 뒷모습 기본 자세 |
| 8 | Row2-2 | walk_a_back | 뒷모습 걷기 A |
| 9 | Row2-3 | walk_b_back | 뒷모습 걷기 B |
| 10 | Row2-4 | attack1_back | 뒷모습 공격1 |
| 11 | Row2-5 | attack2_back | 뒷모습 공격2 |
| 12 | Row2-6 | hit_back | 뒷모습 피격 |

### 좌우반전
- 각 프레임을 좌우반전하여 `_flip` 버전 생성 (총 24장)

### 프롬프트

> 2D top-down cartoon sprite sheet for a mobile idle game. Small simple character (128x128 pixels per frame). Clean illustration with thick black outlines and flat coloring. Minimal detail — the character will appear very small in-game.
>
> NOT pixel art. Smooth lines, simple flat colors, minimal shading.
>
> Character design: A very simple small boy seen from DIRECTLY ABOVE at a top-down perspective. Green cap (plain solid color, no details). White T-shirt (plain). Lower body is ALL ONE solid brown color — shorts and shoes are the same brown with no distinction. Simple round head, two small black dot eyes ONLY — NO mouth, NO nose, NO other facial features. Both hands EMPTY. Extremely minimal design.
>
> CRITICAL: ALL frames must face STRAIGHT at the camera (front) or STRAIGHT away (back). The character must NEVER turn to the side. No side profiles, no 3/4 angles.
>
> IMPORTANT PERSPECTIVE RULE FOR WALK FRAMES: Limbs moving FORWARD (toward camera) should appear LONGER and LARGER. Limbs moving BACKWARD (away from camera) should appear SHORTER and SMALLER — foreshortened to create depth.
>
> Arrange all frames on a transparent background. Each cell exactly 128x128 pixels.
>
> Row 1 — Front-facing, looking straight at camera (6 frames, left to right):
> 1. Idle: Standing still facing camera, feet together, both arms resting at sides
> 2. Walk A: Right foot forward (drawn LONGER/BIGGER) + left foot back (drawn SHORTER/SMALLER) + left arm forward (LONGER) + right arm back (SHORTER). Head and torso face straight at camera.
> 3. Walk B: Left foot forward (drawn LONGER/BIGGER) + right foot back (drawn SHORTER/SMALLER) + right arm forward (LONGER) + left arm back (SHORTER). Exact opposite of Walk A.
> 4. Attack 1: Character's RIGHT arm (viewer's right side) is extended straight out to the RIGHT side, horizontal, as if reaching out to the right. Left arm stays at side. Body faces camera.
> 5. Attack 2: Character's RIGHT arm (viewer's right side) is raised DIAGONALLY UP to the upper-right, pointing to about 1-2 o'clock direction. Left arm stays at side. Body faces camera.
> 6. Hit: Body and upper torso TILTED/LEANING to one side (viewer's left), as if knocked sideways by an impact. Eyes shut (two short lines). Feet stay planted but torso is clearly angled off-center.
>
> Row 2 — Back-facing, looking straight away from camera (6 frames, same order):
> 1-6: Exact same poses as Row 1 but showing the character's back. Back of green cap, back of white shirt, brown lower half. NO face visible. All arm/leg positions match Row 1 from rear view.
>
> Total: 12 frames, 2 rows x 6 columns. Each cell 128x128 pixels. Transparent background. Thick black outline, flat colors, extremely minimal detail. Every single frame faces DIRECTLY forward or DIRECTLY backward.
