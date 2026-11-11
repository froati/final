// =====================================================
// Gui.pde — 조절판 (담당 B, B2-1) — ControlP5 (CH16)
// 슬라이더 이름 = 변수 이름 (06-1 §4-8). ControlP5는 이름이 같은 변수에 값을 바로 넣어 준다.
// 버튼 이름 = 함수 이름: "resetGarden" 버튼을 누르면 resetGarden()이 불린다.
// H 키로 숨기기·보이기.
// =====================================================

import controlP5.*;

ControlP5 cp5;
boolean guiVisible = true;

float threshold = 60;      // 배경과 얼마나 달라야 사람으로 볼지 (A가 읽는다) — [ ] 키
float sensitivity = 15;    // 칸 하나가 "움직였다"(흩날림)의 기준 — 입력 방식마다 Vision.applyModeDefaults()가 정한다
float calmSensitivity = 150; // 전체 움직임이 이만큼이면 고요함 0 — 웹캠은 칸 768개의 합이라 칸 기준과 크기가 다르다. - = 키
float growSpeed = 0.05;    // 꽃이 자라는 속도 (× calm × light) — 싹→꽃: 가만히 약 10초 · 두 손 약 5초 (60fps 기준)
float lifespanSec = 40;    // 꽃의 평균 수명(초) — 보통 햇빛 기준. 두 손 들기면 짧아진다
float poseHold = 2.0;      // 자세를 몇 초 유지해야 햇빛 목표가 바뀔지
boolean showCamera = false; // 회색 실루엣 대신 카메라 화면 그대로 (웹캠일 때만)
boolean showDebug = true;   // 점검 정보 보기 (D 키로도)

// 조절판에 올릴 슬라이더 — {변수 이름, 최솟값, 최댓값}
String[] sliderNames = { "threshold", "sensitivity", "calmSensitivity", "growSpeed", "lifespanSec", "poseHold" };
float[][] sliderRanges = { {5, 150}, {2, 60}, {5, 400}, {0.01, 0.2}, {10, 120}, {0.5, 5} };

final int GUI_X = 12;
final int GUI_Y = 182;     // 점검 정보 아래

void initGui() {
  cp5 = new ControlP5(this);
  cp5.setAutoDraw(false);   // ※ P3D에서는 3D 시점에 같이 그려지지 않게, drawGui()에서 2D로 직접 그린다

  // 반투명 바탕을 보이게 글자색을 밝게
  for (int k = 0; k < sliderNames.length; k++) {
    cp5.addSlider(sliderNames[k])
       .setPosition(GUI_X, GUI_Y + k * 16)
       .setSize(130, 12)
       .setRange(sliderRanges[k][0], sliderRanges[k][1])
       .setValue(sliderValue(sliderNames[k]))
       .setDecimalPrecision(sliderNames[k].equals("growSpeed") ? 3 : 2);   // 0.05가 0.04로 잘려 보이지 않게
  }
  int y = GUI_Y + sliderNames.length * 16 + 6;
  cp5.addToggle("showCamera").setPosition(GUI_X, y).setSize(24, 12);
  cp5.addToggle("showDebug").setPosition(GUI_X + 80, y).setSize(24, 12).setValue(showDebug);
  cp5.addButton("resetGarden").setPosition(GUI_X + 160, y).setSize(70, 14);
}

// 지금 변수 값 (키로 바꾼 값이나 입력 방식이 바꾼 값을 슬라이더에 다시 보여 줄 때)
float sliderValue(String name) {
  if (name.equals("threshold")) return threshold;
  if (name.equals("sensitivity")) return sensitivity;
  if (name.equals("calmSensitivity")) return calmSensitivity;
  if (name.equals("growSpeed")) return growSpeed;
  if (name.equals("lifespanSec")) return lifespanSec;
  return poseHold;
}

void drawGui() {
  if (!guiVisible) return;

  // [ ] - = 키, 웹캠↔마우스 전환으로 바뀐 값을 슬라이더 눈금에도 맞춘다
  // ※ Minim에도 Controller라는 이름이 있어서 controlP5.Controller라고 풀네임으로 쓴다
  for (String name : sliderNames) {
    controlP5.Controller c = cp5.getController(name);
    float v = sliderValue(name);
    if (abs(c.getValue() - v) > 0.0001) c.setValue(v);
  }
  controlP5.Controller t = cp5.getController("showDebug");
  if ((t.getValue() > 0.5) != showDebug) t.setValue(showDebug ? 1 : 0);

  // 바탕 판
  noStroke();
  fill(0, 120);
  rect(GUI_X - 6, GUI_Y - 6, 250, sliderNames.length * 16 + 46, 4);
  cp5.draw();
}

void toggleGui() {
  guiVisible = !guiVisible;
  if (guiVisible) cp5.show();
  else cp5.hide();   // 숨기면 마우스로도 안 눌린다
}

// 조절판 위를 누를 때는 정원에 싹을 심지 않는다
boolean mouseOverGui() {
  return guiVisible && cp5.isMouseOver();
}
