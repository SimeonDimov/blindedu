# ESP32 BLE LED Control

This repository contains a Flutter application that communicates with an ESP32 module over BLE to control an onboard LED. The application scans for BLE devices, connects to the ESP32, and sends commands to toggle the LED state.

## Flutter App Setup

### Dependencies

- `flutter_reactive_ble`: Handles BLE operations
- `permission_handler`: Manages permission requests

### Running the App

1. Clone the repository.
2. Navigate to the project directory.
3. Run `flutter pub get` to install dependencies.
4. Connect a device or use an emulator.
5. Execute `flutter run` to start the app.

### Key Features

- Scans for devices advertising the specified BLE service.
- Connects to the ESP32 device and manages connection status.
- Sends commands to turn the LED on or off.
- Receives and displays feedback from the ESP32 regarding LED state.

## ESP32 Firmware Setup

### Key Components

- `BLEService`: BLE service with a unique UUID. (12345678-1234-5678-1234-56789abcdef0) Default setup, already preset in the code.
- `BLEStringCharacteristic`: Characteristic to receive commands. ("87654321-4321-6789-4321-6789abcdef01", BLEWrite | BLERead | BLENotify, 20) Default setup, already preset in the code.
- `LED_BUILTIN`: Built-in LED for feedback.

### Uploading the Firmware

1. Open Arduino IDE.
2. Install the `ArduinoBLE` library via the Library Manager.
3. Load the `esp32.ino` sketch file.
4. Configure the correct port and board settings for your ESP32 module.
5. Upload the sketch to the ESP32.

Upload your ESP32 code using the Arduino IDE, ensuring you've selected the correct board and port for your ESP32 module.

### Functionality

- Advertises a BLE service that the Flutter app can discover.
- Listens for incoming commands to control the LED state.
- Sends back the LED status as a BLE notification.

## iOS Specific Setup

- Install Xcode on your Mac.
- Configure an Apple Developer account for app signing.
- Set up the correct provisioning profiles and certificates.
- Update `Info.plist` with necessary permissions descriptions.

## Contributions

This project is open for contributions. Please follow the standard fork-and-pull-request workflow. Make sure your code adheres to the existing coding standards.
