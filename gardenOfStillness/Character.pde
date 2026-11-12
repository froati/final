// =====================================================
// Character.pde — 정원의 캐릭터 (2026-11-11)
// 화면에는 웹캠 영상(사람)을 보여 주지 않는다. 정원 가운데에 캐릭터 하나가 서 있고,
// 웹캠은 "동작"만 알아낸다(Vision · Pose) → 캐릭터가 그 동작을 따라 한다.
//
//   pose 차렷     → 가만히 서서 숨 쉰다 (오래 고요하면 눈을 감는다)
//   pose 두손들기 → 두 팔을 머리 위로
//   pose 웅크리기 → 쪼그려 앉아 무릎을 감싼다
//   pose 팔벌리기 → 양팔을 옆으로 (덩굴이 손끝을 향해 자란다)
//   waving        → 손 흔드는 쪽 팔을 흔든다 (나비)
//   lean          → 몸을 그쪽으로 기울인다
//   크게 움직임    → 몸이 흔들린다
// 모든 각도는 목표값으로 이징해서 따라가므로 동작이 부드럽게 바뀐다.
//
// 캐릭터는 몸이 서는 자리(z = 2, 땅 y = GROUND_Y)에 선 판이다.
// 앞쪽 꽃(z > 2)은 캐릭터를 가리고, 캐릭터는 뒤쪽 평원을 가린다.
// =====================================================

// ---- 크기 (640×480 좌표) ----
final float CHAR_CX = 320;              // 화면 가운데
final float CHAR_FEET = GROUND_Y + 4;   // 발바닥 (잔디에 살짝 묻힌다)
final float CHAR_Z = 2;
final float LEG_LEN = 36;               // 허벅지·정강이 하나씩
final float TORSO_LEN = 74;
final float HEAD_R = 26;
final float UPPER_ARM = 34, FOREARM = 32;
final float SHOULDER_HALF = 26;         // 어깨 너비의 절반
// 캐릭터 머리 위 끝 ~ 발바닥 (웹캠 몸과 맞출 때 쓴다)
final float CHAR_TOP = CHAR_FEET - LEG_LEN * 2 - TORSO_LEN - HEAD_R * 2 + 6;
final float CHAR_H = CHAR_FEET - CHAR_TOP;

// ---- 지금 동작 상태 (목표로 이징) ----
float armL = 0.15, armR = 0.15;       // 어깨 각도: 0 = 아래, PI/2 = 옆, PI = 위 (바깥쪽이 +)
float elbowL = 0.1, elbowR = 0.1;     // 팔꿈치 굽힘 (+ 바깥, - 안쪽)
float crouch = 0;                     // 0 서 있음 ~ 1 쪼그려 앉음
float tilt = 0;                       // 몸 기울기 (라디안)
float shake = 0;                      // 크게 움직일 때 흔들림 세기
float eyeClose = 0;                   // 0 뜬 눈 ~ 1 감은 눈
float waveSide = 1;                   // 손 흔드는 쪽 (-1 화면 왼쪽 팔 · 1 오른쪽 팔)

// 이번 프레임 손끝 위치 (덩굴·나비가 쓴다, 화면 좌표)
PVector handL = new PVector(), handR = new PVector();

