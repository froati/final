// =====================================================
// Vision.pde — 입력 (담당 A)
// 웹캠 → (거울처럼 좌우 뒤집기) → 칸별 움직임 → 배경 빼기 → 4×4 블록으로 잡음 정리
//      → isPerson · 상자 · 무게중심 · 가장자리 점 · 회색 인간 실루엣
// 웹캠이 없거나 M 키를 누르면 예전 "마우스판 가짜 입력"으로 돈다.
// 06-2 §2 약속 값의 이름·뜻은 그대로다.
//
// 시작 순서: 카메라 밖으로 나간다 → B 키(빈 배경 찍기) → 화면 앞에 선다
// =====================================================

import processing.video.*;

final int CELL = 20;   // 칸 한 변 (픽셀)
final int COLS = 32;   // 640 / 20
final int ROWS = 24;   // 480 / 20
final int BLK = 4;     // 잡음 정리용 블록 한 변 (픽셀)
final int BW = 160;    // 640 / 4
final int BH = 120;    // 480 / 4
final float MOTION_NOISE = 4;   // 칸 움직임이 이보다 작으면 카메라 잡음으로 보고 전체 합에서 뺀다

// ---- 둘 사이 약속 값 (A가 채우고 B가 읽는다) — 이름·뜻을 바꾸려면 06-2 §2부터 고친다 ----
boolean[] isPerson = new boolean[640 * 480];          // 픽셀마다 사람인지
int personCount = 0;                                  // 사람 픽셀 수
float[][] motion = new float[COLS][ROWS];             // 칸마다 움직임 양
float totalMotion = 0;                                // 전체 움직임 합 (잡음 뺀 값)
ArrayList<PVector> edgePoints = new ArrayList<PVector>();  // 실루엣 가장자리 점 (덩굴이 향할 팔 끝을 여기서 찾는다)
int boxLeft, boxRight, boxTop, boxBottom;             // 둘레 상자
float centerX, centerY;                               // 무게중심
String pose = "없음";                                 // 지금 프레임의 자세 이름
boolean waving = false;                               // 손만 흔드는 중인지
float waveX, waveY;                                   // 흔드는 위치
float lean = 0;                                       // 몸 기울기 (왼쪽 -1 ~ 오른쪽 1) — A4-4, 지금은 ←→ 키

// ---- 웹캠 ----
Capture cam;
boolean useCamera = false;     // true면 웹캠, false면 마우스판
PImage frame;                  // 거울처럼 뒤집은 이번 프레임 (640×480)
int[] bgPixels;                // B 키로 찍은 빈 배경 (없으면 null)
float[] prevBright = new float[640 * 480];   // 전 프레임 밝기 (움직임 계산용)
int[] blockCount = new int[BW * BH];         // 블록마다 "배경과 다른" 픽셀 수
boolean[] blockPerson = new boolean[BW * BH];
boolean[] blockTemp = new boolean[BW * BH];

// ---- 화면에 그릴 회색 인간 ----
PImage silhouette;
String builtPose = "";         // 마우스판: 가짜 몸을 마지막으로 만든 자세

void initInput() {
  silhouette = createImage(640, 480, ARGB);
  frame = createImage(640, 480, RGB);

  // ※ 3D(P3D) 모드에서는 Video 라이브러리가 카메라 영상을 그래픽카드로만 보내서 pixels[]가 전부 0(검정)이 된다.
  //    라이브러리 안의 설정(useGLBufferSink)을 꺼서 pixels[]에 영상이 들어오게 한다.
  //    공개된 설정이 아니라서 자바 리플렉션으로 바꾼다 (2026-11-10 이 노트북에서 확인: 끄기 전 밝기 0 → 끈 뒤 126)
  try {
    java.lang.reflect.Field f = Video.class.getDeclaredField("useGLBufferSink");
    f.setAccessible(true);
    f.set(null, false);
  } catch (Exception e) {
    println("useGLBufferSink를 끄지 못함 — 웹캠 영상이 검게 나올 수 있다: " + e);
  }

  String[] cams = Capture.list();
  printArray(cams);            // 연결된 카메라 목록 (CH14)
  if (cams.length > 0) {
    try {
      cam = new Capture(this, 640, 480, pickCamera(cams));
      cam.start();
      useCamera = true;
    } catch (Exception e) {
      println("웹캠을 열 수 없어 마우스판으로 돈다: " + e);
    }
  }
  applyModeDefaults();
}

// 가상 카메라(Virtual)는 건너뛰고 진짜 카메라를 고른다
String pickCamera(String[] cams) {
  for (String c : cams) {
    if (!c.contains("Virtual")) return c;
  }
  return cams[0];
}

