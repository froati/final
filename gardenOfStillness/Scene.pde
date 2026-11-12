// =====================================================
// Scene.pde — 환경 값과 정원의 규칙 (담당 B) — 3D
// 관객의 행동은 환경 값의 "목표"만 옮긴다. 화면의 변화는 모두 아래 규칙의 결과다 (06-1 §4-4).
//
// ★ 성장 계수 growthFactor() = calm × light  (06-1 §4-4 "자라기": growSpeed × calm × light)
//   가만히 서 있음(차렷, 햇빛 0.5)  ×1 — 멈춰 있는 동안 시간이 지나면 핀다
//   두 손 들고 멈춤(햇빛 1)         ×2 — 빠르게
//   움직임                          ×0 — 고요함이 0 → 자라지 않는다 (게다가 흩날린다)
//   웅크리고 멈춤(햇빛 0)           ×0 — 해가 져서 멈춘다 (반딧불이)
//   아무도 없음                     ×0 — 자라지 않고 늙기만 한다 → 시들고 씨앗을 남긴다
// =====================================================

// ---- 환경 값 (모두 0~1) ----
float calm = 0;            // 고요함
float light = 0.5;         // 햇빛
float lightTarget = 0.5;   // 햇빛이 따라가는 목표 — 자세가 2초 유지되면 바뀐다
float wind = 0;            // 바람 세기 — 움직이면 돌풍 (오른쪽으로)
float breeze = 0;          // 산들바람 -1~1 — 몸을 기울인 쪽으로 분다 (B4-5, lean을 따라간다)
// 거름(soil)은 Soil.pde (B4-1)

// 실제로 옆으로 미는 바람 (+ 오른쪽, - 왼쪽) — 꽃·씨앗·꽃잎·잔디가 이 값을 쓴다
float windX() {
  return wind + breeze;
}

// ---- 안내 문구 (B4-4) ----
int stillZeroSinceMs = -1;   // 사람이 있는데 고요함이 0인 상태가 시작된 시각 (-1이면 아님)
float hintAlpha = 0;

// ---- 2초 유지 판단 ----
String heldPose = "없음";
int poseStartMs = 0;

// ---- 정원에 사는 것들 ----
final int MAX_FLOWERS = 300;
final int MAX_SEEDS = 100;
final int START_SEEDS = 70;      // 처음 평원에 있는 씨앗 수 — 06-1 §3-1 "앞사람이 남긴 씨앗" 자리
ArrayList<Flower> flowers = new ArrayList<Flower>();
ArrayList<Seed> seeds = new ArrayList<Seed>();
ArrayList<Petal> petals = new ArrayList<Petal>();
ArrayList<Firefly> fireflies = new ArrayList<Firefly>();
ArrayList<Sparkle> sparkles = new ArrayList<Sparkle>();
ArrayList<Butterfly> butterflies = new ArrayList<Butterfly>();
ArrayList<Vine> vines = new ArrayList<Vine>();
color[] palette;

// 새 꽃(싹)을 정원에 넣는 곳은 모두 여기를 거친다 — 상한 확인 + "똑" 소리 (B3-3)
boolean addFlower(Flower f) {
  if (flowers.size() >= MAX_FLOWERS) return false;
  flowers.add(f);
  playSprout();
  return true;
}

void initScene() {
  palette = new color[] {
    color(255, 140, 170),  // 분홍
    color(255, 200, 90),   // 노랑
    color(190, 150, 255),  // 보라
    color(255, 248, 235),  // 흰색
    color(120, 190, 255),  // 하늘
    color(255, 120, 100)   // 다홍
  };
  sowMeadow();
}

// 평원 여기저기에 씨앗을 뿌린다 — 처음에는 잔디만 보이고, 관객이 멈춰 있으면 여기서 꽃이 난다
void sowMeadow() {
  for (int i = 0; i < START_SEEDS; i++) {
    PVector p = randomMeadowPoint(40, -900);
    seeds.add(new Seed(p.x, p.y, p.z, palette[int(random(palette.length))]));
  }
}

