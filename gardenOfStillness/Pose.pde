// =====================================================
// Pose.pde — 자세 (담당 A)
// 실루엣 모양으로 자세를 알아보는 것은 2주차 A2-1~A2-3(실루엣 재기 · 기준 자세 C키),
// 3주차 A3-2(자세 판정)에서 만든다. 그때까지는 웹캠 모드에서도 숫자 키로 자세를 알려 준다.
// "2초 유지했는가"는 A가 아니라 B(Scene.pde)가 판단한다.
// =====================================================

boolean holdZero = false;   // 0 키를 누르고 있는가 (마우스판: 사람 없음)
boolean holdW = false;      // W 키를 누르고 있는가 (손 흔들기)
boolean holdLeft = false;   // ← 키 (몸 기울기, A4-4 전까지 임시)
boolean holdRight = false;  // → 키
String fakePose = "차렷";   // 숫자 키로 고른 자세

void updatePose() {
  if (useCamera) {
    // 웹캠: 사람이 화면에 있으면 숫자 키로 고른 자세 (임시 — A3-2에서 실루엣으로 판정)
    if (personCount < 500) pose = "없음";
    else pose = fakePose;
  } else {
    // 마우스판: 키로 고른 자세대로 가짜 몸을 만든다 (자세가 바뀔 때만)
    if (holdZero) pose = "없음";
    else pose = fakePose;
    if (!pose.equals(builtPose)) buildFakeBody(pose);
  }
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
  if (key == 'b' || key == 'B') captureBackground();   // 빈 배경 찍기 (카메라 밖으로 나가서)
  if (key == 'm' || key == 'M') toggleInputMode();     // 웹캠 ↔ 마우스판
  if (key == '[') threshold = max(5, threshold - 5);   // 사람으로 볼 색 차이 ↓ (몸이 잘 안 잡히면)
  if (key == ']') threshold += 5;                      // ↑ (배경까지 사람이 되면)
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