// 입력 방식마다 움직임 숫자의 크기가 달라서 기준값을 따로 둔다 (A1-5 측정으로 고칠 값)
void applyModeDefaults() {
  if (useCamera) {
    sensitivity = 15;        // 칸 평균 밝기 차이
    calmSensitivity = 150;   // 잡음 뺀 칸 움직임의 합
  } else {
    sensitivity = 12;        // 마우스 속도 (픽셀/프레임)
    calmSensitivity = 12;
    builtPose = "";          // 가짜 몸을 다시 만들게
  }
}

void toggleInputMode() {
  if (cam == null) return;   // 웹캠이 없으면 바꿀 수 없다
  useCamera = !useCamera;
  applyModeDefaults();
}

void captureBackground() {
  if (useCamera) {
    frame.loadPixels();
    bgPixels = frame.pixels.clone();   // 지금 화면을 배경으로 저장
    println("배경 저장");
  }
}

// 매 프레임
void updateInput() {
  if (useCamera) updateCameraInput();
  else updateMouseInput();

  // 손 흔들기 (4주차 나비용) — 지금은 W를 누르는 동안
  waving = holdW;
  waveX = mouseX;
  waveY = mouseY;

  // 몸 기울기 (A4-4 전까지 임시) — ←→ 키를 누르는 동안 그쪽으로 천천히 기운다
  float leanTarget = 0;
  if (holdLeft) leanTarget -= 1;
  if (holdRight) leanTarget += 1;
  lean += (leanTarget - lean) * 0.05;
}

// ================= 웹캠 =================
void updateCameraInput() {
  if (!cam.available()) return;      // 새 프레임이 없으면 지난 값 그대로
  cam.read();
  if (cam.width == 0) return;

  PImage src = cam;
  if (cam.width != 640 || cam.height != 480) {
    src = cam.get();
    src.resize(640, 480);            // 카메라가 다른 크기를 주면 맞춘다
  }
  src.loadPixels();
  frame.loadPixels();
  for (int y = 0; y < 480; y++) {
    for (int x = 0; x < 640; x++) {
      frame.pixels[x + y * 640] = src.pixels[(639 - x) + y * 640];   // 좌우 뒤집기 = 거울
    }
  }
  frame.updatePixels();

  findMotion();
  findPerson();
}

// 밝기를 빠르게: (빨강 + 초록 + 파랑) / 3  (brightness()보다 훨씬 빠르다)
float fastBright(int c) {
  return (((c >> 16) & 0xFF) + ((c >> 8) & 0xFF) + (c & 0xFF)) / 3.0;
}

// ① 칸별 움직임: 칸마다 전 프레임과의 밝기 차이 평균 (06-1 §4-2, 칸 안에서 2픽셀씩 건너뛴다)
void findMotion() {
  totalMotion = 0;
  for (int cx = 0; cx < COLS; cx++) {
    for (int cy = 0; cy < ROWS; cy++) {
      float diffSum = 0;
      for (int y = cy * CELL; y < cy * CELL + CELL; y += 2) {
        for (int x = cx * CELL; x < cx * CELL + CELL; x += 2) {
          int i = x + y * 640;
          float b = fastBright(frame.pixels[i]);
          diffSum += abs(b - prevBright[i]);
          prevBright[i] = b;                       // 다음 프레임 비교용으로 저장
        }
      }
      motion[cx][cy] = diffSum / 100;              // 칸 안 100개 픽셀의 평균
      totalMotion += max(0, motion[cx][cy] - MOTION_NOISE);
    }
  }
}

