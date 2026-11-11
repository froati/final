// =====================================================
// Log.pde — 기록 장치 (담당 A, 06-2 A1-4)
// L 키로 켜고 끈다. 켜져 있는 동안 매 프레임 숫자를 CSV 한 줄씩 적는다.
// 파일은 스케치 폴더의 logs/ 안에 생긴다. 이 파일을 Claude에게 읽혀 평균·범위를 물어본다.
// =====================================================

PrintWriter logWriter;
boolean logging = false;

void toggleLog() {
  if (!logging) {
    String name = "logs/log-" + nf(month(), 2) + nf(day(), 2) + "-"
                + nf(hour(), 2) + nf(minute(), 2) + nf(second(), 2) + ".csv";
    logWriter = createWriter(name);
    logWriter.println("ms,totalMotion,personCount,pose,calm,light");   // 첫 줄 = 열 이름
    logging = true;
    println("기록 시작: " + name);
  } else {
    logWriter.flush();   // 남은 내용을 파일에 쓰고
    logWriter.close();   // 닫는다
    logging = false;
    println("기록 끝");
  }
}

void updateLog() {
  if (logging) {
    logWriter.println(millis() + "," + totalMotion + "," + personCount + ","
                    + pose + "," + calm + "," + light);
  }
}
