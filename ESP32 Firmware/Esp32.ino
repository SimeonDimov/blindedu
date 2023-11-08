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
  commandCharacteristic.writeValue("LED OFF"); // Set initial value for the characteristic

  BLE.advertise(); // Start advertising
  Serial.println("BLE LED Control service advertised, ready to connect...");
}

void loop() {
  BLEDevice central = BLE.central(); // Wait for a BLE central to connect

  // If a central is connected to the peripheral:
  if (central) {
    Serial.print("Connected to central: ");
    Serial.println(central.address());

    while (central.connected()) { // While the central is still connected
      if (commandCharacteristic.written()) { // If the characteristic was written to by central
        String command = commandCharacteristic.value(); // Read the command

       if (command == "on") {
  digitalWrite(LED_BUILTIN, HIGH); // Turn on the built-in LED
  commandCharacteristic.writeValue("LED ON"); // Notify the central device
} else if (command == "off") {
  digitalWrite(LED_BUILTIN, LOW); // Turn off the built-in LED
  commandCharacteristic.writeValue("LED OFF"); // Notify the central device
}

      }
    }

    // When central disconnects
    Serial.print("Disconnected from central: ");
    Serial.println(central.address());
  }
}