// ★ 성장 계수 (위 설명 참고)
float growthFactor() {
  return calm * light;
}

// 차렷으로 가만히 서 있을 때(calm 1 × light 0.5) 대비 몇 배인가 — 화면 표시용
float growthRelative() {
  return growthFactor() / 0.5;
}

// ---------- 환경 값 갱신 ----------
void updateEnvironment() {
  // 고요함: 움직임이 작을수록 목표 1, 사람이 없으면 목표 0. 느리게 따라간다 (06-1 §4-5)
  float calmTarget;
  if (personCount < 500) {
    calmTarget = 0;
  } else {
    calmTarget = constrain(map(totalMotion, 0, calmSensitivity, 1, 0), 0, 1);
  }
  calm = calm * 0.98 + calmTarget * 0.02;

  // 햇빛: 같은 자세가 poseHold초 이어지고 고요함도 높을 때만 목표를 옮긴다
  if (!pose.equals(heldPose)) {
    heldPose = pose;
    poseStartMs = millis();
  }
  float heldSec = (millis() - poseStartMs) / 1000.0;
  if (heldSec >= poseHold && calm > 0.6) {
    if (pose.equals("두손들기")) lightTarget = 1.0;
    else if (pose.equals("차렷")) lightTarget = 0.5;
    else if (pose.equals("웅크리기")) lightTarget = 0.0;
    // 팔벌리기는 햇빛을 바꾸지 않는다 — 덩굴의 목표가 된다 (4주차 B4-3)
  }
  light = light * 0.995 + lightTarget * 0.005;

  // 바람: 움직이면 바로 오르고, 멈추면 금방 잦아든다
  float windNow = constrain(totalMotion / (calmSensitivity * 4), 0, 1);
  wind = max(wind * 0.96, windNow);

  // 산들바람: 몸을 기울인 쪽으로 천천히 (B4-5). 기울기만큼이라 움직이지 않아도 분다
  breeze = breeze * 0.98 + lean * 0.5 * 0.02;

  // 거름: 시간이 지나면 조금씩 줄어든다 (B4-1)
  updateSoil();
}

// ---------- 매 프레임 규칙 ----------
void updateGarden() {
  // ※ 2026-11-11: "몸(실루엣 가장자리)에서 싹 트기"를 뺐다 — 꽃이 사람 몸에 붙어 보이고,
  //    사람이 움직이면 허공에 남았다. 꽃은 땅(씨앗)에서만 자란다 (06-1 §4-4 수정)

  // ① 씨앗: 떨어지고, 내려앉고, 고요함이 높을 때 일정 확률로 싹튼다 (색은 부모 색 + 조금의 변화)
  for (int i = seeds.size() - 1; i >= 0; i--) {
    Seed s = seeds.get(i);
    s.update();
    if (s.readyToSprout() && flowers.size() < MAX_FLOWERS) {
      addFlower(new Flower(s.x, s.y, s.z, mutate(s.c)));
      seeds.remove(i);
    } else if (s.offScreen()) {
      seeds.remove(i);
    }
  }

  // ② 꽃
  for (int i = flowers.size() - 1; i >= 0; i--) {
    Flower f = flowers.get(i);
    f.update();

    // 흩날림: 꽃머리가 "웹캠 화면에서" 있는 칸의 움직임이 sensitivity를 넘으면 꽃잎이 된다
    //         보는 시점이 움직여도 웹캠 기준으로 계산한다 (Meadow.pde의 webcamViewX·Y)
    //         웹캠 속 사람의 몸을 캐릭터 몸에 겹쳐서 본다 (Character.pde screenToCam)
    //         → 오른손을 휘두르면 캐릭터 오른손 근처 꽃이 흩날린다
    float sx = screenToCamX(webcamViewX(f.headX(), f.z));
    float sy = screenToCamY(webcamViewY(f.headY(), f.z));
    int cx = constrain(int(sx / CELL), 0, COLS - 1);
    int cy = constrain(int(sy / CELL), 0, ROWS - 1);
    if (!waving && f.stage >= 1 && motion[cx][cy] > sensitivity) {
      scatter(f);
      flowers.remove(i);
      continue;
    }

    if (f.dead) {
      if (f.bloomed) dropSeeds(f);
      flowers.remove(i);
    }
  }

  // ③ 꽃잎
  for (int i = petals.size() - 1; i >= 0; i--) {
    Petal p = petals.get(i);
    p.update();
    if (p.done) petals.remove(i);
  }

  // ④ 덩굴 (B4-3) · 나비 (B4-2)
  updateVines();
  updateButterflies();

  // ⑤ 반딧불이 · 반짝이 · 안내 문구
  updateFireflies();
  updateSparkles();
  updateHint();
}

