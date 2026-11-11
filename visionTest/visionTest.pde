// =====================================================
// visionTest — 입력 시험 스케치 (담당 A, 06-2 A1-1 ~ A1-4) — 초안 (2026-11-10)
// 웹캠 → 배경 빼기 → 실루엣(isPerson · personCount) → 칸별 움직임(motion · totalMotion)
// 합치기 1에서 여기 계산을 gardenOfStillness의 Vision.pde로 옮긴다.
//
// ※ Video 라이브러리가 필요하다: Processing 메뉴 스케치 → 라이브러리 가져오기 → 라이브러리 추가
//    → "Video Library for Processing 4" 설치
//
// 키
//   B  빈 배경 찍기 (사람이 화면 밖에 있을 때)
//   V  카메라 화면 ↔ 흑백 실루엣 보기
//   [ ]  threshold 내리기/올리기 (배경과 얼마나 달라야 사람인지)
//   , .  sensitivity 내리기/올리기 (빨갛게 칠할 칸의 기준)
//   L  기록 켜기/끄기 (logs/ 폴더에 CSV)
//   P  흑백 실루엣 점검 화면만 PNG로 저장 (얼굴·방은 저장하지 않는다)
// =====================================================

import processing.video.*;

final int CELL = 20;
final int COLS = 32;   // 640 / 20
final int ROWS = 24;   // 480 / 20

Capture cam;
PImage frame;          // 이번 프레임 (640×480으로 맞춘 것)
PImage bg;             // B 키로 찍은 빈 배경
PImage sil;            // 흑백 실루엣 (사람 흰색 · 배경 검정)
float[] prevBright;    // 전 프레임의 픽셀 밝기 (움직임 계산용)

// ---- 06-2 §2 약속 값 (이름 그대로) ----
boolean[] isPerson = new boolean[640 * 480];
int personCount = 0;
float[][] motion = new float[COLS][ROWS];
float totalMotion = 0;

// ---- 조절 값 (나중에 조절판 슬라이더) ----
float threshold = 60;      // 색 차이가 이보다 크면 사람
float sensitivity = 15;    // 칸 움직임이 이보다 크면 "움직였다"
boolean showCamera = false;

// ---- 기록 장치 ----
PrintWriter logWriter;
boolean logging = false;

PFont font;

void setup() {
  size(640, 480);
  font = createFont("Malgun Gothic", 13);   // ※ 한글이 보이는 글꼴
  textFont(font);

  printArray(Capture.list());               // 연결된 카메라 이름 목록 (CH14) — 콘솔에서 확인
  cam = new Capture(this, 640, 480);        // 기본 카메라. 안 되면 new Capture(this, 640, 480, "카메라 이름")
  cam.start();

  frame = createImage(640, 480, RGB);
  sil = createImage(640, 480, RGB);
  prevBright = new float[640 * 480];
}

void draw() {
  if (cam.available()) {
    cam.read();
    if (cam.width > 0) {
      frame = cam.get();                                 // 카메라 화면 복사
      if (frame.width != 640 || frame.height != 480) {
        frame.resize(640, 480);                          // 카메라가 다른 크기를 주면 맞춘다
      }
      frame.loadPixels();
      findPerson();
      findMotion();
      if (logging) writeLog();
    }
  }

  // 보기
  if (showCamera) image(frame, 0, 0);
  else image(sil, 0, 0);
  drawMotionCells();
  drawInfo();
}

// ① 배경 빼기: 지금 픽셀과 배경 픽셀의 색 차이가 threshold보다 크면 사람 (06-1 §4-1)
void findPerson() {
  personCount = 0;
  sil.loadPixels();
  for (int i = 0; i < frame.pixels.length; i++) {
    if (bg == null) {
      isPerson[i] = false;                               // 배경을 아직 안 찍었으면 판단하지 않는다
    } else {
      color c = frame.pixels[i];
      color b = bg.pixels[i];
      float d = dist(red(c), green(c), blue(c), red(b), green(b), blue(b));
      isPerson[i] = d > threshold;
    }
    if (isPerson[i]) {
      personCount++;
      sil.pixels[i] = color(255);
    } else {
      sil.pixels[i] = color(0);
    }
  }
  sil.updatePixels();
}

