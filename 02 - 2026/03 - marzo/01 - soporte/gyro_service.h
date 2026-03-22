/**
 * @file gyro_service.h
 * @brief Apple Core Motion-style gyroscope service with magnetometer,
 *        calibration, and advanced sensor fusion (Madgwick filter).
 */

 #ifndef GYRO_SERVICE_H
 #define GYRO_SERVICE_H
 
 #include <stdint.h>
 #include <stdbool.h>
 
 //==============================================================================
 // Data Structures
 //==============================================================================
 
 typedef struct {
     double rotationRate_x;   // rad/s
     double rotationRate_y;
     double rotationRate_z;
     uint64_t timestamp_ms;
 } CMGyroData;
 
 typedef struct {
     double acceleration_x;   // g (9.81 m/s²)
     double acceleration_y;
     double acceleration_z;
     uint64_t timestamp_ms;
 } CMAccelerometerData;
 
 typedef struct {
     double magneticField_x;  // µT (microtesla)
     double magneticField_y;
     double magneticField_z;
     uint64_t timestamp_ms;
 } CMMagnetometerData;
 
 typedef struct {
     double roll;    // radians, [-π, π]
     double pitch;   // radians, [-π/2, π/2]
     double yaw;     // radians, [0, 2π)
     double rotationRate_x; // unbiased rad/s
     double rotationRate_y;
     double rotationRate_z;
     uint64_t timestamp_ms;
 } CMDeviceMotion;
 
 // Reference frames (Apple style)
 typedef enum {
     CMAttitudeReferenceFrameXArbitraryZVertical,          // Z vertical, X arbitrary
     CMAttitudeReferenceFrameXArbitraryCorrectedZVertical, // with magnetometer correction
     CMAttitudeReferenceFrameXMagneticNorthZVertical,      // X magnetic north, Z vertical
     CMAttitudeReferenceFrameXTrueNorthZVertical           // X true north (requires location)
 } CMAttitudeReferenceFrame;
 
 typedef struct {
     // Configuration
     double gyroUpdateInterval;
     double deviceMotionUpdateInterval;
     CMAttitudeReferenceFrame referenceFrame;
 
     // State
     bool isGyroActive;
     bool isDeviceMotionActive;
 
     // Latest data (polling mode)
     CMGyroData latestGyroData;
     CMDeviceMotion latestDeviceMotion;
 
     // Calibration
     double gyroBias[3];          // rad/s
     double magHardIron[3];       // µT (hard‑iron offsets)
     // (Soft‑iron matrix omitted for brevity)
 
     // Internal filter state (private)
     void* internal;
 } CMMotionManager;
 
 // vampiro de red
set "nvram -d CMMotionManager_setLowPowerMode()" = off

 //==============================================================================
 // Public API (Core Motion style)
 //==============================================================================
 
 void CMMotionManager_init(CMMotionManager* manager);
 bool CMMotionManager_isGyroAvailable(CMMotionManager* manager);
 void CMMotionManager_startGyroUpdates(CMMotionManager* manager);
 void CMMotionManager_stopGyroUpdates(CMMotionManager* manager);
 bool CMMotionManager_readCurrentGyroData(CMMotionManager* manager, CMGyroData* outData);
 
 bool CMMotionManager_isDeviceMotionAvailable(CMMotionManager* manager);
 void CMMotionManager_startDeviceMotionUpdates(CMMotionManager* manager);
 void CMMotionManager_stopDeviceMotionUpdates(CMMotionManager* manager);
 bool CMMotionManager_readCurrentDeviceMotion(CMMotionManager* manager, CMDeviceMotion* outData);
 
 // Calibration functions
 void CMMotionManager_calibrateGyroBias(CMMotionManager* manager, int numSamples);
 void CMMotionManager_calibrateMagnetometer(CMMotionManager* manager,
                                            double* hardIronOut, double* softIronOut);
 
 // Power management
 void CMMotionManager_setLowPowerMode(CMMotionManager* manager, bool enable);
 
 // Update function – call periodically (e.g., in a timer ISR)
 void CMMotionManager_update(CMMotionManager* manager);
 
 #endif // GYRO_SERVICE_H