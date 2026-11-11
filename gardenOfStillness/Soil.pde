// =====================================================
// Soil.pde — 거름 (담당 B, B4-1)
// 바닥에 닿은 꽃잎이 그 칸의 거름(soil)을 올리고, 시간이 지나면 조금씩 줄어든다.
// 거름이 많은 칸의 씨앗은 빨리 싹튼다 (Seed.readyToSprout). 바닥에 옅은 갈색 얼룩으로 그린다.
//
// 땅은 3D 평면이라 칸을 "땅 위 x·z"로 나눈다 (웹캠 칸 motion과는 다른 격자다).
// =====================================================

final float SOIL_CELL = 40;        // 거름 칸 한 변 (세계 좌표)
final float SOIL_X0 = -1400;       // 격자가 시작하는 x
final float SOIL_Z0 = -1000;       // 격자가 시작하는 z (멀리)
final int SOIL_COLS = 86;          // x 방향 칸 수 → -1400 ~ 2040
final int SOIL_ROWS = 31;          // z 방향 칸 수 → -1000 ~ 240
final float SOIL_PER_PETAL = 0.08; // 꽃잎 한 장이 올리는 거름 (꽃 한 송이 ≈ 0.4~0.6)
final float SOIL_DECAY = 0.9997;   // 매 프레임 곱한다 → 약 1분이면 반으로 준다 (60fps)

float[][] soil = new float[SOIL_COLS][SOIL_ROWS];

int soilCol(float x) {
  return int((x - SOIL_X0) / SOIL_CELL);
}

int soilRow(float z) {
  return int((z - SOIL_Z0) / SOIL_CELL);
}

boolean inSoil(int c, int r) {
  return c >= 0 && c < SOIL_COLS && r >= 0 && r < SOIL_ROWS;
}

// 그 자리 거름 양 (격자 밖이면 0)
float soilAt(float x, float z) {
  int c = soilCol(x);
  int r = soilRow(z);
  if (!inSoil(c, r)) return 0;
  return soil[c][r];
}

// 꽃잎이 땅에 닿았을 때 (Petal.update)
void addSoil(float x, float z, float amount) {
  int c = soilCol(x);
  int r = soilRow(z);
  if (inSoil(c, r)) soil[c][r] = min(1, soil[c][r] + amount);
}

void updateSoil() {
  for (int c = 0; c < SOIL_COLS; c++) {
    for (int r = 0; r < SOIL_ROWS; r++) {
      if (soil[c][r] > 0) {
        soil[c][r] *= SOIL_DECAY;
        if (soil[c][r] < 0.005) soil[c][r] = 0;
      }
    }
  }
}

void clearSoil() {
  for (int c = 0; c < SOIL_COLS; c++) {
    for (int r = 0; r < SOIL_ROWS; r++) {
      soil[c][r] = 0;
    }
  }
}

float totalSoil() {
  float sum = 0;
  for (int c = 0; c < SOIL_COLS; c++) {
    for (int r = 0; r < SOIL_ROWS; r++) {
      sum += soil[c][r];
    }
  }
  return sum;
}

// 땅 위에 거름 얼룩 — 땅 평면 바로 위, 잔디 아래에 그린다 (Meadow.drawMeadow에서 부른다)
// 칸 가장자리는 투명하게 → 네모가 아니라 번진 얼룩처럼 보인다
void drawSoil() {
  hint(DISABLE_DEPTH_MASK);   // 얇은 판끼리 깜빡이지 않게
  noStroke();
  float y = GROUND_Y - 0.5;
  for (int c = 0; c < SOIL_COLS; c++) {
    for (int r = 0; r < SOIL_ROWS; r++) {
      float s = soil[c][r];
      if (s <= 0.01) continue;
      float x = SOIL_X0 + c * SOIL_CELL + SOIL_CELL / 2;
      float z = SOIL_Z0 + r * SOIL_CELL + SOIL_CELL / 2;
      float h = SOIL_CELL * 0.75;   // 얼룩 반지름 — 이웃 칸과 조금 겹친다
      float a = min(1, s) * 170;
      // 가운데 진하고 가장자리 투명한 마름모 4장 = 부드러운 얼룩
      beginShape(TRIANGLE_FAN);
      fill(95, 65, 35, a);
      vertex(x, y, z);
      fill(95, 65, 35, 0);
      vertex(x - h, y, z);
      vertex(x, y, z - h);
      vertex(x + h, y, z);
      vertex(x, y, z + h);
      vertex(x - h, y, z);
      endShape();
    }
  }
  hint(ENABLE_DEPTH_MASK);
}