void updateCharacter() {
  float tArmL = 0.15, tArmR = 0.15, tElL = 0.1, tElR = 0.1, tCrouch = 0;
  if (pose.equals("두손들기")) {
    tArmL = tArmR = 2.75;
    tElL = tElR = 0.15;
  } else if (pose.equals("팔벌리기")) {
    tArmL = tArmR = HALF_PI;
    tElL = tElR = 0;
  } else if (pose.equals("웅크리기")) {
    tCrouch = 1;
    tArmL = tArmR = 0.35;
    tElL = tElR = -1.3;              // 팔을 안으로 굽혀 무릎을 감싼다
  }

  // 손 흔들기: 손 위치가 몸 중심의 어느 쪽인지로 팔을 고른다
  if (waving) {
    float wx = camToScreenX(waveX);
    waveSide = (wx < CHAR_CX) ? -1 : 1;
    float flap = 0.55 + 0.45 * sin(millis() * 0.012);   // 팔꿈치를 까딱까딱
    if (waveSide < 0) {
      tArmL = 2.3;
      tElL = flap;
    } else {
      tArmR = 2.3;
      tElR = flap;
    }
  }

  float k = 0.15;   // 따라가는 빠르기
  armL += (tArmL - armL) * k;
  armR += (tArmR - armR) * k;
  elbowL += (tElL - elbowL) * k;
  elbowR += (tElR - elbowR) * k;
  crouch += (tCrouch - crouch) * 0.1;
  tilt += (lean * 0.25 - tilt) * 0.1;
  float moveNow = (personCount >= 500) ? constrain(totalMotion / max(1, calmSensitivity), 0, 1) : 0;
  shake += (moveNow - shake) * 0.2;
  eyeClose += (((calm > 0.75) ? 1 : 0) - eyeClose) * 0.05;
}

// 팔 하나: 어깨(sx, sy)에서 바깥쪽(side)으로. 어깨 각도 a, 팔꿈치 e. 손끝 위치를 돌려준다
PVector armPoints(float sx, float sy, float side, float a, float e, PVector elbowOut) {
  float ex = sx + side * sin(a) * UPPER_ARM;
  float ey = sy + cos(a) * UPPER_ARM;
  float b = a + e;
  float hx = ex + side * sin(b) * FOREARM;
  float hy = ey + cos(b) * FOREARM;
  elbowOut.set(ex, ey);
  return new PVector(hx, hy);
}

// 두 점 사이를 둥근 막대로 (팔·다리)
void limb(float x1, float y1, float x2, float y2, float w) {
  float len = dist(x1, y1, x2, y2);
  pushMatrix();
  translate(x1, y1);
  rotate(atan2(y2 - y1, x2 - x1));
  rect(-w / 2, -w / 2, len + w, w, w / 2);
  popMatrix();
}

