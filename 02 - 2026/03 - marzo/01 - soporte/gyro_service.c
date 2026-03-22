/**
 * @file gyro_service.c
 * @brief Implementation of Apple-style gyroscope service for embedded firmware.
 */

 #include "gyro_service.h"
 #include <string.h>
 #include <math.h>
 
 //==============================================================================
 // Hardware Abstraction Layer (HAL) – Implement these for your specific sensor!
 //==============================================================================
 
 /**
  * @brief Initializes the gyroscope sensor hardware (I2C/SPI, registers, etc.).
  * @return true on success, false on failure.
  */
 extern bool HAL_Gyro_Init(void);
 
 /**
  * @brief Reads raw gyroscope data from sensor registers.
  * @param out_x Pointer to store X-axis rotation rate (rad/s).
  * @param out_y Pointer to store Y-axis rotation rate (rad/s).
  * @param out_z Pointer to store Z-axis rotation rate (rad/s).
  * @return true if read succeeded, false otherwise.
  */
 extern bool HAL_Gyro_ReadRaw(double* out_x, double* out_y, double* out_z);
 
 /**
  * @brief Optional: Reads accelerometer data for sensor fusion (if available).
  * @param out_x Acceleration in g (9.81 m/s²) on X axis.
  * @param out_y Acceleration in g on Y axis.
  * @param out_z Acceleration in g on Z axis.
  * @return true if read succeeded, false otherwise.
  */
 extern bool HAL_Accel_ReadRaw(double* out_x, double* out_y, double* out_z);
 
 //==============================================================================
 // Private Helper Functions
 //==============================================================================
 
 // Simple complementary filter for attitude estimation (roll/pitch/yaw)
 // If you have a magnetometer, use it to correct yaw drift; this is a minimal example.
 static void _update_attitude_complementary(CMMotionManager* manager,
                                            double gx, double gy, double gz,
                                            double ax, double ay, double az,
                                            double dt) {
     // Calculate roll and pitch from accelerometer (gravity vector)
     double accel_roll = atan2(ay, az);
     double accel_pitch = atan2(-ax, sqrt(ay*ay + az*az));
 
     // Complementary filter: 98% gyro integration, 2% accelerometer
     // This is a simplified approach; a full Kalman/Mahony filter would be better.
     manager->latestDeviceMotion.roll = 0.98 * (manager->latestDeviceMotion.roll + gx * dt)
                                       + 0.02 * accel_roll;
     manager->latestDeviceMotion.pitch = 0.98 * (manager->latestDeviceMotion.pitch + gy * dt)
                                        + 0.02 * accel_pitch;
 
     // Yaw (heading) – without magnetometer, use only gyro integration (will drift)
     manager->latestDeviceMotion.yaw += gz * dt;
     // Keep yaw in range [0, 2π)
     if (manager->latestDeviceMotion.yaw < 0) manager->latestDeviceMotion.yaw += 2 * M_PI;
     if (manager->latestDeviceMotion.yaw >= 2 * M_PI) manager->latestDeviceMotion.yaw -= 2 * M_PI;
 }
 
 //==============================================================================
 // Public API Implementation
 //==============================================================================
 
 void CMMotionManager_init(CMMotionManager* manager) {
     memset(manager, 0, sizeof(CMMotionManager));
 
     // Default update rates: 50 Hz for gyro, 50 Hz for device-motion
     manager->gyroUpdateInterval = 0.02;
     manager->deviceMotionUpdateInterval = 0.02;
 
     manager->isGyroActive = false;
     manager->isDeviceMotionActive = false;
 
     // Initialize hardware abstraction
     HAL_Gyro_Init();
 }
 
 bool CMMotionManager_isGyroAvailable(CMMotionManager* manager) {
     // In a real implementation, check sensor presence via WHO_AM_I register.
     // For now, assume HAL init success indicates availability.
     (void)manager;
     return true; // Placeholder – replace with actual detection
 }
 
 void CMMotionManager_startGyroUpdates(CMMotionManager* manager) {
     if (manager->isGyroActive) return;
     manager->isGyroActive = true;
 }
 
 void CMMotionManager_stopGyroUpdates(CMMotionManager* manager) {
     manager->isGyroActive = false;
 }
 
 bool CMMotionManager_readCurrentGyroData(CMMotionManager* manager, CMGyroData* outData) {
     if (!manager->isGyroActive) return false;
     if (outData) {
         *outData = manager->latestGyroData;
     }
     return true;
 }
 
 bool CMMotionManager_isDeviceMotionAvailable(CMMotionManager* manager) {
     // Device-motion requires both gyro and accelerometer
     return CMMotionManager_isGyroAvailable(manager); // Add accel check if needed
 }
 
 void CMMotionManager_startDeviceMotionUpdates(CMMotionManager* manager) {
     if (manager->isDeviceMotionActive) return;
     manager->isDeviceMotionActive = true;
 
     // Reset attitude to current orientation (optional)
     // A proper implementation would calibrate to a known reference frame.
     manager->latestDeviceMotion.roll = 0.0;
     manager->latestDeviceMotion.pitch = 0.0;
     manager->latestDeviceMotion.yaw = 0.0;
 }
 
 void CMMotionManager_stopDeviceMotionUpdates(CMMotionManager* manager) {
     manager->isDeviceMotionActive = false;
 }
 
 bool CMMotionManager_readCurrentDeviceMotion(CMMotionManager* manager, CMDeviceMotion* outData) {
     if (!manager->isDeviceMotionActive) return false;
     if (outData) {
         *outData = manager->latestDeviceMotion;
     }
     return true;
 }
 
 // This function should be called periodically (e.g., by a timer interrupt or main loop)
 void CMMotionManager_update(CMMotionManager* manager) {
     static uint64_t last_update_ms = 0;
     uint64_t now_ms = 0; // Obtain actual system time (HAL_GetTick() or similar)
 
     // Dummy timestamp – replace with actual time source
     // Example: now_ms = HAL_GetTick();
 
     double dt = (now_ms - last_update_ms) / 1000.0;
     if (dt <= 0) dt = 0.01; // Default 10ms if no valid time
 
     //----------------------------------------------------------------------
     // 1. Read raw gyroscope data
     //----------------------------------------------------------------------
     double gx = 0, gy = 0, gz = 0;
     if (HAL_Gyro_ReadRaw(&gx, &gy, &gz)) {
         manager->latestGyroData.rotationRate_x = gx;
         manager->latestGyroData.rotationRate_y = gy;
         manager->latestGyroData.rotationRate_z = gz;
         manager->latestGyroData.timestamp_ms = now_ms;
 
         // If device-motion is active, copy unbiased rotation rates (raw for now)
         if (manager->isDeviceMotionActive) {
             manager->latestDeviceMotion.rotationRate_x = gx;
             manager->latestDeviceMotion.rotationRate_y = gy;
             manager->latestDeviceMotion.rotationRate_z = gz;
             manager->latestDeviceMotion.timestamp_ms = now_ms;
         }
     }
 
     //----------------------------------------------------------------------
     // 2. If device-motion active, read accelerometer and run attitude filter
     //----------------------------------------------------------------------
     if (manager->isDeviceMotionActive) {
         double ax = 0, ay = 0, az = 0;
         if (HAL_Accel_ReadRaw(&ax, &ay, &az)) {
             // Convert accelerometer raw data to meaningful units (g) if needed.
             // Complementary filter updates roll/pitch/yaw.
             _update_attitude_complementary(manager, gx, gy, gz, ax, ay, az, dt);
         }
     }
 
     last_update_ms = now_ms;
 }