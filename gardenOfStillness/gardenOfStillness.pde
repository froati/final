// =====================================================
// 멈춤의 정원 (Garden of Stillness) — 초안 (2026-11-10)
// 뼈대: 관객의 행동이 규칙에 따라 움직이는 정원을 바꾸고, 그 변화를 보여 준다.
//
// 3D 잔디 평원에서 시작한다. 관객이 가만히 있으면 시간이 지나며 꽃이 피고(×1),
// 두 손 들고 멈추면 햇빛이 강해져 ×2로 빨라진다. 움직이거나 웅크리거나 아무도 없으면 ×0
// (06-1 §4-4 규칙 그대로 · 오른쪽 아래 "성장 ×N" 표시 · 자라는 꽃의 반짝이).
//
// 웹캠에 비친 관객이 배경을 뺀 원래 모습(컬러) 그대로 3D 평원 한가운데 선다.
//   시작: 화면 앞에 앉아 카메라를 바라보고 2초 가만히 있는다 (얼굴을 찾아 기준을 자동 저장, 누를 키 없음)
//   가만히 있기 = 고요함↑ → 평원(땅)의 씨앗에서 싹이 튼다 (꽃은 땅에서만 자란다)
//   움직이기    = 고요함↓ · 바람 → 움직인 칸의 꽃이 흩날린다
//   숫자 키 1~4 = 지금 자세 알려 주기 (1 차렷 · 2 두손들기 · 3 웅크리기 · 4 팔벌리기)
//                 ※ 실루엣으로 자세를 알아보는 것은 A3-2에서 만든다. 그때까지 임시
//   [ ]  사람으로 볼 색 차이(threshold) · - =  고요함 기준(calmSensitivity)
//   M    웹캠 ↔ 마우스판 (마우스판: 마우스 움직임 = 관객 움직임, 0 누르는 동안 = 사람 없음)
//   W 손 흔들기(누르는 동안, 마우스 자리 = 손 자리 → 나비) · ←→ 몸 기울기(누르는 동안 → 산들바람)
//   ※ W·←→도 A4-2·A4-4(손 흔들기·기울기 판정) 전까지 임시
//   클릭 싹 · S 사진 · L 기록 · D 점검 정보 · H 조절판 · R 처음으로
//
// 정원 규칙 (B): 거름(Soil) · 나비와 꽃가루(Butterfly) · 덩굴(Vine, 팔벌리기 유지) · 소리(Sound, Minim)
//               · 조절판(Gui, ControlP5) · 만개 종소리 · "잠시 멈춰 보세요" 안내
// 키가 안 먹으면 한/영 키를 눌러 영문 입력으로 바꾼다.
// =====================================================

final float GROUND_Y = 440;   // 땅 높이 — 몸이 서 있는 자리(z = 0)에서 화면 y 440
PFont font;

// ---- 화면 크기 ----
// 모든 계산은 웹캠과 같은 640×480 좌표(W·H)로 하고, 그릴 때만 VIEW_SCALE배로 키운다.
// 창 크기를 바꾸려면 VIEW_SCALE만 바꾼다 (1 = 640×480, 1.5 = 960×720, 2 = 1280×960)
final int W = 640;
final int H = 480;
final float VIEW_SCALE = 2;

// ※ 창 크기에 변수를 쓰려면 size()를 setup()이 아니라 settings()에 둬야 한다
void settings() {
  size(round(W * VIEW_SCALE), round(H * VIEW_SCALE), P3D);   // 3D 모드
}

// 화면에 붙는 2D용 카메라: 기본 카메라 + 확대 → 640×480 좌표로 그리면 창 전체에 맞게 커진다
// (3D 세계도 같은 방법으로 키운다 — 세계와 카메라를 똑같이 키우면 보이는 모습은 같고 크기만 커진다)
void screenCamera() {
  camera();
  scale(VIEW_SCALE);
}

// 마우스 위치를 640×480 좌표로 (창이 커져도 계산은 그대로)
float mx() { return mouseX / VIEW_SCALE; }
float my() { return mouseY / VIEW_SCALE; }
float pmx() { return pmouseX / VIEW_SCALE; }
float pmy() { return pmouseY / VIEW_SCALE; }

void setup() {
  // ※ 기본 글꼴은 한글이 깨져서 맑은 고딕을 쓴다. 확대해도 흐리지 않게 배율만큼 큰 글꼴로 만들고 13 크기로 쓴다
  font = createFont("Malgun Gothic", 13 * VIEW_SCALE);
  textFont(font, 13);
  initInput();   // A: 입력 (웹캠, 없으면 마우스판)
  initMeadow();  // B: 3D 잔디 평원
  initScene();   // B: 환경 값 · 정원 (평원에 땅속 씨앗 뿌리기)
  initSound();   // B: 소리 (Minim)
  initGui();     // B: 조절판 (ControlP5)
}