void drawCharacter() {
  if (personCount < 500) return;   // 사람이 없으면 캐릭터도 없다 (정원만 남는다)

  float t = millis() / 1000.0;
  float breathe = 1 + 0.02 * sin(t * 2);                    // 숨쉬기
  float wobble = shake * 0.08 * sin(t * 14);                // 크게 움직이면 흔들림

  // 몸의 기준점 (기울기·흔들림 전, 발바닥 가운데 기준)
  float hipDrop = crouch * 40;
  float hipY = CHAR_FEET - LEG_LEN * 2 + hipDrop;
  float shoulderY = hipY - TORSO_LEN * breathe + 12;
  float headY = hipY - TORSO_LEN * breathe - HEAD_R + 4;

  hint(DISABLE_DEPTH_MASK);

  // 그림자 (땅 위)
  pushMatrix();
  translate(CHAR_CX, GROUND_Y - 0.5, CHAR_Z);
  rotateX(HALF_PI);
  noStroke();
  fill(0, 55);
  ellipse(0, 0, 90 + crouch * 20, 22);
  popMatrix();

  pushMatrix();
  translate(CHAR_CX, CHAR_FEET, CHAR_Z);
  rotate(tilt + wobble);            // 발을 축으로 기울기
  translate(-CHAR_CX, -CHAR_FEET);
  noStroke();

  color skin = color(250, 226, 196);
  color cloth = color(118, 172, 112);
  color clothDark = color(82, 128, 84);
  color shoe = color(112, 82, 58);

  // 다리: 쪼그리면 무릎이 바깥으로 나오고 엉덩이가 내려간다
  for (int s = -1; s <= 1; s += 2) {
    float hipX = CHAR_CX + s * 11;
    float footX = CHAR_CX + s * 16;
    float kneeX = CHAR_CX + s * (13 + crouch * 22);
    float kneeY = lerp(CHAR_FEET - LEG_LEN, hipY + 6, crouch * 0.6);
    fill(clothDark);
    limb(hipX, hipY, kneeX, kneeY, 15);
    limb(kneeX, kneeY, footX, CHAR_FEET - 6, 14);
    fill(shoe);
    ellipse(footX + s * 3, CHAR_FEET - 4, 22, 11);
  }

  // 몸통
  fill(cloth);
  rect(CHAR_CX - 25, shoulderY - 6, 50, hipY - shoulderY + 14, 18);
  fill(clothDark);
  rect(CHAR_CX - 25, hipY - 6, 50, 9, 4);                  // 허리띠

  // 팔
  PVector elbow = new PVector();
  PVector hl = armPoints(CHAR_CX - SHOULDER_HALF, shoulderY + 4, -1, armL, elbowL, elbow);
  fill(cloth);
  limb(CHAR_CX - SHOULDER_HALF, shoulderY + 4, elbow.x, elbow.y, 13);
  fill(skin);
  limb(elbow.x, elbow.y, hl.x, hl.y, 11);
  ellipse(hl.x, hl.y, 14, 14);
  PVector hr = armPoints(CHAR_CX + SHOULDER_HALF, shoulderY + 4, 1, armR, elbowR, elbow);
  fill(cloth);
  limb(CHAR_CX + SHOULDER_HALF, shoulderY + 4, elbow.x, elbow.y, 13);
  fill(skin);
  limb(elbow.x, elbow.y, hr.x, hr.y, 11);
  ellipse(hr.x, hr.y, 14, 14);

  // 머리
  fill(skin);
  ellipse(CHAR_CX, headY, HEAD_R * 2, HEAD_R * 2);
  // 볼
  fill(255, 160, 150, 120);
  ellipse(CHAR_CX - 14, headY + 7, 9, 5);
  ellipse(CHAR_CX + 14, headY + 7, 9, 5);
  // 눈: 고요하면 감는다
  fill(60, 45, 40);
  float eh = lerp(6, 1.5, eyeClose);
  ellipse(CHAR_CX - 9, headY - 1, 5, eh);
  ellipse(CHAR_CX + 9, headY - 1, 5, eh);
  // 입
  noFill();
  stroke(60, 45, 40);
  strokeWeight(1.5);
  arc(CHAR_CX, headY + 8, 10, 6, 0.2, PI - 0.2);
  noStroke();

  // 머리 위 새싹 — 바람 방향으로 흔들린다
  float sway = (noise(t * 0.8) - 0.5) * 0.4 + windX() * 0.5;
  pushMatrix();
  translate(CHAR_CX, headY - HEAD_R + 2);
  rotate(sway);
  stroke(90, 150, 70);
  strokeWeight(2.5);
  line(0, 0, 0, -14);
  noStroke();
  fill(120, 190, 90);
  pushMatrix();
  translate(0, -14);
  rotate(-0.6);
  ellipse(-7, 0, 14, 7);
  popMatrix();
  pushMatrix();
  translate(0, -14);
  rotate(0.6);
  ellipse(7, 0, 14, 7);
  popMatrix();
  popMatrix();

  // 손끝 위치를 화면 좌표로 저장 (기울기까지 반영 — screenX 대신 직접 돌린다)
  handL = rotateAroundFeet(hl, tilt + wobble);
  handR = rotateAroundFeet(hr, tilt + wobble);

  popMatrix();
  hint(ENABLE_DEPTH_MASK);
}

PVector rotateAroundFeet(PVector p, float ang) {
  float dx = p.x - CHAR_CX, dy = p.y - CHAR_FEET;
  return new PVector(CHAR_CX + dx * cos(ang) - dy * sin(ang), CHAR_FEET + dx * sin(ang) + dy * cos(ang));
}

