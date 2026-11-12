// =====================================================
// Meadow.pde — 3D 잔디 평원 (담당 B)
// 세계 좌표는 프로세싱 기본 카메라 기준이다: z = 0 평면이 웹캠 픽셀과 1:1로 겹치므로
// A가 넘기는 웹캠 좌표(edgePoints · motion 칸)를 그대로 쓸 수 있다.
// 그릴 때만 시점(updateWorldCamera)을 천천히 움직여 입체감을 낸다.
// 땅은 y = GROUND_Y 높이의 평면이고, z가 작을수록(음수) 멀리 있다.
// =====================================================

final int GRASS_CHUNKS = 6;      // 잔디를 깊이별로 6덩어리로 나눠 덩어리마다 다르게 흔든다
final int GRASS_BLADES = 16000;  // 풀잎 수
PShape[] grassChunks;
float EYE_Z;                     // 기본 카메라의 눈 위치 z
float HORIZON_Y;                 // 지평선 화면 높이 (= 눈높이)
color hazeColor;                 // 멀리 있는 것이 섞이는 안개 색

void initMeadow() {
  EYE_Z = (H / 2.0) / tan(PI / 6);   // 프로세싱 기본 카메라 공식
  HORIZON_Y = H / 2.0;
  hazeColor = color(185, 208, 195);

  // 풀잎을 미리 한 번만 만들어 PShape에 담아 둔다 (매 프레임 만들면 느리다)
  grassChunks = new PShape[GRASS_CHUNKS];
  int perChunk = GRASS_BLADES / GRASS_CHUNKS;
  for (int c = 0; c < GRASS_CHUNKS; c++) {
    PShape s = createShape();
    s.beginShape(TRIANGLES);
    s.noStroke();
    for (int i = 0; i < perChunk; i++) {
      // 화면 높이로 고르게 뽑은 뒤 그 높이에 맞는 z를 구한다 → 가까운 곳도 빽빽하게
      // H + 170: 움직이는 시점은 기본 카메라보다 발밑(z ≈ 200)까지 보이므로 그만큼 앞까지 심는다
      float syMin = map(c, 0, GRASS_CHUNKS, H + 170, HORIZON_Y + 25);
      float syMax = map(c + 1, 0, GRASS_CHUNKS, H + 170, HORIZON_Y + 25);
      float sy = random(syMax, syMin);
      float z = groundZForScreenY(sy);
      float x = W / 2.0 + random(-1.5, 1.5) * visibleHalfWidth(z);   // 시점이 옆으로 가도 빈 곳이 안 보이게 넓게

      float h = random(9, 20);        // 풀잎 키 — 땅 꽃(줄기 최대 약 60)보다 낮게
      float w = random(3, 6);         // 풀잎 너비
      float lean = random(-7, 7);     // 풀잎마다 조금씩 기울게
      float haze = constrain(map(z, -150, -2400, 0, 0.8), 0, 0.8);   // 멀수록 안개 색
      color baseC = lerpColor(color(38, 88, 34), hazeColor, haze);
      color tipC = lerpColor(color(random(105, 150), random(170, 210), random(60, 95)), hazeColor, haze);

      s.fill(baseC);
      s.vertex(x - w / 2, GROUND_Y, z);
      s.vertex(x + w / 2, GROUND_Y, z);
      s.fill(tipC);
      s.vertex(x + lean, GROUND_Y - h, z);
    }
    s.endShape();
    grassChunks[c] = s;
  }
}

// ---------- 보는 시점 (월드 카메라) ----------
// 웹캠 좌표와 맞추는 계산은 늘 "기본 카메라" 기준(webcamViewX·Y)으로 하고,
// 화면을 그릴 때만 시점을 천천히 옆·위아래로 움직여 원근(가까운 풀은 빨리, 먼 언덕은 느리게)이 보이게 한다.
float eyeX, eyeY, eyeZ;      // 이번 프레임의 눈 위치
float skyHorizon = 240;      // 이번 프레임에 지평선이 화면에서 보이는 높이 (하늘 그릴 때 쓴다)

// ※ 2026-11-11 시점 고정: 관객의 행동과 관계없이 화면이 흔들리면 "멈추면 정원이 바뀐다"가 흐려지고,
//    화면 속 몸이 실제 자리에서 비껴 보인다. 그래서 기본 카메라(= 웹캠 좌표와 1:1)에 고정한다.
//    예전처럼 천천히 움직이는 시점을 다시 보려면 true로 바꾼다.
final boolean CAMERA_SWAY = false;

