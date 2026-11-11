// =====================================================
// Vine.pde — 덩굴 (담당 B, B4-3)
// 팔 벌리기가 poseHold초 유지되는 동안, 양팔 끝을 "목표"로 땅에서 덩굴이 한 마디씩 자란다.
// 자라는 빠르기는 꽃과 같은 growSpeed × calm × light (growthFactor) — 움직이면 멈춘다.
// 마디는 sin()으로 구불거리고, 마디 끝에 가끔 꽃이 핀다 (그 꽃도 한살이를 따른다).
// 팔을 내리면 덩굴은 거기서 멈추고, 한동안(lifespanSec) 지나면 시들어 사라진다.
//
// 팔 끝 = 실루엣 가장자리 점(edgePoints) 중 가장 왼쪽 · 가장 오른쪽 점 (A의 값만 읽는다)
// =====================================================

final float VINE_SEG = 8;          // 마디 하나 길이
final float VINE_FLOWER_P = 0.12;  // 마디마다 꽃이 필 확률
final int MAX_VINES = 6;

Vine leftVine, rightVine;          // 지금 자라고 있는 왼쪽·오른쪽 덩굴

void updateVines() {
  float heldSec = (millis() - poseStartMs) / 1000.0;
  boolean armsOpen = personCount >= 500 && pose.equals("팔벌리기") && heldSec >= poseHold && edgePoints.size() > 0;

  if (armsOpen) {
    // 팔 끝 찾기
    PVector tipL = edgePoints.get(0);
    PVector tipR = edgePoints.get(0);
    for (PVector e : edgePoints) {
      if (e.x < tipL.x) tipL = e;
      if (e.x > tipR.x) tipR = e;
    }
    // 덩굴이 없거나 시드는 중이면 새로 심는다 (팔 끝 바로 아래 바깥쪽 땅)
    if (leftVine == null || leftVine.wilt > 0) leftVine = plantVine(tipL.x - 20);
    if (rightVine == null || rightVine.wilt > 0) rightVine = plantVine(tipR.x + 20);
    leftVine.grow(tipL);
    rightVine.grow(tipR);
  }

  for (int i = vines.size() - 1; i >= 0; i--) {
    Vine v = vines.get(i);
    v.update();
    if (v.dead) {
      if (v == leftVine) leftVine = null;
      if (v == rightVine) rightVine = null;
      vines.remove(i);
    }
  }
}

Vine plantVine(float x) {
  if (vines.size() >= MAX_VINES) vines.remove(0);   // 너무 많으면 가장 오래된 것부터
  Vine v = new Vine(x, GROUND_Y, 3);
  vines.add(v);
  return v;
}

class Vine {
  ArrayList<PVector> nodes = new ArrayList<PVector>();   // 마디 끝 위치들 (첫 점 = 뿌리)
  float z;
  float progress = 0;     // 다음 마디까지 쌓인 성장 (1이 되면 한 마디)
  boolean reached = false;
  int idleFrames = 0;     // 자라지 않은 지 몇 프레임
  float wilt = 0;         // 시든 정도 0~1
  boolean dead = false;
  float phase;            // 덩굴마다 다르게 구불거리게
  color flowerColor;      // 이 덩굴에 피는 꽃 색

  Vine(float x, float y, float z) {
    this.z = z;
    nodes.add(new PVector(x, y));
    phase = random(TWO_PI);
    flowerColor = palette[int(random(palette.length))];
  }

  // 팔 끝(target)을 향해 자란다 — growthFactor가 0이면(움직임·밤) 자라지 않는다
  void grow(PVector target) {
    if (reached || wilt > 0) return;
    float step = growSpeed * growthFactor() * 2.2;
    if (step <= 0) return;
    idleFrames = 0;
    progress += step;
    while (progress >= 1 && !reached) {
      progress -= 1;
      addNode(target);
    }
  }

  void addNode(PVector target) {
    PVector last = nodes.get(nodes.size() - 1);
    float dir = atan2(target.y - last.y, target.x - last.x);   // 목표 쪽 방향
    float wiggle = sin(nodes.size() * 0.7 + phase) * 0.6;      // sin으로 좌우로 구불
    float a = dir + wiggle;
    PVector n = new PVector(last.x + cos(a) * VINE_SEG, last.y + sin(a) * VINE_SEG);
    nodes.add(n);
    if (dist(n.x, n.y, target.x, target.y) < VINE_SEG * 1.5) reached = true;
    // 마디 끝에 가끔 꽃 (처음 몇 마디는 건너뛴다)
    if (nodes.size() > 5 && random(1) < VINE_FLOWER_P) {
      addFlower(new Flower(n.x, n.y, z + 1, mutate(flowerColor)));
    }
  }

  void update() {
    idleFrames++;
    if (idleFrames > lifespanSec * 60) wilt += 0.004;   // 오래 안 자라면 약 4초에 걸쳐 시든다
    if (wilt >= 1) dead = true;
  }

  void display() {
    color c = lerpColor(color(60, 135, 60), color(125, 105, 65), wilt);
    float alpha = 255 * (1 - wilt * 0.7);
    stroke(c, alpha);
    strokeWeight(max(1.5, 4.5 * depthScale(z)));
    noFill();
    beginShape();
    for (PVector n : nodes) vertex(n.x, n.y, z);
    endShape();
    noStroke();
    // 마디 두 개마다 잎 하나 — 번갈아 왼쪽·오른쪽
    fill(c, alpha);
    for (int k = 2; k < nodes.size(); k += 2) {
      PVector a = nodes.get(k - 1);
      PVector b = nodes.get(k);
      float ang = atan2(b.y - a.y, b.x - a.x) + ((k / 2) % 2 == 0 ? 0.9 : -0.9);
      pushMatrix();
      translate(b.x, b.y, z + 0.5);
      rotateZ(ang);
      fill(lerpColor(c, color(120, 190, 90), 0.35), alpha);   // 잎은 줄기보다 조금 밝게
      ellipse(6, 0, 12, 5);
      popMatrix();
    }
  }
}
