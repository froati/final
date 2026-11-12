// =====================================================
// Pose.pde — 자세 · 손 흔들기 · 기울기 (담당 A)
// 2026-11-11: 얼굴 찾기 + 움직임 방식 (배경을 찍지 않는다 — 화면 밖으로 비킬 필요 없음)
//
//   ① 기준: 얼굴이 보이고 2초 가만히 있으면, 그때의 화면(사람 포함)과 얼굴 위치·크기를 "기준"으로 저장한다.
//      → 평소 모습이 기준 화면에 들어 있으므로, 나중에 "기준과 달라진 곳" = 팔·손이 새로 들어온 곳이다.
//      사람이 3초 넘게 사라지면 기준을 지운다. 자리를 옮겨 얼굴이 멀리 가면 3초 가만히 있을 때 다시 잡는다. C 키로 다시.
//
//   ② 자세: 얼굴 크기(폭 fw)에 맞춘 영역 네 곳이 기준 화면과 얼마나 달라졌는지(0~1)를 본다.
//        ┌──────┐   ┌──────┐
//        │ 위 L │ 얼굴 │ 위 R │     위 L·R  = 머리 양옆과 위  → 손을 들면 팔이 들어온다
//        └──────┘   └──────┘
//   ┌──────┐               ┌──────┐
//   │ 옆 L │     몸통      │ 옆 R │  옆 L·R = 어깨 높이 바깥  → 팔을 벌리면 팔이 들어온다
//   └──────┘               └──────┘
//      위 양쪽 모두 POSE_UP 넘게 달라짐 → 두손들기
//      옆 양쪽 모두 POSE_SIDE 넘게 달라짐 → 팔벌리기
//      얼굴이 기준보다 얼굴 폭의 60% 넘게 내려감 → 웅크리기
//      그 밖 → 차렷.   같은 판정이 6프레임 이어져야 바뀐다(깜빡임 방지)
//      ※ 움직임이 아니라 "기준과의 차이"로 보므로, 손을 든 채 멈춰 있어도 두손들기로 남는다.
//      ※ 차렷으로 가만히 있을 때만 기준 화면을 아주 천천히 지금 화면 쪽으로 고친다 (조명 변화 따라가기)
//
//   ③ 손 흔들기: 움직인 칸이 "적게"(손 크기) 있는 프레임이 최근에 충분히 많으면 → 그 위치가 waveX·waveY
//   ④ 기울기: 얼굴이 기준보다 옆으로 간 만큼 → lean
//
// ⚠ 기준 숫자는 측정 전 임시값이다. 점검 화면(D)·웹캠 미리보기(조절판 showCamera)에 판정 숫자가 나오고
//   기록(L)에도 남는다 → A3-1 측정으로 고친다. "2초 유지했는가"는 B(Scene.pde)가 판단한다.
// 마우스판(웹캠 없을 때)은 키로 흉내 낸다: 1~4 자세 · W 손 흔들기 · ←→ 기울기 · 0 사람 없음
// =====================================================

// ---- 판정 기준 (임시 — A3-1 측정으로 고친다) ----
final float POSE_UP = 0.18;        // 위 영역 양쪽이 이 비율 넘게 달라지면 → 두손들기
final float POSE_SIDE = 0.18;      // 옆 영역 양쪽이 이 비율 넘게 달라지면 → 팔벌리기
final float POSE_DROP = 0.6;       // 얼굴이 기준보다 (얼굴 폭 × 0.6) 넘게 내려가면 → 웅크리기
final int POSE_STABLE_FRAMES = 6;  // 같은 판정이 이만큼 이어져야 자세가 바뀐다
final int WAVE_MIN_CELLS = 2;      // 손 흔들기: 이번 프레임에 움직인 칸이 이 수 이상
final int WAVE_MAX_CELLS = 20;     //            이 수 이하 (더 많으면 몸 전체·팔 크게 움직임 → 흩날림)
final int WAVE_WINDOW = 20;        // 최근 20프레임 중
final int WAVE_NEED = 12;          // 12프레임 넘게 "작게 움직임"이면 손 흔들기
final float LEAN_RANGE = 1.2;      // 기울기: 얼굴이 (기준 얼굴 폭 × 1.2)만큼 옆으로 가면 lean 1
final float LEAN_DEAD = 0.2;       // 이보다 작으면 0으로 본다

// ---- 마우스판 키 ----
boolean holdZero = false;   // 0 키를 누르고 있는가 (마우스판: 사람 없음)
boolean holdW = false;      // W 키 (마우스판: 손 흔들기)
boolean holdLeft = false;   // ← 키 (마우스판: 몸 기울기)
boolean holdRight = false;  // → 키
String fakePose = "차렷";   // 숫자 키로 고른 자세 (마우스판)

