// =====================================================
// Butterfly.pde — 나비와 꽃가루 (담당 B, B4-2)
// 손을 흔들면(waving) 그 자리에 나비가 나타나, waveX·waveY에서 가장 가까운 핀 꽃으로 이징해 날아간다.
// 꽃에 닿으면 그 꽃의 색(꽃가루)을 묻히고, 다른 꽃에 닿으면 묻혀 온 꽃가루를 옮긴다.
// 꽃가루를 받은 꽃이 시들면 씨앗 색 = 두 색의 중간 (Scene.dropSeeds, lerpColor).
// → 빨간 꽃과 파란 꽃 사이에서 손을 흔들면 다음 세대에 보라색 계열이 나온다.
// 손 흔들기를 멈추고 몇 초 지나면 나비는 하늘로 날아간다. 날개는 sin(frameCount × 0.35).
// (손을 흔드는 동안은 꽃이 흩날리지 않는다 — Scene.updateGarden)
// =====================================================

final int MAX_BUTTERFLIES = 2;
final int BUTTERFLY_STAY_MS = 6000;   // 손 흔들기를 멈춘 뒤 이만큼 지나면 떠난다

int lastWavingMs = -100000;

void updateButterflies() {
  if (waving) {
    lastWavingMs = millis();
    // 손을 흔들기 시작하면 나비가 그 자리에 나타난다 (둘째 나비는 3초 뒤)
    if (butterflies.size() == 0 || (butterflies.size() < MAX_BUTTERFLIES && frameCount % 180 == 0)) {
      butterflies.add(new Butterfly(camToScreenX(waveX), camToScreenY(waveY), 0));   // 웹캠 좌표 → 캐릭터 몸 위의 손 자리
    }
  }
  for (int i = butterflies.size() - 1; i >= 0; i--) {
    Butterfly b = butterflies.get(i);
    b.update();
    if (b.gone) butterflies.remove(i);
  }
}

// waveX·waveY에서 (웹캠 화면 기준으로) 가장 가까운 핀 꽃 — 없으면 null
Flower nearestOpenFlower(float wx, float wy) {
  Flower best = null;
  float bestD = 1e9;
  for (Flower f : flowers) {
    if (f.stage != 2) continue;
    // 꽃의 화면 위치를 웹캠 좌표로 (몸을 옮겨 그린 만큼 뺀다)
    float d = dist(wx, wy, screenToCamX(webcamViewX(f.headX(), f.z)), screenToCamY(webcamViewY(f.headY(), f.z)));
    if (d < bestD) {
      bestD = d;
      best = f;
    }
  }
  return best;
}

// 두 색이 충분히 다른가 (같은 꽃·같은 색끼리는 꽃가루를 옮겨도 의미가 없다)
boolean differentColor(color a, color b) {
  return abs(red(a) - red(b)) + abs(green(a) - green(b)) + abs(blue(a) - blue(b)) > 40;
}

class Butterfly {
  float x, y, z;
  float t;                  // noise·날갯짓 위치 (나비마다 다르게)
  boolean carrying = false; // 꽃가루를 묻히고 있는가
  color pollen;             // 묻힌 꽃가루 색
  Flower lastVisited;       // 마지막에 앉았던 꽃
  boolean leaving = false;
  boolean gone = false;
  float alpha = 0;
  color wingColor;
  float facing = 1;         // 1이면 오른쪽을 보고 날고, -1이면 왼쪽

  Butterfly(float x, float y, float z) {
    this.x = x;
    this.y = y;
    this.z = z;
    t = random(1000);
    color[] wings = { color(255, 245, 210), color(255, 215, 120), color(200, 225, 255) };
    wingColor = wings[int(random(wings.length))];
  }

  void update() {
    // 손 흔들기를 멈춘 지 오래되면 떠난다
    if (!waving && millis() - lastWavingMs > BUTTERFLY_STAY_MS) leaving = true;

    float tx, ty, tz;
    Flower target = null;
    if (leaving) {
      // 위로, 바깥쪽으로 날아간다
      tx = x + 6 * facing;
      ty = y - 6;
      tz = z;
      alpha -= 3;
      if (alpha <= 0 || y < -150) gone = true;
    } else {
      alpha = min(255, alpha + 10);
      target = nearestOpenFlower(waveX, waveY);
      if (target != null) {
        tx = target.headX();
        ty = target.headY() - 5;   // 꽃 위에 살짝 떠서 앉는다
        tz = target.z;
      } else {
        tx = camToScreenX(waveX);  // 핀 꽃이 없으면 (캐릭터 몸 위의) 손 근처를 맴돈다
        ty = camToScreenY(waveY);
        tz = 0;
      }
    }

    // 이징으로 다가간다 + noise로 팔랑팔랑 흔들림
    float px = x;
    x += (tx - x) * 0.04 + (noise(t, frameCount * 0.03) - 0.5) * 2.5;
    y += (ty - y) * 0.04 + (noise(t + 300, frameCount * 0.03) - 0.5) * 2.5;
    z += (tz - z) * 0.04;
    if (abs(x - px) > 0.3) facing = (x > px) ? 1 : -1;

    // 꽃에 닿았다
    if (target != null && dist(x, y, z, tx, ty, tz) < 8 && target != lastVisited) {
      visit(target);
    }
  }

  // 꽃에 앉았을 때: 묻혀 온 꽃가루를 옮겨 주고, 이 꽃의 꽃가루를 묻힌다
  void visit(Flower f) {
    if (carrying && differentColor(pollen, f.petalColor)) {
      f.pollinated = true;
      f.pollenColor = pollen;
      // 꽃가루가 옮겨졌다는 표시로 반짝이 몇 개
      for (int k = 0; k < 6; k++) sparkles.add(new Sparkle(f.headX(), f.headY(), f.z));
    }
    pollen = f.petalColor;
    carrying = true;
    lastVisited = f;
  }

  void display() {
    if (alpha <= 0) return;
    // 꽃 위에 가만히 있으면 날갯짓이 느려진다
    boolean resting = lastVisited != null && dist(x, y, lastVisited.headX(), lastVisited.headY() - 5) < 10;
    float speed = resting ? 0.08 : 0.35;
    float flap = 0.25 + 0.95 * abs(sin(frameCount * speed + t));   // 0.25(펼침) ~ 1.2(접힘)

    pushMatrix();
    translate(x, y, z);
    scale(facing * 1.8, 1.8, 1.8);  // 날아가는 쪽을 보게 좌우 뒤집기 + 잘 보이게 키우기
    rotateZ(-0.25);                 // 나는 쪽으로 살짝 숙인다
    noStroke();
    for (int s = -1; s <= 1; s += 2) {
      pushMatrix();
      rotateY(s * flap);            // 몸통을 축으로 날개를 접었다 편다
      fill(wingColor, alpha);
      ellipse(s * 6, -3, 11, 9);    // 윗날개
      fill(lerpColor(wingColor, color(255, 170, 90), 0.35), alpha);
      ellipse(s * 4.5, 3.5, 7, 6);  // 아랫날개
      popMatrix();
    }
    fill(50, 40, 35, alpha);
    ellipse(0, 0, 2.5, 10);         // 몸통
    if (carrying) {
      fill(pollen, alpha);          // 묻히고 있는 꽃가루 (다리 쪽 작은 점)
      ellipse(0, 5, 3.5, 3.5);
    }
    popMatrix();
  }
}