// ② 배경 빼기 → 블록 정리 → 사람 픽셀 · 상자 · 중심 · 가장자리 · 회색 인간
void findPerson() {
  edgePoints.clear();
  if (bgPixels == null) {          // 배경을 아직 안 찍었으면 사람을 찾지 않는다
    personCount = 0;
    silhouette.loadPixels();
    java.util.Arrays.fill(silhouette.pixels, 0);
    silhouette.updatePixels();
    return;
  }

  // 2-1) 픽셀마다 배경과 색 차이가 threshold보다 크면 그 블록의 개수 +1
  java.util.Arrays.fill(blockCount, 0);
  float th2 = threshold * threshold;         // dist() 대신 제곱끼리 비교 (빠르다)
  for (int y = 0; y < 480; y++) {
    for (int x = 0; x < 640; x++) {
      int i = x + y * 640;
      int c = frame.pixels[i];
      int b = bgPixels[i];
      int dr = ((c >> 16) & 0xFF) - ((b >> 16) & 0xFF);
      int dg = ((c >> 8) & 0xFF) - ((b >> 8) & 0xFF);
      int db = (c & 0xFF) - (b & 0xFF);
      if (dr * dr + dg * dg + db * db > th2) {
        blockCount[(y / BLK) * BW + (x / BLK)]++;
      }
    }
  }

  // 2-2) 블록 16픽셀 중 절반 이상이 달라야 "사람 블록" → 점 잡음이 사라진다
  for (int k = 0; k < BW * BH; k++) blockTemp[k] = blockCount[k] >= 8;
  // 이웃 4블록 중 2개 이상이 사람이어야 남긴다 → 외톨이 블록(잡음)을 지운다
  for (int by = 0; by < BH; by++) {
    for (int bx = 0; bx < BW; bx++) {
      int k = by * BW + bx;
      int n = 0;
      if (bx > 0 && blockTemp[k - 1]) n++;
      if (bx < BW - 1 && blockTemp[k + 1]) n++;
      if (by > 0 && blockTemp[k - BW]) n++;
      if (by < BH - 1 && blockTemp[k + BW]) n++;
      blockPerson[k] = blockTemp[k] && n >= 2;
    }
  }

  // 2-3) 픽셀마다: 사람이면 카메라 밝기로 명암을 준 회색, 아니면 투명
  personCount = 0;
  boxLeft = 640;
  boxRight = 0;
  boxTop = 480;
  boxBottom = 0;
  float sumX = 0, sumY = 0;
  silhouette.loadPixels();
  for (int y = 0; y < 480; y++) {
    for (int x = 0; x < 640; x++) {
      int i = x + y * 640;
      boolean p = blockPerson[(y / BLK) * BW + (x / BLK)];
      isPerson[i] = p;
      if (p) {
        personCount++;
        if (x < boxLeft) boxLeft = x;
        if (x > boxRight) boxRight = x;
        if (y < boxTop) boxTop = y;
        if (y > boxBottom) boxBottom = y;
        sumX += x;
        sumY += y;
        int g = int(70 + fastBright(frame.pixels[i]) * 0.5);   // 70~197 사이 회색 — 얼굴·옷 명암이 남는다
        silhouette.pixels[i] = 0xFF000000 | (g << 16) | (g << 8) | g;
      } else {
        silhouette.pixels[i] = 0;                                // 완전히 투명
      }
    }
  }
  silhouette.updatePixels();

  // 사람이 없을 때 0으로 나누지 않게 (06-2 0-2의 5번)
  if (personCount > 0) {
    centerX = sumX / personCount;
    centerY = sumY / personCount;
  } else {
    centerX = 320;
    centerY = 240;
    boxLeft = boxRight = boxTop = boxBottom = 0;
  }

  // 2-4) 가장자리 점: 사람 블록인데 옆 블록 하나라도 배경인 곳의 가운데
  for (int by = 1; by < BH - 1; by++) {
    for (int bx = 1; bx < BW - 1; bx++) {
      int k = by * BW + bx;
      if (blockPerson[k] && (!blockPerson[k - 1] || !blockPerson[k + 1] || !blockPerson[k - BW] || !blockPerson[k + BW])) {
        edgePoints.add(new PVector(bx * BLK + BLK / 2, by * BLK + BLK / 2));
      }
    }
  }
}

// ================= 마우스판 (웹캠 없을 때 · 시험용) =================
void updateMouseInput() {
  for (int cx = 0; cx < COLS; cx++) {
    for (int cy = 0; cy < ROWS; cy++) {
      motion[cx][cy] = 0;
    }
  }
  // 이번 프레임에 마우스가 지나간 칸들에 마우스 속도를 넣는다
  float speed = dist(mouseX, mouseY, pmouseX, pmouseY);
  if (speed > 0) {
    int steps = int(speed / (CELL / 2)) + 1;
    for (int s = 0; s <= steps; s++) {
      float x = lerp(pmouseX, mouseX, s / float(steps));
      float y = lerp(pmouseY, mouseY, s / float(steps));
      int cx = constrain(int(x / CELL), 0, COLS - 1);
      int cy = constrain(int(y / CELL), 0, ROWS - 1);
      motion[cx][cy] = speed;
    }
  }
  totalMotion = speed;
}

