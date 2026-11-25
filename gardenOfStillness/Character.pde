// =====================================================
// Character.pde — 1인칭 시점 (2026-11-25)
// 화면에는 정원만 보인다. 관객이 정원 안에 서서 자기 눈으로 보는 시점이고,
// 사람 모습(웹캠 영상)도, 내 몸(팔·손·무릎)도 그리지 않는다.
// 웹캠은 "동작"만 알아내고(Vision · Pose), 정원이 그 동작에 반응한다.
//
// 여기서 하는 일은 두 가지다.
//   ① 덩굴의 목표점: 팔을 벌리면 (보이지 않는) 양손이 화면 양 끝에 있다고 보고 그 위치를 handL·handR에 둔다
//   ② 웹캠 좌표 ↔ 화면 좌표: 흩날림·나비가 "화면의 어디"인지 맞춘다 (아래 camToScreen·screenToCam)
// 시점(카메라)은 그대로다: 기본 카메라의 눈높이(땅에서 200)가 사람 눈높이와 같다.
// =====================================================

final float FP_CX = 320;                // 화면 가운데

// ---- 덩굴의 목표점 (보이지 않는 양손, 화면 좌표) ----
// 팔 각도 a: 0 = 내림 · PI/2 = 옆으로 벌림 · 2.75 = 위로 듦. 목표로 이징해서 부드럽게 옮긴다
final float FP_SHOULDER_HALF = 150;     // 어깨 너비의 절반
final float FP_REACH_X = 130;           // 팔을 옆으로 뻗었을 때 가로로 더 나가는 길이
// 손 높이 = FP_ARM_Y0 + cos(a)·FP_DOWN − sin(a)·FP_UP → 내림 y≈940 · 옆 y≈260 · 위 y≈130
final float FP_ARM_Y0 = 583;
final float FP_DOWN = 357;
final float FP_UP = 323;

float armL = 0.15, armR = 0.15;
PVector handL = new PVector(), handR = new PVector();   // 덩굴이 쓴다

void updateCharacter() {
  float tArm = 0.15;
  if (pose.equals("두손들기")) tArm = 2.75;
  else if (pose.equals("팔벌리기")) tArm = HALF_PI;
  armL += (tArm - armL) * 0.15;
  armR += (tArm - armR) * 0.15;
  handL = handPos(-1, armL);
  handR = handPos(1, armR);
}

// 손 위치: side -1 왼쪽 · 1 오른쪽. 화면 안으로 맞춘다
PVector handPos(float side, float a) {
  float x = FP_CX + side * (FP_SHOULDER_HALF + sin(a) * FP_REACH_X);
  float y = FP_ARM_Y0 + cos(a) * FP_DOWN - sin(a) * FP_UP - 40;
  return new PVector(constrain(x, 10, W - 10), constrain(y, 20, GROUND_Y - 10));
}

// ================= 웹캠 좌표 ↔ 화면 좌표 =================
// 1인칭: 웹캠 속 얼굴 = 내 눈. 얼굴 가운데를 화면의 "몸 기준점"(FP_CX, FP_HEAD_Y)에 겹치고,
// 얼굴 폭을 FP_FACE_PX로 키운다 → 팔을 벌리면 화면 양 끝, 손을 들면 화면 위쪽에 닿는다.
// 그래서 "오른손을 휘두르면 화면 오른쪽 꽃이 흩날리고", 손 흔드는 자리 근처로 나비가 온다.
final float FP_HEAD_Y = 330;     // 얼굴 가운데가 겹칠 화면 높이
final float FP_FACE_PX = 95;     // 얼굴 폭이 화면에서 차지하는 크기
boolean mapIdentity() { return personCount < 500; }
float camScale() { return FP_FACE_PX / max(20, faceW); }

float camToScreenX(float x) {
  if (mapIdentity()) return x;
  return FP_CX + (x - faceX) * camScale();
}
float camToScreenY(float y) {
  if (mapIdentity()) return y;
  return FP_HEAD_Y + (y - faceY) * camScale();
}
float screenToCamX(float x) {
  if (mapIdentity()) return x;
  return faceX + (x - FP_CX) / camScale();
}
float screenToCamY(float y) {
  if (mapIdentity()) return y;
  return faceY + (y - FP_HEAD_Y) / camScale();
}

// ================= 웹캠 미리보기 (조절판 showCamera) =================
// 판정을 점검할 때만: 화면 오른쪽 위 작은 판에 얼굴 상자와 판정 영역 네 곳을 보여 준다
// ※ 사람 모습(웹캠 영상)은 그리지 않는다 — 어두운 판 위에 판정 표시만
// 영역은 "기준과 달라진 비율"만큼 진하게 칠해진다 (넘으면 노랑)
void drawCameraPreview() {
  if (!showCamera || !useCamera) return;
  float pw = 192, ph = 144, px = W - pw - 8, py = 8;
  float sx = pw / 640.0, sy = ph / 480.0;
  noStroke();
  fill(0, 160);
  rect(px - 3, py - 3, pw + 6, ph + 6, 4);
  fill(20, 30, 40);
  rect(px, py, pw, ph);   // 웹캠 영상 대신 빈 판
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