void scatter(Flower f) {
  for (int k = 0; k < f.petalCount; k++) {
    petals.add(new Petal(f.headX(), f.headY(), f.z, f.currentColor()));
  }
}

// 시든 꽃 → 씨앗 1~3개. 씨앗은 꽃보다 조금 뒤(평원 쪽)로 날아가 떨어진다
// 나비가 다른 꽃의 꽃가루를 옮겨 준 꽃이면 씨앗 색 = 두 색의 중간 (B4-2)
void dropSeeds(Flower f) {
  color seedColor = f.petalColor;
  if (f.pollinated) seedColor = lerpColor(f.petalColor, f.pollenColor, 0.5);
  int n = int(random(1, 4));
  for (int k = 0; k < n; k++) {
    float sz = min(f.z - random(0, 150), 40);
    seeds.add(new Seed(f.headX(), f.headY(), sz, seedColor));
    if (seeds.size() > MAX_SEEDS) seeds.remove(0);
  }
}

color mutate(color c) {
  float r = constrain(red(c) + random(-25, 25), 40, 255);
  float g = constrain(green(c) + random(-25, 25), 40, 255);
  float b = constrain(blue(c) + random(-25, 25), 40, 255);
  return color(r, g, b);
}

// 시험용 클릭: 화면에서 누른 자리 "아래의 땅"에 싹 — 꽃은 땅에서만 자란다
//   화면 높이 sy에 보이는 땅의 깊이 z를 구하고, 그 깊이에서 화면 x에 해당하는 땅 위 x를 구한다
void plantAt(float sx, float sy) {
  if (sy <= HORIZON_Y + 2) return;                    // 하늘(지평선 위)을 누르면 심지 않는다
  float z = max(groundZForScreenY(sy), -2000);
  float x = W / 2.0 + (sx - W / 2.0) / depthScale(z);
  addFlower(new Flower(x, GROUND_Y, z, palette[int(random(palette.length))]));
}

// R 키 · 조절판의 resetGarden 버튼
void resetGarden() {
  flowers.clear();
  seeds.clear();
  petals.clear();
  sparkles.clear();
  butterflies.clear();
  vines.clear();
  clearSoil();
  sowMeadow();     // 처음처럼 잔디 평원 + 땅속 씨앗
}

// ---------- 그리기 ----------