void updateWorldCamera() {
  if (CAMERA_SWAY) {
    float t = millis() / 1000.0;
    eyeX = W / 2.0 + 160 * sin(t * 0.12);   // 약 50초에 한 번 좌우로 오간다
    eyeY = 200 + 30 * sin(t * 0.09);            // 눈높이도 살짝 오르내린다
    eyeZ = EYE_Z * 1.15;
  } else {
    eyeX = W / 2.0;                         // 기본 카메라 그대로
    eyeY = H / 2.0;
    eyeZ = EYE_Z;
  }
  setWorldCamera();
  // 아주 먼 땅 = 지평선. screenY는 실제 창 픽셀이라 배율로 나눠 640×480 좌표로 바꾼다
  skyHorizon = screenY(eyeX, GROUND_Y, eyeZ - 100000) / VIEW_SCALE;
}

// 창이 VIEW_SCALE배로 커져도 같은 모습이 보이게, 카메라 위치를 배율만큼 키우고 세계도 같은 배율로 키운다
void setWorldCamera() {
  float s = VIEW_SCALE;
  if (CAMERA_SWAY) {
    camera(eyeX * s, eyeY * s, eyeZ * s,          // 눈 위치
           W / 2.0 * s, 290 * s, -200 * s,        // 바라보는 곳: 사람 조금 뒤 평원
           0, 1, 0);                              // 위쪽 방향 (프로세싱은 y가 아래로 커진다)
    scale(s);
  } else {
    screenCamera();                       // 기본 카메라: z = 0 평면이 화면·웹캠 좌표와 정확히 겹친다
  }
}

// 3D 위치 → 웹캠 화면 좌표 (기본 카메라에서 보이는 자리). A의 motion 칸과 맞출 때 쓴다
float webcamViewX(float x, float z) {
  return W / 2.0 + (x - W / 2.0) * depthScale(z);
}

float webcamViewY(float y, float z) {
  return H / 2.0 + (y - H / 2.0) * depthScale(z);
}

// 땅 위 z에서 화면에 보이는 가로 반폭 (멀수록 넓게 보인다)
float visibleHalfWidth(float z) {
  return (W / 2.0) * (EYE_Z - z) / EYE_Z;
}

// 화면 높이 sy에 보이는 땅의 z (위 식을 거꾸로 푼 것)
float groundZForScreenY(float sy) {
  return EYE_Z - (GROUND_Y - HORIZON_Y) * EYE_Z / (sy - HORIZON_Y);
}

// 원근 배율: z = 0이면 1, 멀수록 작아진다
float depthScale(float z) {
  return EYE_Z / (EYE_Z - z);
}

// 땅 위 아무 곳 (화면에 보이는 범위 안)
PVector randomMeadowPoint(float zNear, float zFar) {
  float z = random(zFar, zNear);
  float x = W / 2.0 + random(-0.95, 0.95) * visibleHalfWidth(z);
  return new PVector(x, GROUND_Y, z);
}

void drawMeadow() {
  // 땅 평면: 가까운 곳은 진한 초록, 먼 곳은 안개 색 (꼭짓점마다 색을 주면 사이가 그러데이션된다)
  noStroke();
  beginShape(QUADS);
  fill(52, 92, 42);
  vertex(-2500, GROUND_Y, 450);
  vertex(W + 2500, GROUND_Y, 450);
  fill(hazeColor);
  vertex(W + 9000, GROUND_Y, -6000);
  vertex(-9000, GROUND_Y, -6000);
  endShape();

  drawSoil();   // 거름 얼룩 (Soil.pde) — 땅 위, 잔디 아래

  // 잔디: 덩어리마다 noise로 다르게, 바람만큼 더 눕는다 (밑동은 그대로, 끝만 움직이는 기울이기)
  for (int c = 0; c < GRASS_CHUNKS; c++) {
    float a = (noise(c * 0.7, frameCount * 0.008) - 0.5) * 0.35 + windX() * 0.6;   // 바람 방향으로 눕는다
    float t = tan(a);
    pushMatrix();
    translate(0, GROUND_Y, 0);
    applyMatrix(1, -t, 0, 0,    // x' = x - t*y  → 위로 갈수록(y가 음수) 옆으로 밀린다
                0, 1, 0, 0,
                0, 0, 1, 0,
                0, 0, 0, 1);
    translate(0, -GROUND_Y, 0);
    shape(grassChunks[c]);
    popMatrix();
  }
}