// ---- 기준 ----
boolean hasBase = false;
int[] refPixels;            // 기준 화면 (평소 모습의 사람 포함)
float baseFX, baseFY, baseFW;
int stillSinceMs = -1;      // 가만히 있기 시작한 시각
int goneSinceMs = -1;       // 사람이 사라진 시각
int movedSinceMs = -1;      // 얼굴이 기준 자리에서 멀어진 채 가만히 있기 시작한 시각
int baseSavedMs = -100000;  // 기준을 저장한 시각 (화면에 잠깐 알림)

// ---- 판정에 쓴 숫자 (점검 화면·미리보기·기록용) ----
float upL = 0, upR = 0, sideL = 0, sideR = 0, dropRatio = 0;
int movingCells = 0;
String candPose = "없음";
int candFrames = 0;
boolean[] waveHist = new boolean[WAVE_WINDOW];
int waveIdx = 0;

void updatePose() {
  if (!useCamera) {
    // 마우스판: 키로 고른 자세대로 가짜 몸을 만든다 (자세가 바뀔 때만)
    if (holdZero) pose = "없음";
    else pose = fakePose;
    if (!pose.equals(builtPose)) buildFakeBody(pose);
    return;
  }

  // ---- 웹캠: 사람이 없으면 ----
  if (personCount < 500) {
    pose = "없음";
    candPose = "없음";
    candFrames = 0;
    waving = false;
    lean *= 0.95;
    stillSinceMs = -1;
    if (goneSinceMs < 0) goneSinceMs = millis();
    if (hasBase && millis() - goneSinceMs > 3000) clearBase();   // 다음 사람을 위해 기준을 지운다
    return;
  }
  goneSinceMs = -1;
  boolean still = totalMotion < calmSensitivity * 0.3;

  // ---- ① 기준이 없으면: 2초 가만히 있을 때 자동 저장 ----
  if (!hasBase) {
    if (still && faceNow) {
      if (stillSinceMs < 0) stillSinceMs = millis();
      if (millis() - stillSinceMs > 2000) saveBase();
    } else if (!still) {
      stillSinceMs = -1;
    }
    pose = "차렷";   // 기준을 잡기 전에는 보통 자세로 본다
    updateWave();
    return;
  }

  // 자리를 옮겼으면(얼굴이 기준에서 얼굴 폭의 1.5배 넘게 멀어지거나 크기가 35% 넘게 바뀜) 3초 가만히 있을 때 다시 잡는다
  boolean moved = dist(faceX, faceY, baseFX, baseFY) > baseFW * 1.5 || abs(faceW - baseFW) > baseFW * 0.35;
  if (moved && still && faceNow) {
    if (movedSinceMs < 0) movedSinceMs = millis();
    if (millis() - movedSinceMs > 3000) saveBase();
  } else {
    movedSinceMs = -1;
  }

  // ---- ② 자세: 얼굴 둘레 영역이 기준과 얼마나 달라졌나 ----
  float fw = faceW;
  upL = zoneChange(faceX - 2.0 * fw, faceY - 2.0 * fw, faceX - 0.75 * fw, faceY + 0.2 * fw);
  upR = zoneChange(faceX + 0.75 * fw, faceY - 2.0 * fw, faceX + 2.0 * fw, faceY + 0.2 * fw);
  sideL = zoneChange(faceX - 4.0 * fw, faceY + 0.7 * fw, faceX - 2.0 * fw, faceY + 2.0 * fw);
  sideR = zoneChange(faceX + 2.0 * fw, faceY + 0.7 * fw, faceX + 4.0 * fw, faceY + 2.0 * fw);
  dropRatio = (faceY - baseFY) / baseFW;   // + 내려감

  String now;
  if (min(upL, upR) > POSE_UP) now = "두손들기";
  else if (min(sideL, sideR) > POSE_SIDE) now = "팔벌리기";
  else if (dropRatio > POSE_DROP) now = "웅크리기";
  else now = "차렷";

  if (now.equals(candPose)) candFrames++;
  else {
    candPose = now;
    candFrames = 1;
  }
  if (candFrames >= POSE_STABLE_FRAMES) pose = candPose;

  // 차렷으로 가만히 있으면 기준 화면을 아주 천천히 지금 화면 쪽으로 (15프레임마다 1/32)
  if (pose.equals("차렷") && still && frameCount % 15 == 0) blendReference();

  // ---- ③ 손 흔들기 · ④ 기울기 ----
  updateWave();
  float lt = (faceX - baseFX) / (baseFW * LEAN_RANGE);
  if (abs(lt) < LEAN_DEAD) lt = 0;
  lean += (constrain(lt, -1, 1) - lean) * 0.1;
}