// ② 칸별 움직임: 칸마다 전 프레임과의 밝기 차이 평균 (06-1 §4-2)
//    계산을 줄이려고 칸 안에서 2픽셀씩 건너뛴다 → 칸 하나에 100개 픽셀
void findMotion() {
  totalMotion = 0;
  for (int cx = 0; cx < COLS; cx++) {
    for (int cy = 0; cy < ROWS; cy++) {
      float diffSum = 0;
      for (int y = cy * CELL; y < cy * CELL + CELL; y += 2) {
        for (int x = cx * CELL; x < cx * CELL + CELL; x += 2) {
          int i = x + y * 640;
          diffSum += abs(brightness(frame.pixels[i]) - prevBright[i]);
        }
      }
      motion[cx][cy] = diffSum / 100;
      totalMotion += motion[cx][cy];
    }
  }
  // 이번 밝기를 저장해 두었다가 다음 프레임에 비교한다
  for (int i = 0; i < frame.pixels.length; i++) {
    prevBright[i] = brightness(frame.pixels[i]);
  }
}

void drawMotionCells() {
  noStroke();
  for (int cx = 0; cx < COLS; cx++) {
    for (int cy = 0; cy < ROWS; cy++) {
      if (motion[cx][cy] > sensitivity) {
        fill(255, 0, 0, 110);                            // 움직인 칸은 빨갛게
        rect(cx * CELL, cy * CELL, CELL, CELL);
      }
    }
  }
}

void drawInfo() {
  String[] lines = {
    "totalMotion  " + nf(totalMotion, 1, 1) + "   personCount  " + personCount,
    "threshold  " + nf(threshold, 1, 0) + "  ([ ])   sensitivity  " + nf(sensitivity, 1, 1) + "  (, .)",
    (bg == null ? "배경 없음 — 화면 밖으로 나가서 B" : "배경 있음") + (logging ? "   ● 기록 중" : ""),
    "B 배경 · V 카메라/실루엣 · L 기록 · P 점검 사진   fps " + nf(frameRate, 1, 0)
  };
  noStroke();
  fill(0, 150);
  rect(6, 6, 420, lines.length * 17 + 8, 4);
  fill(255);
  for (int k = 0; k < lines.length; k++) {
    text(lines[k], 12, 22 + k * 17);
  }
}

void keyPressed() {
  if (key == 'b' || key == 'B') {
    bg = frame.get();          // 지금 화면을 배경으로 저장
    bg.loadPixels();
    println("배경 저장");
  }
  if (key == 'v' || key == 'V') showCamera = !showCamera;
  if (key == '[') threshold = max(5, threshold - 5);
  if (key == ']') threshold += 5;
  if (key == ',') sensitivity = max(0.5, sensitivity - 0.5);
  if (key == '.') sensitivity += 0.5;
  if (key == 'l' || key == 'L') toggleLog();
  if (key == 'p' || key == 'P') {
    String name = "check/sil-" + nf(hour(), 2) + nf(minute(), 2) + nf(second(), 2) + ".png";
    sil.save(savePath(name));  // 흑백 실루엣만 저장 (savePath는 check/ 폴더가 없으면 만들어 준다)
    println("점검 화면 저장: " + name);
  }
}

// ---- 기록 장치 (A1-4) ----
void toggleLog() {
  if (!logging) {
    String name = "logs/vision-" + nf(month(), 2) + nf(day(), 2) + "-"
                + nf(hour(), 2) + nf(minute(), 2) + nf(second(), 2) + ".csv";
    logWriter = createWriter(name);
    logWriter.println("ms,totalMotion,personCount");
    logging = true;
    println("기록 시작: " + name);
  } else {
    logWriter.flush();
    logWriter.close();
    logging = false;
    println("기록 끝");
  }
}

void writeLog() {
  logWriter.println(millis() + "," + totalMotion + "," + personCount);
}

void exit() {
  if (logging) toggleLog();
  super.exit();
}
