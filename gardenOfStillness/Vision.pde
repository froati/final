// =====================================================
// Vision.pde — 입력 (담당 A)
// 2026-11-11부터: 배경 빼기 대신 "얼굴 찾기 + 움직임" (OpenCV for Processing)
//   웹캠 → (거울처럼 좌우 뒤집기) → 칸별 움직임(앞 프레임과의 차이)
//                                → 얼굴 찾기(OpenCV 얼굴 검출기) → 사람이 있는가 · 얼굴 위치·크기
//   자세·손 흔들기·기울기는 Pose.pde가 얼굴 둘레 영역을 보고 판정한다.
//   → 시작할 때 화면 밖으로 비킬 필요가 없다. 화면 앞에 앉기만 하면 된다.
// 웹캠이 없거나 M 키를 누르면 "마우스판 가짜 입력"으로 돈다.
// 06-2 §2 약속 값의 이름·뜻은 그대로다 (personCount만 "사람 픽셀 수" → "사람이 있으면 큰 수"로 바뀜).
// =====================================================

import processing.video.*;
import gab.opencv.*;
import java.awt.Rectangle;

final int CELL = 20;   // 칸 한 변 (픽셀)
final int COLS = 32;   // 640 / 20
final int ROWS = 24;   // 480 / 20
final float MOTION_NOISE = 4;   // 칸 움직임이 이보다 작으면 카메라 잡음으로 보고 전체 합에서 뺀다

// ---- 둘 사이 약속 값 (A가 채우고 B가 읽는다) — 이름·뜻을 바꾸려면 06-2 §2부터 고친다 ----
boolean[] isPerson = new boolean[640 * 480];          // 픽셀마다 사람인지 (마우스판 가짜 몸에서만 채운다)
int personCount = 0;                                  // 사람이 있으면 큰 수(웹캠: 얼굴이 보이면 10000), 없으면 0
float[][] motion = new float[COLS][ROWS];             // 칸마다 움직임 양
float totalMotion = 0;                                // 전체 움직임 합 (잡음 뺀 값)
ArrayList<PVector> edgePoints = new ArrayList<PVector>();  // 실루엣 가장자리 점 (마우스판 가짜 몸)
int boxLeft, boxRight, boxTop, boxBottom;             // 둘레 상자 (웹캠: 얼굴 상자)
float centerX, centerY;                               // 중심 (웹캠: 얼굴 가운데)
String pose = "없음";                                 // 지금 프레임의 자세 이름
boolean waving = false;                               // 손만 흔드는 중인지
float waveX, waveY;                                   // 흔드는 위치
float lean = 0;                                       // 몸 기울기 (왼쪽 -1 ~ 오른쪽 1)
// ※ 위 값들은 모두 "웹캠 화면 좌표"다. 정원(B)이 화면·세계 위치와 비교할 때는
//    Character.pde의 camToScreen·screenToCam으로 바꾼다 (웹캠 속 얼굴을 캐릭터 머리에 겹친다)

// ---- 웹캠 ----
Capture cam;
boolean useCamera = false;     // true면 웹캠, false면 마우스판
PImage frame;                  // 거울처럼 뒤집은 이번 프레임 (640×480)
float[] prevBright = new float[640 * 480];   // 전 프레임 밝기 (움직임 계산용)
String builtPose = "";         // 마우스판: 가짜 몸을 마지막으로 만든 자세

// ---- 얼굴 찾기 (OpenCV) ----
OpenCV opencv;
PImage small;                  // 얼굴 찾기용 작은 화면 (320×240 — 작을수록 빠르다)
float faceX = 320, faceY = 200, faceW = 100;   // 얼굴 가운데·폭 (웹캠 좌표, 부드럽게 따라간다)
int faceSeenMs = -100000;      // 마지막으로 얼굴을 본 시각
boolean faceNow = false;       // 이번 검사에서 얼굴을 찾았는가
final int FACE_GRACE_MS = 2500;   // 얼굴이 잠깐 안 보여도(고개 숙임·돌림) 이 시간 동안은 "사람 있음"

