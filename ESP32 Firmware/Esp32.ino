#include <ArduinoBLE.h>

BLEService myService("12345678-1234-5678-1234-56789abcdef0"); // BLE LED Service
// Change BLEWrite to BLEWrite | BLERead | BLENotify
BLEStringCharacteristic commandCharacteristic("87654321-4321-6789-4321-6789abcdef01", BLEWrite | BLERead | BLENotify, 20);

void setup() {
  pinMode(LED_BUILTIN, OUTPUT); // Use built-in LED for demonstration
  Serial.begin(115200);

  // begin initialization of BLE
  if (!BLE.begin()) {
    Serial.println("starting BLE failed!");
    while (1);
  }

  BLE.setLocalName("ESP32 LED Control"); // Set the name visible to remote BLE central devices
  BLE.setAdvertisedService(myService); // Set the advertised service
  myService.addCharacteristic(commandCharacteristic); // Add characteristics to the service
  BLE.addService(myService); // Add the service
  commandCharacteristic.writeValue("LED OFF");

  BLE.advertise(); // Start advertising
  Serial.println("BLE LED Control service advertised, ready to connect...");
}

void loop() {
  BLEDevice central = BLE.central(); 


  if (central) {
    Serial.print("Connected to central: ");
    Serial.println(central.address());

    while (central.connected()) { 
      if (commandCharacteristic.written()) { 
        String command = commandCharacteristic.value(); // Read the command

       if (command == "on") {
  digitalWrite(LED_BUILTIN, HIGH); 
  commandCharacteristic.writeValue("LED ON"); 
} else if (command == "off") {
  digitalWrite(LED_BUILTIN, LOW); // 
  commandCharacteristic.writeValue("LED OFF"); 
}

      }
    }

    // When central disconnects
    Serial.print("Disconnected from central: ");
    Serial.println(central.address());
  }
}
