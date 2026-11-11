// =====================================================
// Flower.pde — 꽃의 한살이 (담당 B) — 3D
// 싹(0) → 봉오리(1) → 꽃(2) → 시듦(3) → 사라지며 씨앗을 남긴다 (06-1 §4-4, §4-6)
// 자라는 빠르기 = growSpeed × calm × light (06-1 §4-4) — 멈춰 있어야 자라고,
// 햇빛이 강하면 빨리, 움직이거나 어둡거나 아무도 없으면 자라지 않고 늙기만 한다.
// =====================================================

final float MAX_SIZE = 26;   // 다 자란 꽃의 크기

class Flower {
  float x, y, z;         // 뿌리 위치 (심은 자리에 고정 — 06-2 0-2의 4번)
  float size = 2;        // 지금 크기
  int stage = 0;         // 0 싹 · 1 봉오리 · 2 꽃 · 3 시듦
  float age = 0;         // 나이 — 언제나 늘어난다
  float lifespan;        // 수명 (꽃마다 조금씩 다르다)
  float openness = 0;    // 열린 정도 0~1 — light를 따라간다
  color petalColor;      // 꽃잎 색 — 씨앗에 물려준다
  int petalCount;        // 꽃잎 수
  float wilt = 0;        // 시든 정도 0~1
  boolean bloomed = false;  // 꽃까지 피어 봤는가 (씨앗을 남길 자격)
  boolean pollinated = false;  // 나비가 다른 꽃의 꽃가루를 옮겨 주었는가 (B4-2)
  color pollenColor;           // 옮겨 받은 꽃가루 색 → 씨앗 색 = 꽃잎 색과의 중간
  boolean dead = false;
  float spin;            // 꽃잎 돌림 각도
  float noiseOff;        // 흔들림용 noise 위치

  Flower(float x, float y, float z, color c) {
    this.x = x;
    this.y = y;
    this.z = z;
    petalColor = c;
    lifespan = lifespanSec * 60 * random(0.7, 1.3);   // 초 → 프레임 (60fps)
    petalCount = int(random(5, 9));
    spin = random(TWO_PI);
    noiseOff = random(1000);
  }

  // 아직 자라는 중인가 (반짝이 효과를 낼 꽃)
  boolean growing() {
    return stage < 2 || (stage == 2 && size < MAX_SIZE);
  }

  void update() {
    // 늙기: 언제나 는다. 햇빛이 강하면 빨리 늙는다 (보통 0.5 → 1씩, 두 손 1 → 1.5씩)
    age += 0.5 + light;

    if (stage < 3) {
      // 자라기: growSpeed × calm × light (growthFactor) — Scene.pde 참고
      size = min(size + growSpeed * growthFactor(), MAX_SIZE);
      if (stage == 0 && size > MAX_SIZE * 0.35) stage = 1;
      if (stage == 1 && size > MAX_SIZE * 0.65) {
        stage = 2;
        bloomed = true;
      }
      if (age > lifespan) stage = 3;   // 수명이 다하면 시들기 시작
    } else {
      wilt += 0.004;                   // 약 4초에 걸쳐 시든다
      if (wilt >= 1) dead = true;
    }

    // 열림: 핀 꽃만 light를 따라 열린다. 어두우면 오므라든다(지우지 않는다)
    float openTarget = 0;
    if (stage == 2) openTarget = constrain(light * 1.6, 0.1, 1);
    openness = openness * 0.97 + openTarget * 0.03;
  }

  // 땅에서 난 꽃은 잔디 위로 올라오게 줄기가 길고, 덩굴 마디에 핀 꽃은 짧다
  float stemLength() {
    if (y >= GROUND_Y - 1) return size * 2.3;
    return size * 1.4;
  }

  // 꽃머리 위치 — noise로 살랑이고 바람 방향으로 기운다 (B4-5: 몸을 기울인 쪽)
  float headX() {
    float sway = (noise(noiseOff + frameCount * 0.01) - 0.5) * 6 + windX() * 12;
    return x + sway * (size / MAX_SIZE);
  }

  float headY() {
    return y - stemLength();
  }

  color currentColor() {
    return lerpColor(petalColor, color(140, 110, 80), wilt * 0.8);   // 시들면 갈색으로 바랜다
  }

  void display() {
    float hx = headX();
    float hy = headY();
    color stemCol = lerpColor(color(80, 150, 70), color(130, 110, 70), wilt);

    // 줄기 — 멀리 있으면 가늘게 (P3D 선 굵기에는 원근이 적용되지 않아서 직접 줄인다)
    stroke(stemCol);
    strokeWeight(max(0.6, 2 * depthScale(z)));
    line(x, y, z, hx, hy, z);
    noStroke();

    if (stage >= 2) {
      // 줄기 가운데 잎 하나
      pushMatrix();
      translate(lerp(x, hx, 0.5), lerp(y, hy, 0.5), z);
      rotateZ(-0.5);
      fill(stemCol);
      ellipse(5, 0, 10, 4);
      popMatrix();
    }

    pushMatrix();
    translate(hx, hy, z);
    if (stage == 0) {
      // 싹: 떡잎 두 장
      fill(stemCol);
      float s = size * 0.5 + 1;
      ellipse(-s * 0.6, 0, s * 1.2, s * 0.5);
      ellipse(s * 0.6, 0, s * 1.2, s * 0.5);
    } else if (stage == 1) {
      // 봉오리: 꽃잎 색 물방울 + 초록 받침
      fill(petalColor);
      ellipse(0, -size * 0.2, size * 0.45, size * 0.7);
      fill(stemCol);
      ellipse(0, 0, size * 0.4, size * 0.2);
    } else {
      // 꽃 · 시듦: 3D 꽃잎 — 열린 정도에 따라 꽃잎이 눕거나(활짝) 일어서서(오므림) 컵이 된다
      float r = size * 0.55 * (1 - wilt * 0.4);   // 꽃잎 길이 — 시들면 줄어든다
      float cup = (1 - openness) * 1.3;            // 0이면 활짝, 클수록 꽃잎이 일어선다
      rotateZ(wilt * 1.2);                         // 시들면 고개를 숙인다
      rotateX(0.75);                               // 꽃 얼굴이 하늘·앞쪽을 보게 기울인다
      fill(currentColor());
      for (int k = 0; k < petalCount; k++) {
        pushMatrix();
        rotateZ(spin + TWO_PI * k / petalCount);  // 꽃잎을 빙 둘러 놓는다 (CH8 변환)
        rotateX(-cup);                             // 꽃잎 밑동을 축으로 일으켜 세운다
        translate(0, -r * 0.5, 0);
        ellipse(0, 0, r * 0.6, r);
        popMatrix();
      }
      fill(lerpColor(color(255, 210, 80), color(120, 90, 50), wilt));
      translate(0, 0, 1);
      ellipse(0, 0, r * 0.45, r * 0.45);          // 꽃술
    }
    popMatrix();
  }
}
