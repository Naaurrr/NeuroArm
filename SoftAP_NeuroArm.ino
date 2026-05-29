#include <WiFi.h>
#include <WiFiUdp.h>
#include <ESP32Servo.h>

const char*    apSSID    = "NeuroArmAP_Test";
const uint16_t localPort = 4210;

const int      servoPins[3]  = {18, 19, 21};  
Servo          servos[3];
int            currentAngle[3] = {0, 0, 0};

WiFiUDP        Udp;

void setup() {
  Serial.begin(115200);
  delay(500);

  // Starts SoftAP
  WiFi.mode(WIFI_AP);
  WiFi.softAP(apSSID);
  Serial.printf("SoftAP \"%s\" up, IP = %s\n",
   apSSID, WiFi.softAPIP().toString().c_str());

  // UDP listens
  Udp.begin(localPort);
  Serial.printf("UDP listening on port %d\n", localPort);

  
  for (int i = 0; i < 3; i++) {
    servos[i].attach(servoPins[i]);
    servos[i].write(0);
    currentAngle[i] = 0;
  }
  Serial.println("Servos are attached");
}

void loop() {
  int pkt = Udp.parsePacket();
  if (pkt <= 0) return;

// commands get read
  char buf[16];
  int len = Udp.read(buf, pkt);
  buf[len] = '\0';
  int cmd = String(buf).toInt();
  Serial.printf("CMD received: %d\n", cmd);

  
  switch (cmd) {
    case 2:  
      for (int i = 0; i < 2; i++) {
        servos[i].write(180);
        Serial.printf("Finger %d → 180°\n", i);
      }
      delay(2000);
      for (int i = 0; i < 2; i++) {
        servos[i].write(0);
        Serial.printf("Finger %d → 0°\n", i);
      }
      break;

    case 8:  
      {
        int orig = currentAngle[2];
        int target = orig + 100;
        servos[2].write(target);
        Serial.printf("Elbow → %d°\n", target);
        delay(2000);
        servos[2].write(orig);
        Serial.printf("Elbow → %d°\n", orig);
      }
      break;

    case 10:
      
      for (int i = 0; i < 2; i++) {
        servos[i].write(180);
        Serial.printf("Finger %d → 180°\n", i);
      }
      delay(10);
     
      {
        int orig = currentAngle[2];
        int target = orig;
        servos[2].write(target);
        Serial.printf("Elbow → %d°\n", target);
      }
      delay(2000);
      
      for (int i = 0; i < 2; i++) {
        servos[i].write(0);
        Serial.printf("Finger %d → 0°\n", i);
      }
      servos[2].write(currentAngle[2]);
      Serial.printf("Elbow → %d°\n", currentAngle[2]);
      break;

    default:
      Serial.println("Unknown cmd, ignored");
      break;
  }

  
  Udp.beginPacket(Udp.remoteIP(), Udp.remotePort());
  Udp.print("ACK\n");
  Udp.endPacket();
  Serial.println("→ ACK sent");
}