void initInput() {
  frame = createImage(640, 480, RGB);
  small = createImage(320, 240, RGB);

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
      opencv = new OpenCV(this, 320, 240);
      opencv.loadCascade(OpenCV.CASCADE_FRONTALFACE);   // 정면 얼굴 검출기 (라이브러리에 들어 있다)
    } catch (Exception e) {
      println("웹캠을 열 수 없어 마우스판으로 돈다: " + e);
      useCamera = false;
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
    threshold = 50;          // 기준 화면과 이만큼 색이 다르면 "달라졌다" (Pose.pde 영역 판정)
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

// 매 프레임
// 웹캠: 손 흔들기·기울기·자세는 Pose.pde가 자동으로 판정한다 (키 입력 없음)
// 마우스판(웹캠 없을 때 시험용): 키로 흉내 낸다 — W 손 흔들기 · ←→ 기울기 · 1~4 자세
void updateInput() {
  if (useCamera) {
    updateCameraInput();
    return;
  }
  updateMouseInput();

  waving = holdW;
  waveX = mx();
  waveY = my();
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
  findFace();
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

// ② 얼굴 찾기: 2프레임에 한 번, 작은 화면에서 가장 큰 얼굴 하나
void findFace() {
  if (frameCount % 2 == 0) {
    small.copy(frame, 0, 0, 640, 480, 0, 0, 320, 240);
    opencv.loadImage(small);
    Rectangle[] faces = opencv.detect();
    Rectangle best = null;
    for (Rectangle r : faces) {
      if (best == null || r.width > best.width) best = r;
    }
    faceNow = best != null;
    if (faceNow) {
      float nx = (best.x + best.width / 2.0) * 2;   // 작은 화면 → 640×480 좌표
      float ny = (best.y + best.height / 2.0) * 2;
      float nw = best.width * 2;
      boolean jump = millis() - faceSeenMs > FACE_GRACE_MS || dist(nx, ny, faceX, faceY) > faceW * 2;
      float k = jump ? 1 : 0.4;   // 처음 찾았거나 크게 뛰면 바로, 아니면 부드럽게
      faceX += (nx - faceX) * k;
      faceY += (ny - faceY) * k;
      faceW += (nw - faceW) * k;
      faceSeenMs = millis();
    }
  }

  // 사람이 있는가: 얼굴을 최근 FACE_GRACE_MS 안에 봤으면 있음
  boolean present = millis() - faceSeenMs < FACE_GRACE_MS;
  personCount = present ? 10000 : 0;
  centerX = faceX;
  centerY = faceY;
  boxLeft = int(faceX - faceW / 2);
  boxRight = int(faceX + faceW / 2);
  boxTop = int(faceY - faceW / 2);
  boxBottom = int(faceY + faceW / 2);
}

// ================= 마우스판 (웹캠 없을 때 · 시험용) =================
void updateMouseInput() {
  for (int cx = 0; cx < COLS; cx++) {
    for (int cy = 0; cy < ROWS; cy++) {
      motion[cx][cy] = 0;
    }
  }
  // 이번 프레임에 마우스가 지나간 칸들에 마우스 속도를 넣는다
  float speed = dist(mx(), my(), pmx(), pmy());
  if (speed > 0) {
    int steps = int(speed / (CELL / 2)) + 1;
    for (int s = 0; s <= steps; s++) {
      float x = lerp(pmx(), mx(), s / float(steps));
      float y = lerp(pmy(), my(), s / float(steps));
      int cx = constrain(int(x / CELL), 0, COLS - 1);
      int cy = constrain(int(y / CELL), 0, ROWS - 1);
      motion[cx][cy] = speed;
    }
  }
  totalMotion = speed;
}

// 가짜 몸: 자세에 맞는 사람 모양을 그려서 isPerson · 상자 · 가장자리 점을 구한다 (마우스판 시험용)
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
      }
    }
  }
  // 사람이 없을 때 0으로 나누지 않게 (06-2 0-2의 5번)
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
// 화면에는 웹캠 속 사람을 그리지 않는다 — 캐릭터(Character.pde)가 동작을 따라 한다 (2026-11-11).
// 웹캠 화면 점검은 조절판 showCamera → Character.pde의 drawCameraPreview()