// 하늘·해·먼 언덕 — 화면에 붙은 2D 배경 (깊이 검사를 끄고 그려서 3D 물체 뒤에 깔린다)
void drawSky() {
  background(0);   // P3D에서는 background()가 깊이 기록도 지운다 — 빼면 전 프레임의 흔적이 남는다
  hint(DISABLE_DEPTH_TEST);
  color top, horizon;
  if (light < 0.5) {
    float t = light / 0.5;
    top = lerpColor(color(12, 16, 40), color(110, 165, 215), t);
    horizon = lerpColor(color(40, 42, 80), color(220, 220, 205), t);
  } else {
    float t = (light - 0.5) / 0.5;
    top = lerpColor(color(110, 165, 215), color(140, 205, 250), t);
    horizon = lerpColor(color(220, 220, 205), color(255, 244, 215), t);
  }
  noStroke();
  beginShape(QUADS);                 // 꼭짓점 색이 다른 사각형 = 그러데이션
  fill(top);
  vertex(0, 0);
  vertex(W, 0);
  fill(horizon);
  vertex(W, skyHorizon + 20);
  vertex(0, skyHorizon + 20);
  endShape();
  rect(0, skyHorizon + 20, W, H);   // 지평선 아래는 땅이 덮지만 혹시 빈 곳이 보일 때를 대비

  // 시점이 옆으로 움직이면 먼 것일수록 조금만 움직인다 (시차 — 입체감)
  float shift = -(eyeX - W / 2.0);

  // 해: light가 클수록 높이 뜬다
  float sunY = map(light, 0, 1, skyHorizon + 30, 60);
  float sunX = 530 + shift * 0.03;
  fill(255, 230, 150, 60);
  ellipse(sunX, sunY, 110, 110);
  fill(255, 236, 170);
  ellipse(sunX, sunY, 56, 56);

  // 먼 언덕 (지평선 위로 살짝) — 뒤쪽 언덕은 덜, 앞쪽 언덕은 더 움직인다
  fill(lerpColor(horizon, color(90, 130, 105), 0.3));
  ellipse(660 + shift * 0.06, skyHorizon + 10, 380, 34);
  fill(lerpColor(horizon, color(90, 130, 105), 0.45));
  ellipse(90 + shift * 0.1, skyHorizon + 14, 460, 46);
  ellipse(430 + shift * 0.1, skyHorizon + 16, 560, 38);
  hint(ENABLE_DEPTH_TEST);
}

void drawGarden() {
  for (Seed s : seeds) s.display();
  for (Vine v : vines) v.display();
  for (Flower f : flowers) f.display();
  for (Petal p : petals) p.display();
  for (Butterfly b : butterflies) b.display();
}

// ---------- 안내 문구 (B4-4): 사람이 있는데 고요함이 10초 넘게 0이면 "잠시 멈춰 보세요" ----------
void updateHint() {
  boolean zero = personCount >= 500 && calm < 0.05;
  if (zero && stillZeroSinceMs < 0) stillZeroSinceMs = millis();
  if (!zero) stillZeroSinceMs = -1;
  boolean show = stillZeroSinceMs >= 0 && millis() - stillZeroSinceMs > 10000;
  hintAlpha = ease(hintAlpha, show ? 255 : 0, 0.05);
}

void drawStillHint() {
  if (hintAlpha < 2) return;
  String msg = "잠시 멈춰 보세요";
  textFont(bannerFont, 28);
  textAlign(CENTER, CENTER);
  float pulse = 0.75 + 0.25 * sin(millis() * 0.003);   // 천천히 숨 쉬듯
  fill(0, hintAlpha * 0.35);
  text(msg, W / 2 + 2, 402);              // 아래 가운데 — 점검 정보·조절판과 겹치지 않게
  fill(255, 250, 235, hintAlpha * pulse);
  text(msg, W / 2, 400);
  textFont(font, 13);
  textAlign(LEFT, BASELINE);
}

// 밤: 화면 전체에 어두운 막을 덮는다 (햇빛 0.5 이상이면 없음)
void drawNightShade() {
  float dark = constrain(1 - light * 2, 0, 1);
  if (dark <= 0) return;
  hint(DISABLE_DEPTH_TEST);
  noStroke();
  fill(8, 12, 35, dark * 150);
  rect(0, 0, W, H);
  hint(ENABLE_DEPTH_TEST);
}

void drawCalmGauge() {
  noStroke();
  fill(0, 90);
  rect(60, 466, 520, 8, 4);
  fill(170, 240, 190);
  rect(60, 466, 520 * calm, 8, 4);
  fill(255);
  textAlign(RIGHT, CENTER);
  text("고요함", 54, 469);
  textAlign(LEFT, BASELINE);
}