// ================= 웹캠 좌표 ↔ 캐릭터(화면) 좌표 =================
// 웹캠 속 얼굴을 캐릭터 머리에 겹친다: 얼굴 가운데 → 캐릭터 머리 가운데, 얼굴 폭 → 캐릭터 머리 지름.
// 그래서 "오른손을 휘두르면 캐릭터 오른손 근처 꽃이 흩날리고", 손 흔드는 자리 근처로 나비가 온다.
// 마우스판은 가짜 몸이 이미 캐릭터 자리에 있으니 그대로(1:1) 쓴다.
final float CHAR_HEAD_Y = CHAR_FEET - LEG_LEN * 2 - TORSO_LEN - HEAD_R + 4;   // 서 있을 때 머리 가운데
boolean mapIdentity() { return !useCamera || personCount < 500; }
float camScale() { return HEAD_R * 2 / max(20, faceW); }

float camToScreenX(float x) {
  if (mapIdentity()) return x;
  return CHAR_CX + (x - faceX) * camScale();
}
float camToScreenY(float y) {
  if (mapIdentity()) return y;
  return CHAR_HEAD_Y + (y - faceY) * camScale();
}
float screenToCamX(float x) {
  if (mapIdentity()) return x;
  return faceX + (x - CHAR_CX) / camScale();
}
float screenToCamY(float y) {
  if (mapIdentity()) return y;
  return faceY + (y - CHAR_HEAD_Y) / camScale();
}

// ================= 웹캠 미리보기 (조절판 showCamera) =================
// 판정을 점검할 때만: 화면 오른쪽 위에 웹캠 화면을 작게, 얼굴 상자와 판정 영역 네 곳을 겹쳐 보여 준다
// 영역은 "기준과 달라진 비율"만큼 진하게 칠해진다 (넘으면 노랑)
void drawCameraPreview() {
  if (!showCamera || !useCamera) return;
  float pw = 192, ph = 144, px = W - pw - 8, py = 8;
  float sx = pw / 640.0, sy = ph / 480.0;
  noStroke();
  fill(0, 160);
  rect(px - 3, py - 3, pw + 6, ph + 6, 4);
  image(frame, px, py, pw, ph);
  if (personCount < 500) return;
  float fw = faceW;
  if (hasBase) {
    previewZone(px, py, sx, sy, faceX - 2.0 * fw, faceY - 2.0 * fw, faceX - 0.75 * fw, faceY + 0.2 * fw, upL, POSE_UP);
    previewZone(px, py, sx, sy, faceX + 0.75 * fw, faceY - 2.0 * fw, faceX + 2.0 * fw, faceY + 0.2 * fw, upR, POSE_UP);
    previewZone(px, py, sx, sy, faceX - 4.0 * fw, faceY + 0.7 * fw, faceX - 2.0 * fw, faceY + 2.0 * fw, sideL, POSE_SIDE);
    previewZone(px, py, sx, sy, faceX + 2.0 * fw, faceY + 0.7 * fw, faceX + 4.0 * fw, faceY + 2.0 * fw, sideR, POSE_SIDE);
  }
  noFill();
  stroke(255, 80, 80);
  strokeWeight(1);
  rect(px + (faceX - fw / 2) * sx, py + (faceY - fw / 2) * sy, fw * sx, fw * sy);   // 얼굴
  if (hasBase) {
    stroke(120, 220, 255);
    ellipse(px + baseFX * sx, py + baseFY * sy, 5, 5);                           // 기준 얼굴 자리
  }
  noStroke();
}

void previewZone(float px, float py, float sx, float sy, float x0, float y0, float x1, float y1, float v, float limit) {
  x0 = constrain(x0, 0, 640); x1 = constrain(x1, 0, 640);
  y0 = constrain(y0, 0, 480); y1 = constrain(y1, 0, 480);
  if (x1 <= x0 || y1 <= y0) return;
  if (v > limit) fill(255, 220, 60, 150);
  else fill(120, 220, 255, 40 + 150 * v / limit);
  stroke(255, 120);
  strokeWeight(0.5);
  rect(px + x0 * sx, py + y0 * sy, (x1 - x0) * sx, (y1 - y0) * sy);
  noStroke();
}
