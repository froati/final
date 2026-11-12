// =====================================================
// Sound.pde — 소리 (담당 B) — Minim (CH15)
// B2-4: 배경 음악 loop(), calm이 클수록 크게
// B3-3: 새 싹이 틀 때 "똑"(너무 잦으면 확률로 줄인다) · 핀 꽃이 기준을 넘는 "만개" 때 종소리 한 번
// B4-4: 새소리는 light가 클수록, 풀벌레 소리는 light가 작을수록 크게
//
// data/ 안의 파일 5개 (지금은 사인파로 합성한 임시 음원 — 저작권 없음. 같은 이름으로 바꿔 넣으면 된다):
//   bgm.wav · sprout.wav · bell.wav · birds.wav · crickets.wav
// 파일이 없으면 그 소리만 조용히 빠지고 스케치는 그대로 돈다.
// =====================================================

import ddf.minim.*;

Minim minim;
AudioPlayer bgm, birds, crickets;   // 계속 도는 소리 (loop)
AudioSample sproutSnd, bellSnd;     // 짧게 터뜨리는 소리 (trigger — 겹쳐서 울릴 수 있다)

// 지금 소리 크기 (0~1) — 갑자기 바뀌지 않게 천천히 따라간다
float bgmVol = 0, birdsVol = 0, cricketsVol = 0;

// 싹 소리: 너무 잦으면 시끄러우니 간격·확률로 줄인다
int lastSproutMs = 0;
final int SPROUT_GAP_MS = 180;      // 최소 간격

// 만개: 핀 꽃이 BLOOM_ON 송이를 넘으면 종 한 번. BLOOM_OFF 아래로 내려가야 다시 울릴 수 있다
final int BLOOM_ON = 45;
final int BLOOM_OFF = 30;
boolean bloomRung = false;
int bloomShownMs = -100000;         // "만개" 글자를 띄운 시각
PFont bannerFont;                   // 큰 글씨용 (작은 글꼴을 키우면 흐려져서 따로 만든다)

void initSound() {
  minim = new Minim(this);
  bannerFont = createFont("Malgun Gothic", 28 * VIEW_SCALE);   // 확대해도 흐리지 않게 배율만큼 크게
  bgm = loadLoop("bgm.wav");
  birds = loadLoop("birds.wav");
  crickets = loadLoop("crickets.wav");
  sproutSnd = loadShort("sprout.wav");
  bellSnd = loadShort("bell.wav");
}

// 계속 도는 소리를 불러와 바로 반복 재생한다 (처음엔 소리 0)
AudioPlayer loadLoop(String name) {
  AudioPlayer p = minim.loadFile(name);
  if (p == null) {
    println("소리 파일 없음: data/" + name);
    return null;
  }
  setVolume(p, 0);
  p.loop();
  return p;
}

AudioSample loadShort(String name) {
  AudioSample s = minim.loadSample(name, 512);
  if (s == null) println("소리 파일 없음: data/" + name);
  return s;
}

void updateSound() {
  // 배경 음악: 고요할수록 크게 (조용히 깔려 있다가 멈추면 차오른다)
  bgmVol = ease(bgmVol, 0.25 + 0.75 * calm, 0.05);
  // 새소리: 햇빛이 0.4를 넘으면서 커진다 · 풀벌레: 햇빛이 0.5 아래로 내려가면서 커진다
  birdsVol = ease(birdsVol, constrain(map(light, 0.4, 1.0, 0, 1), 0, 1), 0.03);
  cricketsVol = ease(cricketsVol, constrain(map(light, 0.5, 0.05, 0, 1), 0, 1), 0.03);

  setVolume(bgm, bgmVol);
  setVolume(birds, birdsVol * 0.8);
  setVolume(crickets, cricketsVol * 0.6);

  // 만개 판정 — 핀 꽃(stage 2) 수
  int open = 0;
  for (Flower f : flowers) if (f.stage == 2) open++;
  if (!bloomRung && open >= BLOOM_ON) {
    bloomRung = true;
    bloomShownMs = millis();
    if (bellSnd != null) bellSnd.trigger();
  } else if (bloomRung && open < BLOOM_OFF) {
    bloomRung = false;
  }
}

// 새 싹이 틀 때 부른다 (Scene.addFlower)
void playSprout() {
  if (sproutSnd == null) return;
  if (millis() - lastSproutMs < SPROUT_GAP_MS) return;
  if (random(1) > 0.6) return;     // 열에 여섯 번만
  lastSproutMs = millis();
  sproutSnd.trigger();
}

// 0~1 크기 → 데시벨(dB). Minim의 setGain은 dB 단위다 (0 dB = 원래 크기, -80 dB = 거의 안 들림)
void setVolume(AudioPlayer p, float v) {
  if (p == null) return;
  float db = (v < 0.001) ? -80 : max(-80, 20 * log(v) / log(10));
  p.setGain(db);
}

float ease(float now, float target, float k) {
  return now + (target - now) * k;
}

// 만개 때 화면 가운데 위에 잠깐 "만개" 글자 (3초 동안 서서히 사라진다)
void drawBloomBanner() {
  float t = (millis() - bloomShownMs) / 3000.0;
  if (t < 0 || t > 1) return;
  float a = 255 * (1 - t);
  textAlign(CENTER, CENTER);
  textFont(bannerFont, 28);
  fill(255, 240, 200, a);
  text("만개", W / 2, 400 - t * 12);   // 아래 가운데에서 살짝 떠오르며 사라진다
  textFont(font, 13);
  textAlign(LEFT, BASELINE);
}

// 창을 닫을 때 소리 정리
void stopSound() {
  // 도는 소리를 먼저 닫고 Minim을 멈춘다 (순서가 바뀌면 "Stream closed" 오류가 찍힌다)
  if (bgm != null) bgm.close();
  if (birds != null) birds.close();
  if (crickets != null) crickets.close();
  if (sproutSnd != null) sproutSnd.close();
  if (bellSnd != null) bellSnd.close();
  if (minim != null) minim.stop();
}
