#include <WiFi.h>
#include <WebServer.h>
#include <ESPmDNS.h>


const String ssid = "";
const String password = "";
const int controlPin = 5;
WebServer server(80);

// Helper Functions

void handleRoot() {
  server.send(200, "text/plain", "ESP32 Server is running!");
}

void handleControl() {
  Serial.println("Received /control request");

  if (server.hasArg("signal")) {
    String signalValue = server.arg("signal");
    Serial.print("Signal value: ");
    Serial.println(signalValue);
    
    if (signalValue == "1") {
      activatePin();
      server.send(200, "text/plain", "OK - Pin activated");
    } else {
      server.send(400, "text/plain", "Bad Request - Invalid signal value");
    }
  } else {
    server.send(400, "text/plain", "Bad Request - 'signal' argument missing or invalid");
  }
}

void activatePin() {
  Serial.println("Activating pin 5 for 3 seconds...");
  digitalWrite(controlPin, HIGH);
  delay(3000);
  digitalWrite(controlPin, LOW);
  Serial.println("Pin 5 is now LOW.");
}

void setup() {
  // Start serial communication for debugging
  Serial.begin(115200);
  pinMode(controlPin, OUTPUT);
  digitalWrite(controlPin, LOW);

  // Connect to Wi-Fi
  Serial.println();
  Serial.print("Connecting to ");
  Serial.println(ssid);

  WiFi.begin(ssid, password);

  int retries = 0;
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
    if (++retries > 20) {
      Serial.println("\nFailed to connect to WiFi. Please check credentials and restart.");
      while(1);
    }
  }

  Serial.println("");
  Serial.println("WiFi connected!");
  Serial.print("IP address: ");
  Serial.println(WiFi.localIP());

  // Initialize mDNS
  if (!MDNS.begin("esp32lock")) {
    Serial.println("Error setting up MDNS responder");
    while (1) {
      delay(1000);
    }
  }
  Serial.println("mDNS responder started");


  // Start the server
  server.on("/", HTTP_GET, handleRoot);
  server.on("/control", HTTP_POST, handleControl);

  server.begin();
  Serial.println("HTTP server started");
}

void loop() {
  server.handleClient();
}


