/**
 * @file gyro_service.h
 * @brief Apple Core Motion-style gyroscope service for taximeter firmware.
 *        Provides raw rotation rates (rad/s) and processed attitude (roll/pitch/yaw).
 */

 #ifndef GYRO_SERVICE_H
 #define GYRO_SERVICE_H
 
 #include <stdint.h>
 #include <stdbool.h>
 
 //==============================================================================
 // Data Structures (Mirroring Apple's CMGyroData and CMDeviceMotion)
 //==============================================================================
 
 /**
  * Raw gyroscope data (CMGyroData equivalent).
  * Rotation rates in radians per second around X, Y, and Z axes.
  * Positive values follow the right-hand rule around each axis.
  */
 typedef struct {
     double rotationRate_x;  ///< Rotation rate around X axis (rad/s)
     double rotationRate_y;  ///< Rotation rate around Y axis (rad/s)
     double rotationRate_z;  ///< Rotation rate around Z axis (rad/s)
     uint64_t timestamp_ms;  ///< Milliseconds since system boot
 } CMGyroData;
 
 /**
  * Processed device-motion data (CMDeviceMotion equivalent).
  * Includes attitude (roll/pitch/yaw) and unbiased rotation rates.
  * All angles in radians.
  */
 typedef struct {
     // Attitude (orientation) in radians
     double roll;   ///< Rotation around X axis (-π to π)
     double pitch;  ///< Rotation around Y axis (-π/2 to π/2)
     double yaw;    ///< Rotation around Z axis (0 to 2π)
 
     // Unbiased rotation rate (rad/s) after sensor fusion
     double rotationRate_x;
     double rotationRate_y;
     double rotationRate_z;
 
     uint64_t timestamp_ms;
 } CMDeviceMotion;
 
 //==============================================================================
 // CMMotionManager Class Interface
 //==============================================================================
 
 typedef struct {
     // Configuration
     double gyroUpdateInterval;        ///< Desired update interval (seconds), e.g., 0.02 = 50 Hz
     double deviceMotionUpdateInterval;///< Desired device-motion update interval (seconds)
 
     // State
     bool isGyroActive;                ///< True if gyroscope updates are running
     bool isDeviceMotionActive;        ///< True if device-motion updates are running
 
     // Latest data (polling mode)
     CMGyroData latestGyroData;
     CMDeviceMotion latestDeviceMotion;
 
     // Internal use (private)
     void* internal;                   ///< Pointer to private driver state
 } CMMotionManager;
 
 //==============================================================================
 // Public API (Apple Core Motion Style)
 //==============================================================================
 
 /**
  * @brief Initializes a new motion manager instance.
  * @param manager Pointer to CMMotionManager structure to initialize.
  */
 void CMMotionManager_init(CMMotionManager* manager);
 
 /**
  * @brief Checks if gyroscope hardware is available on the device.
  * @param manager Pointer to initialized motion manager.
  * @return true if gyroscope is present and initialized, false otherwise.
  */
 bool CMMotionManager_isGyroAvailable(CMMotionManager* manager);
 
 /**
  * @brief Starts raw gyroscope updates (polling mode).
  *        The system updates manager->latestGyroData at the specified interval.
  *        Call CMMotionManager_readCurrentGyroData() to get the latest sample.
  * @param manager Pointer to initialized motion manager.
  */
 void CMMotionManager_startGyroUpdates(CMMotionManager* manager);
 
 /**
  * @brief Stops raw gyroscope updates to save power.
  * @param manager Pointer to initialized motion manager.
  */
 void CMMotionManager_stopGyroUpdates(CMMotionManager* manager);
 
 /**
  * @brief Reads the latest raw gyroscope data (polling mode).
  * @param manager Pointer to initialized motion manager.
  * @param outData Pointer to CMGyroData structure to fill with latest data.
  * @return true if new data was available, false otherwise.
  */
 bool CMMotionManager_readCurrentGyroData(CMMotionManager* manager, CMGyroData* outData);
 
 /**
  * @brief Checks if device-motion (processed) service is available.
  * @param manager Pointer to initialized motion manager.
  * @return true if device-motion service can be started, false otherwise.
  */
 bool CMMotionManager_isDeviceMotionAvailable(CMMotionManager* manager);
 
 /**
  * @brief Starts processed device-motion updates (polling mode).
  *        Enables sensor fusion (gyro + accelerometer + magnetometer if available).
  *        Call CMMotionManager_readCurrentDeviceMotion() to get attitude and unbiased rates.
  * @param manager Pointer to initialized motion manager.
  */
 void CMMotionManager_startDeviceMotionUpdates(CMMotionManager* manager);
 
 /**
  * @brief Stops device-motion updates to save power.
  * @param manager Pointer to initialized motion manager.
  */
 void CMMotionManager_stopDeviceMotionUpdates(CMMotionManager* manager);
 
 /**
  * @brief Reads the latest processed device-motion data.
  * @param manager Pointer to initialized motion manager.
  * @param outData Pointer to CMDeviceMotion structure to fill.
  * @return true if new data was available, false otherwise.
  */
 bool CMMotionManager_readCurrentDeviceMotion(CMMotionManager* manager, CMDeviceMotion* outData);
 
 /**
  * @brief Optional: Call this periodically (e.g., in main loop or timer ISR) to update
  *        internal sensor readings. The manager uses its configured intervals.
  * @param manager Pointer to initialized motion manager.
  */
 void CMMotionManager_update(CMMotionManager* manager);
 
 #endif // GYRO_SERVICE_H