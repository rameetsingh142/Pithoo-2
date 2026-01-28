#include "Wire.h"
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// IMU Definitions
#define IMU_REG_PWR_MGMT_1 0x6B
#define IMU_REG_ACCEL_XOUT_H 0x3B

// BLE UUIDs
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

// IMU Variables
float roll, pitch;
float gyroRoll, gyroPitch;
float complementaryRoll, complementaryPitch;
float alpha = 0.96;
unsigned long previousTime;
float dt = 0;
int16_t accelX, accelY, accelZ;
int16_t gyroX, gyroY, gyroZ;

// BLE Variables
BLEServer* pServer = NULL;
BLECharacteristic* pCharacteristic = NULL;
bool deviceConnected = false;
bool oldDeviceConnected = false;

// BLE Server Callbacks
class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
      Serial.println("Device connected");
    };

    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
      Serial.println("Device disconnected");
    }
};

void setup() {
  Serial.begin(115200);
  
  // Initialize I2C
  Wire.begin(4, 5);  // SDA=GPIO4, SCL=GPIO5 for ESP32-C3
  
  // Initialize IMU
  initializeIMU();
  previousTime = millis();
  
  // Initialize BLE
  Serial.println("Starting BLE...");
  BLEDevice::init("ESP32_IMU");
  
  // Create BLE Server
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());
  
  // Create BLE Service
  BLEService *pService = pServer->createService(SERVICE_UUID);
  
  // Create BLE Characteristic
  pCharacteristic = pService->createCharacteristic(
                      CHARACTERISTIC_UUID,
                      BLECharacteristic::PROPERTY_READ   |
                      BLECharacteristic::PROPERTY_WRITE  |
                      BLECharacteristic::PROPERTY_NOTIFY |
                      BLECharacteristic::PROPERTY_INDICATE
                    );
  
  // Add descriptor for notifications
  pCharacteristic->addDescriptor(new BLE2902());
  
  // Start the service
  pService->start();
  
  // Start advertising
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(false);
  pAdvertising->setMinPreferred(0x0);
  BLEDevice::startAdvertising();
  Serial.println("BLE device is now advertising...");
}

void initializeIMU() {
  Wire.beginTransmission(0x68);
  Wire.write(IMU_REG_PWR_MGMT_1);
  Wire.write(0x00);
  Wire.endTransmission();
  Serial.println("IMU initialized");
}

void readIMUData() {
  Wire.beginTransmission(0x68);
  Wire.write(IMU_REG_ACCEL_XOUT_H);
  Wire.endTransmission(false);
  Wire.requestFrom(0x68, 14);

  if (Wire.available() == 14) {
    accelX = Wire.read() << 8 | Wire.read();
    accelY = Wire.read() << 8 | Wire.read();
    accelZ = Wire.read() << 8 | Wire.read();
    Wire.read(); Wire.read(); // Skip temperature
    gyroX = Wire.read() << 8 | Wire.read();
    gyroY = Wire.read() << 8 | Wire.read();
    gyroZ = Wire.read() << 8 | Wire.read();
  }
}

void calculateRollPitch() {
  float accelXf = accelX / 16384.0;
  float accelYf = accelY / 16384.0;
  float accelZf = accelZ / 16384.0;
  roll = atan2(accelYf, sqrt(accelXf * accelXf + accelZf * accelZf)) * 180.0 / M_PI;
  pitch = atan2(-accelXf, sqrt(accelYf * accelYf + accelZf * accelZf)) * 180.0 / M_PI;
}

void complementaryFilter() {
  unsigned long currentTime = millis();
  dt = (currentTime - previousTime) / 1000.0;
  previousTime = currentTime;

  float gyroRollRate = gyroX / 131.0;
  float gyroPitchRate = gyroY / 131.0;

  gyroRoll += gyroRollRate * dt;
  gyroPitch += gyroPitchRate * dt;

  complementaryRoll = alpha * (complementaryRoll + gyroRollRate * dt) + (1 - alpha) * roll;
  complementaryPitch = alpha * (complementaryPitch + gyroPitchRate * dt) + (1 - alpha) * pitch;
}

void loop() {
  // Read and process IMU data
  readIMUData();
  calculateRollPitch();
  complementaryFilter();

  // Send data via BLE if connected
  if (deviceConnected) {
    // Create data string: "roll,pitch"
    String data = String(complementaryRoll, 2) + "," + String(complementaryPitch, 2);
    pCharacteristic->setValue(data.c_str());
    pCharacteristic->notify();
    
    Serial.print("Sent: ");
    Serial.println(data);
  }

  // Handle disconnection
  if (!deviceConnected && oldDeviceConnected) {
    delay(500);
    pServer->startAdvertising();
    Serial.println("Start advertising again");
    oldDeviceConnected = deviceConnected;
  }
  
  // Handle new connection
  if (deviceConnected && !oldDeviceConnected) {
    oldDeviceConnected = deviceConnected;
  }

  delay(50);
}