// 지금 정원이 얼마나 빨리 자라는지, 왜 그런지 — 환경 값으로만 판단한다 (자세 이름을 보지 않는다)
void drawGrowthStatus() {
  float rel = growthRelative();
  String why;
  color col;
  if (personCount < 500) {
    why = "아무도 없음 — 늙기만 한다";
    col = color(200, 200, 200);
  } else if (light < 0.15) {
    why = "밤 — 성장이 멈췄다";
    col = color(150, 160, 220);
  } else if (calm < 0.3) {
    why = "움직임 — 자라지 않는다";
    col = color(230, 150, 130);
  } else if (light > 0.75) {
    why = "햇빛 + 고요함 — 빠르게";
    col = color(255, 220, 110);
  } else {
    why = "고요함 — 자라는 중";
    col = color(170, 240, 190);
  }
  String label = "성장 ×" + nf(rel, 1, 1) + "   " + why;
  textAlign(RIGHT, CENTER);
  float tw = textWidth(label);
  noStroke();
  fill(0, 170);
  rect(W - tw - 20, 438, tw + 14, 22, 11);
  fill(col);
  text(label, W - 13, 448);
  textAlign(LEFT, BASELINE);
}

void drawDebug() {
  float heldSec = (millis() - poseStartMs) / 1000.0;
  String[] lines = {
    "자세  " + pose + "  (" + nf(heldSec, 1, 1) + "초 유지)",
    "totalMotion  " + nf(totalMotion, 1, 1) + "   personCount  " + personCount,
    "calm  " + nf(calm, 1, 2) + "   light  " + nf(light, 1, 2) + " → " + nf(lightTarget, 1, 2) + "   wind  " + nf(wind, 1, 2),
    "꽃 " + flowers.size() + "  씨앗 " + seeds.size() + "  꽃잎 " + petals.size() + "  반딧불이 " + fireflies.size()
      + "  나비 " + butterflies.size() + "  덩굴 " + vines.size(),
    "lean " + nf(lean, 1, 2) + "   산들바람 " + nf(breeze, 1, 2) + "   거름 합 " + nf(totalSoil(), 1, 1)
      + (waving ? "   손 흔드는 중" : ""),
    (useCamera ? "웹캠 (얼굴 " + (faceNow ? "보임" : "안 보임") + ", 폭 " + nf(faceW, 1, 0) + ")" : "마우스판")
      + "   threshold " + nf(threshold, 1, 0) + " [ ]   고요함 기준 " + nf(calmSensitivity, 1, 0) + " - =",
    useCamera
      ? (hasBase
          ? "판정  위 " + nf(upL, 1, 2) + "/" + nf(upR, 1, 2) + "  옆 " + nf(sideL, 1, 2) + "/" + nf(sideR, 1, 2)
            + "  내려감 " + nf(dropRatio, 1, 2) + "  움직인 칸 " + movingCells
          : "기준 잡는 중 — 2초 가만히 있어 주세요")
      : "마우스판: 1~4 자세 · W 손흔들기 · ←→ 기울기 · 0 사람 없음",
    "fps  " + nf(frameRate, 1, 0) + (logging ? "   ● 기록 중" : ""),
    "C 기준 다시 · M 웹캠/마우스 · S 사진 · L 기록 · R 처음 · D · H 숨기기"
  };
  noStroke();
  fill(0, 120);
  rect(6, 6, 520, lines.length * 17 + 8, 4);
  fill(255);
  for (int k = 0; k < lines.length; k++) {
    text(lines[k], 12, 22 + k * 17);
  }
}

