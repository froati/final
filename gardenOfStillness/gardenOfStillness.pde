// =====================================================
// 멈춤의 정원 (Garden of Stillness) — 초안 (2026-11-10)
// 뼈대: 관객의 행동이 규칙에 따라 움직이는 정원을 바꾸고, 그 변화를 보여 준다.
//
// 3D 잔디 평원에서 시작한다. 관객이 가만히 있으면 시간이 지나며 꽃이 피고(×1),
// 두 손 들고 멈추면 햇빛이 강해져 ×2로 빨라진다. 움직이거나 웅크리거나 아무도 없으면 ×0
// (06-1 §4-4 규칙 그대로 · 오른쪽 아래 "성장 ×N" 표시 · 자라는 꽃의 반짝이).
//
// 웹캠에 비친 관객이 "회색 인간"이 되어 평원 한가운데 선다. 보는 시점은 천천히 옆으로 오가며 원근을 보여 준다.
//   시작: 카메라 밖으로 나간다 → B 키(빈 배경 찍기) → 화면 앞에 선다
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

void setup() {
  size(640, 480, P3D);                     // 3D 모드. 웹캠 화면과 같은 크기 — z = 0 평면이 화면 좌표와 같다
  font = createFont("Malgun Gothic", 13);  // ※ 기본 글꼴은 한글이 깨져서 맑은 고딕을 쓴다
  textFont(font);
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
  updateLog();

  // ② 정원 (B) — 입력은 환경 값의 목표만 옮기고, 정원은 규칙대로 바뀐다
  updateEnvironment();
  updateGarden();
  updateSound();

  // ③ 그리기
  //   camera()            = 기본 카메라 → 화면에 붙는 2D (하늘 · 어둠 막 · 글자)
  //   setWorldCamera()    = 천천히 움직이는 시점 → 3D 세계
  updateWorldCamera();  // 이번 프레임 시점 정하기 (지평선 높이도 계산)
  camera();
  drawSky();            // 2D 배경: 하늘 · 해 · 먼 언덕 (light로 계산)
  setWorldCamera();
  drawMeadow();         // 3D: 땅 · 잔디 (바람에 눕는다)
  drawGarden();         // 3D: 씨앗 · 꽃 · 꽃잎
  drawSilhouette();     // 3D: 회색 인간 (두께 있는 판)
  if (showDebug) drawBodyDebug();   // 3D: 몸 판 위의 상자 · 중심 · 가장자리 점
  camera();
  drawNightShade();     // 2D: 어두워지면 전체를 덮는 막
  setWorldCamera();
  drawSparkles();       // 3D: 자라는 꽃의 반짝이
  drawFireflies();      // 3D: 반딧불이 (어두울수록 많다)

  // ④ 화면에 붙는 2D 표시 — 깊이 검사를 꺼서 3D 물체에 가려지지 않게
  camera();
  hint(DISABLE_DEPTH_TEST);
  drawCameraHint();   // 웹캠인데 배경을 아직 안 찍었으면 안내
  drawCalmGauge();    // 고요함 게이지
  drawGrowthStatus(); // 성장 속도 ×N 과 그 이유
  drawStillHint();    // "잠시 멈춰 보세요" (고요함이 10초 넘게 0일 때)
  drawBloomBanner();  // "만개" (핀 꽃이 기준을 넘은 순간)
  if (showDebug) drawDebug();
  drawGui();
  hint(ENABLE_DEPTH_TEST);
}

void keyPressed() {
  inputKeyPressed();                                   // A: 입력 키 (0~4, W, B, M, [ ], - =)
  if (key == 's' || key == 'S') saveFrame("photos/garden-####.png");  // 기념사진 (CH17)
  if (key == 'l' || key == 'L') toggleLog();           // 기록 장치 (A1-4)
  if (key == 'd' || key == 'D') showDebug = !showDebug;
  if (key == 'r' || key == 'R') resetGarden();
  if (key == 'h' || key == 'H') toggleGui();          // 조절판 숨기기·보이기 (B2-1)
}

void keyReleased() {
  inputKeyReleased();
}

// 웹캠 모드에서 배경을 아직 안 찍었으면 화면 가운데에 안내
void drawCameraHint() {
  if (useCamera && bgPixels == null) {
    String msg = "카메라 밖으로 잠시 나간 뒤  B  키를 눌러 빈 배경을 찍어 주세요";
    textAlign(CENTER, CENTER);
    noStroke();
    fill(0, 170);
    rect(width / 2 - textWidth(msg) / 2 - 14, height / 2 - 18, textWidth(msg) + 28, 36, 18);
    fill(255);
    text(msg, width / 2, height / 2);
    textAlign(LEFT, BASELINE);
  }
}

void mousePressed() {
  if (mouseOverGui()) return;   // 조절판을 만지는 중이면 싹을 심지 않는다
  plantAt(mouseX, mouseY);      // 시험용: 클릭한 자리에 싹 (B1-4)
}

// 창을 닫을 때 기록 파일이 열려 있으면 닫아 준다 (안 그러면 마지막 줄이 사라질 수 있다)
void exit() {
  if (logging) toggleLog();
  stopSound();
  super.exit();
}