void draw() {
  // ① 입력 (A) — 관객이 어디에, 얼마나 움직였고, 어떤 자세인가
  updateInput();
  updatePose();
  updateCharacter();    // 알아낸 동작을 캐릭터 동작 목표로
  updateLog();

  // ② 정원 (B) — 입력은 환경 값의 목표만 옮기고, 정원은 규칙대로 바뀐다
  updateEnvironment();
  updateGarden();
  updateSound();

  // ③ 그리기
  //   screenCamera()      = 기본 카메라 → 화면에 붙는 2D (하늘 · 어둠 막 · 글자)
  //   setWorldCamera()    = 3D 세계를 보는 시점
  updateWorldCamera();  // 이번 프레임 시점 정하기 (지평선 높이도 계산)
  screenCamera();
  drawSky();            // 2D 배경: 하늘 · 해 · 먼 언덕 (light로 계산)
  setWorldCamera();
  drawMeadow();         // 3D: 땅 · 잔디 (바람에 눕는다)
  drawGarden();         // 3D: 씨앗 · 꽃 · 꽃잎
  drawCharacter();      // 3D: 캐릭터 (웹캠으로 알아낸 동작을 따라 한다 — Character.pde)
  screenCamera();
  drawNightShade();     // 2D: 어두워지면 전체를 덮는 막
  setWorldCamera();
  drawSparkles();       // 3D: 자라는 꽃의 반짝이
  drawFireflies();      // 3D: 반딧불이 (어두울수록 많다)

  // ④ 화면에 붙는 2D 표시 — 깊이 검사를 꺼서 3D 물체에 가려지지 않게
  screenCamera();
  hint(DISABLE_DEPTH_TEST);
  drawCameraHint();   // 배경 자동 찍기 카운트다운
  drawPoseNotice();   // "기준 자세 저장" 알림
  drawCalmGauge();    // 고요함 게이지
  drawGrowthStatus(); // 성장 속도 ×N 과 그 이유
  drawStillHint();    // "잠시 멈춰 보세요" (고요함이 10초 넘게 0일 때)
  drawBloomBanner();  // "만개" (핀 꽃이 기준을 넘은 순간)
  if (showDebug) drawDebug();
  drawCameraPreview(); // 조절판 showCamera: 웹캠 화면 작게 (판정 점검용)
  drawGui();
  hint(ENABLE_DEPTH_TEST);
}

void keyPressed() {
  inputKeyPressed();                                   // A: 입력 키 (C 기준 다시 · M · [ ] - = · 마우스판 0~4 W ←→)
  if (key == 's' || key == 'S') saveFrame("photos/garden-####.png");  // 기념사진 (CH17)
  if (key == 'l' || key == 'L') toggleLog();           // 기록 장치 (A1-4)
  if (key == 'd' || key == 'D') showDebug = !showDebug;
  if (key == 'r' || key == 'R') resetGarden();
  if (key == 'h' || key == 'H') toggleGui();          // 조절판 숨기기·보이기 (B2-1)
}

void keyReleased() {
  inputKeyReleased();
}

// 웹캠 모드 안내: 얼굴이 안 보이면 / 기준을 잡는 중이면 (따로 누를 키는 없다)
void drawCameraHint() {
  if (!useCamera) return;
  String msg = null;
  if (personCount < 500 && millis() - faceSeenMs > 5000) msg = "화면 앞에서 카메라를 바라봐 주세요";
  else if (personCount >= 500 && !hasBase) msg = "잠시 가만히 있어 주세요";
  if (msg != null) {
    textAlign(CENTER, CENTER);
    noStroke();
    fill(0, 170);
    rect(W / 2 - textWidth(msg) / 2 - 14, H / 2 - 18, textWidth(msg) + 28, 36, 18);
    fill(255);
    text(msg, W / 2, H / 2);
    textAlign(LEFT, BASELINE);
  }
}

void mousePressed() {
  if (mouseOverGui()) return;   // 조절판을 만지는 중이면 싹을 심지 않는다
  plantAt(mx(), my());      // 시험용: 클릭한 자리에 싹 (B1-4)
}

// 창을 닫을 때 기록 파일이 열려 있으면 닫아 준다 (안 그러면 마지막 줄이 사라질 수 있다)
void exit() {
  if (logging) toggleLog();
  stopSound();
  super.exit();
}
