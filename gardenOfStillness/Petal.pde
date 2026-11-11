// =====================================================
// Petal.pde — 흩날리는 꽃잎 (담당 B) — 3D
// 중력 + noise() 흔들림 + 바람. 땅에 닿으면 사라지며 그 칸 거름을 올린다 (B4-1, Soil.pde)
// =====================================================

class Petal {
  float x, y, z, vy;
  color c;
  float rot, rotSpeed;   // 빙글빙글 도는 각도
  float t;               // noise 위치
  boolean done = false;

  Petal(float x, float y, float z, color c) {
    this.x = x + random(-4, 4);
    this.y = y + random(-4, 4);
    this.z = z + random(-6, 6);
    this.c = c;
    vy = random(-2, 0);
    rot = random(TWO_PI);
    rotSpeed = random(-0.12, 0.12);
    t = random(1000);
  }

  void update() {
    vy = min(vy + 0.2, 2.0);                                   // 중력 — 꽃잎은 가벼워서 최고 속도를 낮게
    x += (noise(t + frameCount * 0.02) - 0.5) * 3 + windX() * 4;  // 13주차 Pelo처럼 noise로 흔들림 + 바람 방향
    y += vy;
    rot += rotSpeed;
    if (y >= GROUND_Y) {                                       // 땅에 닿음 → 그 칸 거름 (B4-1)
      addSoil(x, z, SOIL_PER_PETAL);
      done = true;
    }
    if (abs(x - width / 2.0) > visibleHalfWidth(z) + 60) done = true;   // 화면 밖
  }

  void display() {
    pushMatrix();
    translate(x, y, z);
    rotateZ(rot);
    rotateX(rot * 0.7);        // 3D로 뒤집히며 떨어진다
    noStroke();
    fill(c, 230);
    ellipse(0, 0, 7, 4);
    popMatrix();
  }
}
