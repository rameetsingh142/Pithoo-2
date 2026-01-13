#include "Wire.h"
#define MUX_Address 0x70             // TCA9548A I2C Multiplexer address as A0 , A1 and A2 are 000 as connected to gnd
#define IMU_REG_PWR_MGMT_1 0x6B      // MPU6050 power management register
#define IMU_REG_ACCEL_XOUT_H 0x3B    // MPU6050 accelerometer data start
float roll , pitch;
float gyroRoll, gyroPitch;
float complementaryRoll, complementaryPitch;
float alpha = 0.96;                  // Complementary filter coefficient
unsigned long previousTime; // Separate time tracking for each IMU
float dt = 0;
int16_t accelX, accelY, accelZ;
int16_t gyroX, gyroY, gyroZ;


void setup() {
  Wire.begin(D4,D5);
  Serial.begin(115200);
  //waking up all the IMU after individually initializing each one
  //  for (int i = 1; i < 7; i++) {
  //    cases(1);      // Select each IMU on the I2C bus
  initializeIMU();   // Initialize each IMU
  //}
}

// Function to select a channel on the TCA9548A multiplexer
//void cases(uint8_t i2c_bus) {
//  if (i2c_bus > 7) return;
//  Wire.beginTransmission(MUX_Address);
//  Wire.write(1 << i2c_bus);// this is used for selecting channel number by using << shift bit operator so for example 1<<1 means 001 will be 010
//  Wire.endTransmission();
//}

// Initialize the IMU (e.g., MPU6050)
void initializeIMU() {
  Wire.beginTransmission(0x68);    // MPU6050 default address
  Wire.write(IMU_REG_PWR_MGMT_1);  //0x6B is the Power Management 1 register of the MPU6050 . This register controls how the IMU handles power.
  Wire.write(0x00);                // Wake up the IMU .This value tells the IMU to exit sleep mode.
  Wire.endTransmission(); // This sends the data to the IMU and finalizes the I2C communication and closes the transmission.
}

// Read IMU data (accelerometer and gyroscope)
void readIMUData() {
  Wire.beginTransmission(0x68);
  Wire.write(IMU_REG_ACCEL_XOUT_H);  // Starting register for accelerometer data
  Wire.endTransmission(false);   // End the transmission, but do NOT send a stop condition (use repeated start)
  Wire.requestFrom(0x68, 14);   // Request 14 bytes of data 6 accelerometer ,6 gyro and 2 temp The MPU6050 stores accelerometer, temperature, and gyroscope data in consecutive registers. By specifying the starting register (IMU_REG_ACCEL_XOUT_H for accelerometer X data, address 0x3B), you are essentially pointing to the beginning of this sequence of 14 bytes of data.

  if (Wire.available() == 14) {
    // Accelerometer data
    accelX = Wire.read() << 8 | Wire.read();//<< 8 shifts the first Wire.read() result (the high byte) 8 bits to the left, making room for the low byte in the lower 8 bits. This effectively converts the 8-bit high byte into the upper 8 bits of a 16-bit value.That is 2 byte of data
    accelY = Wire.read() << 8 | Wire.read();
    accelZ = Wire.read() << 8 | Wire.read();
    // Temperature data (ignore, 2 bytes)
    Wire.read(); Wire.read();
    // Gyroscope data
    gyroX = Wire.read() << 8 | Wire.read();
    gyroY = Wire.read() << 8 | Wire.read();
    gyroZ = Wire.read() << 8 | Wire.read();
  }
}
void calculateRollPitch() {
  float accelXf = accelX / 16384.0;  // Convert to g
  float accelYf = accelY / 16384.0;
  float accelZf = accelZ / 16384.0;
  roll = atan2(accelYf, sqrt(accelXf * accelXf + accelZf * accelZf)) * 180.0 / M_PI;
  pitch = atan2(-accelXf, sqrt(accelYf * accelYf + accelZf * accelZf)) * 180.0 / M_PI;
}
  // Update complementary filter values for each IMU
  void complementaryFilter() {
    unsigned long currentTime = millis();
    dt = (currentTime - previousTime) / 1000.0; // Time difference in seconds
    previousTime = currentTime;

    // Convert gyroscope values to degrees/second
    float gyroRollRate = gyroX / 131.0;  // Sensitivity scale factor for MPU6050 (deg/s)
    float gyroPitchRate = gyroY / 131.0;

    // Integrate the gyroscope data to calculate angle change
    gyroRoll += gyroRollRate * dt;
    gyroPitch += gyroPitchRate * dt;
    // Apply complementary filter
    complementaryRoll = alpha * (complementaryRoll + gyroRollRate * dt) + (1 - alpha) * roll;
    complementaryPitch = alpha * (complementaryPitch + gyroPitchRate * dt) + (1 - alpha) * pitch;
  }
  void loop() {
    //  for (int i = 1; i < 7 ; i++) {   // Loop through each IMU on the multiplexer
    //    cases(1);                 // Select each IMU
    readIMUData();                // Read data from the selected IMU
    calculateRollPitch();    // Calculate roll and pitch from accelerometer for this IMU
    complementaryFilter();   // Apply complementary filter for this IMU
Serial.print(complementaryRoll);
Serial.print(",");
Serial.println(complementaryPitch);


    delay(50); // Small delay for readability

  }
