// =====================================================
// Seed.pde — 씨앗 (담당 B) — 3D
// 시든 꽃에서 떨어져 → 바람에 날리며 → 땅에 내려앉고 → 고요함이 높을 때 일정 확률로 싹튼다
// 처음 평원에는 씨앗이 흩어져 있다 (06-1 §3-1 "앞사람이 남긴 씨앗"). 관객이 멈춰 있어야 싹튼다.
// =====================================================

class Seed {
  float x, y, z;
  float vx, vy;          // 속도
  color c;               // 다음 꽃이 물려받을 색
  boolean landed = false;

  Seed(float x, float y, float z, color c) {
    this.x = x;
    this.y = y;
    this.z = z;
    this.c = c;
    vx = random(-1, 1);
    vy = random(-1.5, 0);              // 살짝 튀어 오르며 떨어진다
    if (y >= GROUND_Y) landed = true;  // 땅에서 시작하면 이미 내려앉은 씨앗
  }

  void update() {
    if (!landed) {
      vy = min(vy + 0.2, 3);   // 중력 (최고 속도 3)
      vx *= 0.98;
      x += vx + windX() * 3;   // 바람 방향으로 옆으로 (B4-5: 몸을 기울인 쪽)
      y += vy;
      if (y >= GROUND_Y) {
        y = GROUND_Y;
        landed = true;
      }
    } else if (abs(windX()) > 0.3) {
      x += windX() * random(0.5, 2);   // 땅 위 씨앗도 센 바람에 굴러간다
    }
  }

  // 싹틀 차례인가: 내려앉았고, 고요함이 높을 때 일정 확률로 (06-1 §4-4)
  //   가만히 서 있으면 씨앗 하나가 평균 약 7초 안에 싹튼다 (60fps 기준)
  //   거름이 가득한 칸(1)이면 확률이 4배 → 약 2초 (B4-1)
  boolean readyToSprout() {
    float boost = 1 + 3 * soilAt(x, z);
    return landed && calm > 0.5 && random(1) < 0.0025 * calm * boost;
  }

  boolean offScreen() {
    return abs(x - width / 2.0) > visibleHalfWidth(z) + 60;
  }

  void display() {
    noStroke();
    fill(lerpColor(color(110, 80, 50), c, 0.35));
    pushMatrix();
    translate(x, y - 1, z);
    ellipse(0, 0, 4, 3);
    popMatrix();
  }
}