// 영역(x0,y0)~(x1,y1) 안에서 기준 화면과 색이 threshold 넘게 다른 픽셀의 비율 (3픽셀씩 건너뛰며)
float zoneChange(float x0, float y0, float x1, float y1) {
  int ax = constrain(int(x0), 0, 639), bx = constrain(int(x1), 0, 639);
  int ay = constrain(int(y0), 0, 479), by = constrain(int(y1), 0, 479);
  float th2 = threshold * threshold;
  int total = 0, changed = 0;
  for (int y = ay; y < by; y += 3) {
    for (int x = ax; x < bx; x += 3) {
      int i = x + y * 640;
      int c = frame.pixels[i];
      int r = refPixels[i];
      int dr = ((c >> 16) & 0xFF) - ((r >> 16) & 0xFF);
      int dg = ((c >> 8) & 0xFF) - ((r >> 8) & 0xFF);
      int db = (c & 0xFF) - (r & 0xFF);
      if (dr * dr + dg * dg + db * db > th2) changed++;
      total++;
    }
  }
  if (total < 30) return 0;   // 영역이 거의 화면 밖이면 판단하지 않는다
  return changed / float(total);
}

void blendReference() {
  for (int i = 0; i < refPixels.length; i++) {
    int c = frame.pixels[i];
    int r = refPixels[i];
    int rr = (r >> 16) & 0xFF, rg = (r >> 8) & 0xFF, rb = r & 0xFF;
    rr += (((c >> 16) & 0xFF) - rr) / 32;
    rg += (((c >> 8) & 0xFF) - rg) / 32;
    rb += ((c & 0xFF) - rb) / 32;
    refPixels[i] = 0xFF000000 | (rr << 16) | (rg << 8) | rb;
  }
}

void saveBase() {
  frame.loadPixels();
  refPixels = frame.pixels.clone();
  baseFX = faceX;
  baseFY = faceY;
  baseFW = max(20, faceW);
  hasBase = true;
  baseSavedMs = millis();
  movedSinceMs = -1;
  candPose = "차렷";
  candFrames = 0;
  println("기준 자세 저장");
}

void clearBase() {
  hasBase = false;
  stillSinceMs = -1;
  upL = upR = sideL = sideR = dropRatio = 0;
}

// 손 흔들기: 움직인 칸이 "적게"(손 크기) 있는 프레임이 최근에 충분히 많으면 손 흔들기
void updateWave() {
  movingCells = 0;
  float sx = 0, sy = 0;
  for (int cx = 0; cx < COLS; cx++) {
    for (int cy = 0; cy < ROWS; cy++) {
      if (motion[cx][cy] > sensitivity) {
        movingCells++;
        sx += cx * CELL + CELL / 2;
        sy += cy * CELL + CELL / 2;
      }
    }
  }
  boolean small = movingCells >= WAVE_MIN_CELLS && movingCells <= WAVE_MAX_CELLS;
  waveHist[waveIdx] = small;
  waveIdx = (waveIdx + 1) % WAVE_WINDOW;
  int n = 0;
  for (boolean b : waveHist) if (b) n++;
  waving = n >= WAVE_NEED;
  if (small) {
    // 손 위치: 움직인 칸들의 가운데 (웹캠 좌표) — 부드럽게 따라간다
    waveX += (sx / movingCells - waveX) * 0.3;
    waveY += (sy / movingCells - waveY) * 0.3;
  }
}

// 기준 자세를 방금 저장했으면 화면에 잠깐 알림
void drawPoseNotice() {
  float t = (millis() - baseSavedMs) / 2000.0;
  if (t < 0 || t > 1) return;
  textAlign(CENTER, CENTER);
  fill(0, 150 * (1 - t));
  noStroke();
  rect(W / 2 - 90, 60, 180, 28, 14);
  fill(255, 255 * (1 - t));
  text("기준 자세 저장", W / 2, 73);
  textAlign(LEFT, BASELINE);
}

void inputKeyPressed() {
  if (key == CODED) {               // 화살표처럼 글자가 아닌 키는 keyCode로 본다
    if (keyCode == LEFT) holdLeft = true;
    if (keyCode == RIGHT) holdRight = true;
    return;
  }
  if (key == '0') holdZero = true;
  if (key == '1') fakePose = "차렷";
  if (key == '2') fakePose = "두손들기";
  if (key == '3') fakePose = "웅크리기";
  if (key == '4') fakePose = "팔벌리기";
  if (key == 'w' || key == 'W') holdW = true;
  if (key == 'c' || key == 'C') clearBase();           // 기준 다시 잡기 (2초 가만히 있으면 저장)
  if (key == 'm' || key == 'M') toggleInputMode();     // 웹캠 ↔ 마우스판
  if (key == '[') threshold = max(5, threshold - 5);   // "달라졌다"로 볼 색 차이 ↓ (팔을 들어도 안 잡히면)
  if (key == ']') threshold += 5;                      // ↑ (가만히 있는데도 자세가 바뀌면)
  if (key == '-') calmSensitivity = max(5, calmSensitivity - 10);  // 고요함 기준 ↓
  if (key == '=') calmSensitivity += 10;                            // ↑ (가만히 있는데도 고요함이 안 차면)
}

void inputKeyReleased() {
  if (key == CODED) {
    if (keyCode == LEFT) holdLeft = false;
    if (keyCode == RIGHT) holdRight = false;
    return;
  }
  if (key == '0') holdZero = false;
  if (key == 'w' || key == 'W') holdW = false;
}