// 가짜 몸: 자세에 맞는 사람 모양을 그려서 웹캠처럼 isPerson · 상자 · 가장자리 점을 구한다
void buildFakeBody(String p) {
  PGraphics g = createGraphics(640, 480);
  g.beginDraw();
  g.background(0);
  g.noStroke();
  g.fill(255);
  float cx = 320;
  if (p.equals("차렷") || p.equals("두손들기") || p.equals("팔벌리기")) {
    g.ellipse(cx, 150, 52, 62);              // 머리
    g.rect(cx - 32, 182, 64, 150, 12);       // 몸통
    g.rect(cx - 28, 330, 24, 110, 6);        // 왼다리
    g.rect(cx + 4, 330, 24, 110, 6);         // 오른다리
    if (p.equals("차렷")) {
      g.rect(cx - 48, 186, 16, 130, 8);
      g.rect(cx + 32, 186, 16, 130, 8);
    } else if (p.equals("두손들기")) {
      g.rect(cx - 48, 60, 16, 140, 8);
      g.rect(cx + 32, 60, 16, 140, 8);
    } else {
      g.rect(cx - 170, 188, 140, 16, 8);
      g.rect(cx + 30, 188, 140, 16, 8);
    }
  } else if (p.equals("웅크리기")) {
    g.ellipse(cx, 388, 140, 100);
    g.ellipse(cx, 322, 54, 58);
  }
  g.endDraw();
  g.loadPixels();

  personCount = 0;
  boxLeft = 640;
  boxRight = 0;
  boxTop = 480;
  boxBottom = 0;
  float sumX = 0, sumY = 0;
  silhouette.loadPixels();
  for (int y = 0; y < 480; y++) {
    for (int x = 0; x < 640; x++) {
      int i = x + y * 640;
      isPerson[i] = (g.pixels[i] & 0xFF) > 128;
      if (isPerson[i]) {
        personCount++;
        boxLeft = min(boxLeft, x);
        boxRight = max(boxRight, x);
        boxTop = min(boxTop, y);
        boxBottom = max(boxBottom, y);
        sumX += x;
        sumY += y;
        int gr = int(120 + 30 * sin(y * 0.02));   // 밋밋하지 않게 위아래로 살짝 명암
        silhouette.pixels[i] = 0xFF000000 | (gr << 16) | (gr << 8) | gr;
      } else {
        silhouette.pixels[i] = 0;
      }
    }
  }
  silhouette.updatePixels();
  if (personCount > 0) {
    centerX = sumX / personCount;
    centerY = sumY / personCount;
  } else {
    centerX = 320;
    centerY = 240;
    boxLeft = boxRight = boxTop = boxBottom = 0;
  }
  edgePoints.clear();
  for (int y = 4; y < 480 - 4; y += 4) {
    for (int x = 4; x < 640 - 4; x += 4) {
      int i = x + y * 640;
      if (isPerson[i] && (!isPerson[i - 4] || !isPerson[i + 4] || !isPerson[i - 4 * 640] || !isPerson[i + 4 * 640])) {
        edgePoints.add(new PVector(x, y));
      }
    }
  }
  builtPose = p;
}

// ================= 그리기 =================
// 회색 인간은 평원 한가운데(z = 0 근처)에 세운 판이다. 판을 세 겹(뒤로 갈수록 어둡게) 겹쳐
// 두께를 준다 → 시점이 옆으로 움직이면 옆면이 보여 입체감이 난다.
// 깊이 기록을 끄고 정원 다음에 그리면: 몸 앞의 꽃·풀은 몸을 가리고, 몸 뒤의 평원은 몸에 가려진다.
void drawSilhouette() {
  // 조절판 showCamera: 웹캠이면 실루엣 대신 카메라 화면 그대로 (몸 판 자리 z = 0) — 맞춰 볼 때 쓴다
  if (showCamera && useCamera) {
    hint(DISABLE_DEPTH_MASK);
    image(frame, 0, 0);
    hint(ENABLE_DEPTH_MASK);
    return;
  }
  if (personCount == 0) return;
  hint(DISABLE_DEPTH_MASK);
  float[] zs = { -10, -6, -2 };
  float[] shade = { 110, 175, 255 };
  for (int k = 0; k < 3; k++) {
    pushMatrix();
    translate(0, 0, zs[k]);
    tint(shade[k]);
    image(silhouette, 0, 0);
    popMatrix();
  }
  noTint();
  hint(ENABLE_DEPTH_MASK);
}

// 점검 화면: 몸이 서 있는 판(z = 0) 위에 상자 · 중심 · 가장자리 점을 그린다
void drawBodyDebug() {
  if (personCount > 0) {
    hint(DISABLE_DEPTH_TEST);
    noFill();
    stroke(255, 80, 80);
    strokeWeight(1);
    rect(boxLeft, boxTop, boxRight - boxLeft, boxBottom - boxTop);
    fill(255, 80, 80);
    noStroke();
    ellipse(centerX, centerY, 8, 8);
    stroke(255, 255, 255, 110);       // 점 수백 개는 POINTS 한 번으로 (빠르다)
    strokeWeight(2);
    beginShape(POINTS);
    for (PVector e : edgePoints) {
      vertex(e.x, e.y);
    }
    endShape();
    noStroke();
    hint(ENABLE_DEPTH_TEST);
  }
}