// ---------- 반짝이: 빠르게 자라는 꽃에서 빛 알갱이가 올라온다 (성장 계수가 클수록 많이) ----------
void updateSparkles() {
  float rel = growthRelative();
  if (rel > 0.5 && flowers.size() > 0) {
    int tries = int(rel * 2);              // ×1 → 2개, ×2 → 4개쯤 시도
    for (int k = 0; k < tries; k++) {
      Flower f = flowers.get(int(random(flowers.size())));
      if (f.growing() && sparkles.size() < 300) {
        sparkles.add(new Sparkle(f.headX(), f.headY(), f.z));
      }
    }
  }
  for (int i = sparkles.size() - 1; i >= 0; i--) {
    Sparkle s = sparkles.get(i);
    s.update();
    if (s.life <= 0) sparkles.remove(i);
  }
}

void drawSparkles() {
  hint(DISABLE_DEPTH_MASK);   // 반투명한 빛이 뒤의 물체를 가리지 않게
  for (Sparkle s : sparkles) s.display();
  hint(ENABLE_DEPTH_MASK);
}

class Sparkle {
  float x, y, z, life = 1;
  Sparkle(float x, float y, float z) {
    this.x = x + random(-6, 6);
    this.y = y + random(-4, 4);
    this.z = z;
  }
  void update() {
    y -= 0.7;                              // 위로 떠오른다
    x += (noise(x * 0.05, frameCount * 0.05) - 0.5);
    life -= 0.02;
  }
  void display() {
    noStroke();
    pushMatrix();
    translate(x, y, z);
    fill(255, 245, 170, life * 90);
    ellipse(0, 0, 7, 7);
    fill(255, 255, 230, life * 255);
    ellipse(0, 0, 2.5, 2.5);
    popMatrix();
  }
}

// ---------- 반딧불이 ----------
void updateFireflies() {
  // 목표 수: 06-1은 (1 - light) × 최대 수. ※ 어두워질 때만 보이도록 2.2배로 당겼다 (light 0.45 이상이면 0마리)
  int want = round(constrain(1 - light * 2.2, 0, 1) * 50);
  int alive = 0;
  for (Firefly ff : fireflies) if (!ff.leaving) alive++;

  if (frameCount % 8 == 0) {
    if (alive < want) {
      fireflies.add(new Firefly());
    } else if (alive > want) {
      for (Firefly ff : fireflies) {
        if (!ff.leaving) { ff.leaving = true; break; }
      }
    }
  }
  for (int i = fireflies.size() - 1; i >= 0; i--) {
    Firefly ff = fireflies.get(i);
    ff.update();
    if (ff.leaving && ff.alpha < 3) fireflies.remove(i);
  }
}

void drawFireflies() {
  hint(DISABLE_DEPTH_MASK);
  for (Firefly ff : fireflies) ff.display();
  hint(ENABLE_DEPTH_MASK);
}

class Firefly {
  float x, y, z, t;
  float alpha = 0;
  boolean leaving = false;

  Firefly() {
    PVector p = randomMeadowPoint(40, -1000);   // 평원 위 아무 깊이
    x = p.x;
    z = p.z;
    y = GROUND_Y - random(10, 160);
    t = random(1000);
  }

  void update() {
    x += (noise(t, frameCount * 0.01) - 0.5) * 2.5;
    y += (noise(t + 500, frameCount * 0.01) - 0.5) * 2.0;
    z += (noise(t + 900, frameCount * 0.01) - 0.5) * 2.5;
    y = constrain(y, GROUND_Y - 220, GROUND_Y - 4);
    float target = leaving ? 0 : 255;
    alpha += (target - alpha) * 0.05;
  }

  void display() {
    float blink = 0.5 + 0.5 * sin(frameCount * 0.08 + t);
    noStroke();
    pushMatrix();
    translate(x, y, z);
    fill(220, 255, 120, alpha * 0.25 * blink);
    ellipse(0, 0, 14, 14);
    fill(245, 255, 170, alpha * blink);
    ellipse(0, 0, 4, 4);
    popMatrix();
  }
}
