// ESP32_soliton_lock_spp.ino
#include "BluetoothSerial.h"

BluetoothSerial SerialBT;

const int SOLENOID_PIN = 23;   // change to the GPIO you use
const unsigned long UNLOCK_DURATION_MS = 3000; // how long to energize solenoid to unlock

void setup() {
  pinMode(SOLENOID_PIN, OUTPUT);
  digitalWrite(SOLENOID_PIN, LOW); // default locked (no power)
  Serial.begin(115200);

  // Optional: set simple PIN for pairing (if you want)
  // SerialBT.setPin("1234");

  bool ok = SerialBT.begin("ESP32_LOCK"); // Bluetooth device name
  if (ok) {
    Serial.println("Bluetooth started as ESP32_LOCK");
  } else {
    Serial.println("Failed to start Bluetooth!");
  }
}

void loop() {
  if (SerialBT.available()) {
    String incoming = SerialBT.readStringUntil('\n');
    incoming.trim(); // remove whitespace
    Serial.print("Received: ");
    Serial.println(incoming);

    // Accept a single character '1' to unlock, or string "OPEN"
    if (incoming == "1" || incoming.equalsIgnoreCase("OPEN")) {
      Serial.println("Unlock command received");
      unlockFor(UNLOCK_DURATION_MS);
      SerialBT.println("OK"); // optional ack
    } else {
      Serial.println("Unknown command");
      SerialBT.println("ERR");
    }
  }
}

// Simple blocking unlock for demonstration. You can replace with non-blocking if you need.
void unlockFor(unsigned long durationMs) {
  digitalWrite(SOLENOID_PIN, HIGH); // power solenoid (or activate your driver)
  delay(durationMs);
  digitalWrite(SOLENOID_PIN, LOW); // de-power
}
