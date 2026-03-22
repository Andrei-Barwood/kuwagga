/**
 * @file gyro_service.c
 * @brief Implementation with Madgwick filter, magnetometer, and calibration.
 */

 #include "gyro_service.h"
 #include <string.h>
 #include <math.h>
 #include <stdlib.h>
 
 //==============================================================================
 // Hardware Abstraction Layer (HAL) – implement these for your sensor
 //==============================================================================
 
 extern bool HAL_Gyro_Init(void);
 extern bool HAL_Gyro_ReadRaw(double* out_x, double* out_y, double* out_z);
 extern bool HAL_Accel_ReadRaw(double* out_x, double* out_y, double* out_z);
 extern bool HAL_Mag_Init(void);
 extern bool HAL_Mag_ReadRaw(double* out_x, double* out_y, double* out_z);
 extern void HAL_SetGyroPowerMode(bool lowPower);
 extern void HAL_SetAccelPowerMode(bool lowPower);
 extern void HAL_SetMagPowerMode(bool lowPower);
 extern uint64_t HAL_GetTickMs(void);  // millisecond counter
 
 //==============================================================================
 // Madgwick filter implementation (6‑DOF and 9‑DOF)
 //==============================================================================
 
 typedef struct {
     double q0, q1, q2, q3;   // quaternion representing orientation
     double beta;              // filter gain (usually 0.1 to 0.2)
     bool useMag;              // true if magnetometer is available
 } MadgwickFilter;
 
 static void Madgwick_init(MadgwickFilter* f, bool useMag) {
     f->q0 = 1.0; f->q1 = 0.0; f->q2 = 0.0; f->q3 = 0.0;
     f->beta = 0.1;   // typical value, tune if needed
     f->useMag = useMag;
 }
 
 // 6‑DOF update (gyro + accelerometer)
 static void Madgwick_update6DOF(MadgwickFilter* f,
                                 double gx, double gy, double gz,
                                 double ax, double ay, double az,
                                 double dt) {
     double q0 = f->q0, q1 = f->q1, q2 = f->q2, q3 = f->q3;
     double beta = f->beta;
 
     // Normalise accelerometer measurement
     double norm = sqrt(ax*ax + ay*ay + az*az);
     if (norm == 0.0) return;
     ax /= norm; ay /= norm; az /= norm;
 
     // Gradient descent algorithm
     double s0, s1, s2, s3;
     double q0q0 = q0*q0, q0q1 = q0*q1, q0q2 = q0*q2, q0q3 = q0*q3;
     double q1q1 = q1*q1, q1q2 = q1*q2, q1q3 = q1*q3;
     double q2q2 = q2*q2, q2q3 = q2*q3;
     double q3q3 = q3*q3;
 
     s0 = 4.0 * ( (q1q1 + q2q2)*ax + (q0q1 - q2q3)*ay + (q0q2 + q1q3)*az - q0 );
     s1 = 4.0 * ( (q0q1 + q2q3)*ax + (q0q0 + q2q2)*ay + (q1q2 - q0q3)*az - q1 );
     s2 = 4.0 * ( (q0q2 - q1q3)*ax + (q1q2 + q0q3)*ay + (q0q0 + q1q1)*az - q2 );
     s3 = 4.0 * ( (q1q2 + q0q3)*ax + (q2q3 - q0q1)*ay + (q0q0 + q1q1 + q2q2 + q3q3)*az - q3 );
 
     norm = sqrt(s0*s0 + s1*s1 + s2*s2 + s3*s3);
     if (norm > 0.0) {
         s0 /= norm; s1 /= norm; s2 /= norm; s3 /= norm;
     }
 
     // Rate of change of quaternion from gyroscope
     double qDot1 = 0.5 * ( -q1*gx - q2*gy - q3*gz );
     double qDot2 = 0.5 * (  q0*gx - q3*gy + q2*gz );
     double qDot3 = 0.5 * (  q3*gx + q0*gy - q1*gz );
     double qDot4 = 0.5 * ( -q2*gx + q1*gy + q0*gz );
 
     // Apply feedback
     qDot1 -= beta * s0;
     qDot2 -= beta * s1;
     qDot3 -= beta * s2;
     qDot4 -= beta * s3;
 
     // Integrate
     f->q0 += qDot1 * dt;
     f->q1 += qDot2 * dt;
     f->q2 += qDot3 * dt;
     f->q3 += qDot4 * dt;
 
     // Normalise quaternion
     norm = sqrt(f->q0*f->q0 + f->q1*f->q1 + f->q2*f->q2 + f->q3*f->q3);
     if (norm > 0.0) {
         f->q0 /= norm; f->q1 /= norm; f->q2 /= norm; f->q3 /= norm;
     }
 }
 
 // 9‑DOF update (gyro + accel + mag) – Madgwick's original algorithm
 static void Madgwick_update9DOF(MadgwickFilter* f,
                                 double gx, double gy, double gz,
                                 double ax, double ay, double az,
                                 double mx, double my, double mz,
                                 double dt) {
     double q0 = f->q0, q1 = f->q1, q2 = f->q2, q3 = f->q3;
     double beta = f->beta;
 
     // Normalise accelerometer
     double norm = sqrt(ax*ax + ay*ay + az*az);
     if (norm == 0.0) return;
     ax /= norm; ay /= norm; az /= norm;
 
     // Normalise magnetometer
     norm = sqrt(mx*mx + my*my + mz*mz);
     if (norm == 0.0) return;
     mx /= norm; my /= norm; mz /= norm;
 
     // Auxiliary variables to avoid repeated calculations
     double q0q0 = q0*q0, q0q1 = q0*q1, q0q2 = q0*q2, q0q3 = q0*q3;
     double q1q1 = q1*q1, q1q2 = q1*q2, q1q3 = q1*q3;
     double q2q2 = q2*q2, q2q3 = q2*q3;
     double q3q3 = q3*q3;
 
     // Reference direction of Earth's magnetic field (assumed horizontal and pointing north)
     double hx = 2.0 * (mx*(0.5 - q2q2 - q3q3) + my*(q1q2 - q0q3) + mz*(q1q3 + q0q2));
     double hy = 2.0 * (mx*(q1q2 + q0q3) + my*(0.5 - q1q1 - q3q3) + mz*(q2q3 - q0q1));
     double bx = sqrt(hx*hx + hy*hy);
     double bz = 2.0 * (mx*(q1q3 - q0q2) + my*(q2q3 + q0q1) + mz*(0.5 - q1q1 - q2q2));
 
     // Gradient descent algorithm (accelerometer + magnetometer)
     double s0, s1, s2, s3;
 
     // Accelerometer part
     s0 = 4.0 * ( (q1q1 + q2q2)*ax + (q0q1 - q2q3)*ay + (q0q2 + q1q3)*az - q0 );
     s1 = 4.0 * ( (q0q1 + q2q3)*ax + (q0q0 + q2q2)*ay + (q1q2 - q0q3)*az - q1 );
     s2 = 4.0 * ( (q0q2 - q1q3)*ax + (q1q2 + q0q3)*ay + (q0q0 + q1q1)*az - q2 );
     s3 = 4.0 * ( (q1q2 + q0q3)*ax + (q2q3 - q0q1)*ay + (q0q0 + q1q1 + q2q2 + q3q3)*az - q3 );
 
     // Magnetometer part
     s0 += 4.0 * ( (q1q1 + q2q2)*bx + (q0q1 - q2q3)*bz - (q0q1 + q2q3)*bx - (q0q2 - q1q3)*bz );
     s1 += 4.0 * ( (q0q1 + q2q3)*bx + (q0q0 + q2q2)*bz - (q1q1 + q2q2)*bx - (q0q3 + q1q2)*bz );
     s2 += 4.0 * ( (q0q2 - q1q3)*bx + (q1q2 + q0q3)*bz - (q2q3 + q0q1)*bx - (q0q0 + q1q1)*bz );
     s3 += 4.0 * ( (q1q2 + q0q3)*bx + (q2q3 - q0q1)*bz - (q1q3 - q0q2)*bx - (q0q0 + q1q1 + q2q2 + q3q3)*bz );
 
     norm = sqrt(s0*s0 + s1*s1 + s2*s2 + s3*s3);
     if (norm > 0.0) {
         s0 /= norm; s1 /= norm; s2 /= norm; s3 /= norm;
     }
 
     // Rate of change of quaternion from gyroscope
     double qDot1 = 0.5 * ( -q1*gx - q2*gy - q3*gz );
     double qDot2 = 0.5 * (  q0*gx - q3*gy + q2*gz );
     double qDot3 = 0.5 * (  q3*gx + q0*gy - q1*gz );
     double qDot4 = 0.5 * ( -q2*gx + q1*gy + q0*gz );
 
     // Apply feedback
     qDot1 -= beta * s0;
     qDot2 -= beta * s1;
     qDot3 -= beta * s2;
     qDot4 -= beta * s3;
 
     // Integrate
     f->q0 += qDot1 * dt;
     f->q1 += qDot2 * dt;
     f->q2 += qDot3 * dt;
     f->q3 += qDot4 * dt;
 
     // Normalise
     norm = sqrt(f->q0*f->q0 + f->q1*f->q1 + f->q2*f->q2 + f->q3*f->q3);
     if (norm > 0.0) {
         f->q0 /= norm; f->q1 /= norm; f->q2 /= norm; f->q3 /= norm;
     }
 }
 
 // Convert quaternion to Euler angles (roll, pitch, yaw)
 static void Madgwick_getEuler(const MadgwickFilter* f, double* roll, double* pitch, double* yaw) {
     double q0 = f->q0, q1 = f->q1, q2 = f->q2, q3 = f->q3;
 
     // Roll (X axis)
     *roll = atan2(2.0*(q0*q1 + q2*q3), 1.0 - 2.0*(q1*q1 + q2*q2));
 
     // Pitch (Y axis)
     double sinp = 2.0*(q0*q2 - q3*q1);
     if (fabs(sinp) >= 1.0)
         *pitch = copysign(M_PI/2.0, sinp);
     else
         *pitch = asin(sinp);
 
     // Yaw (Z axis)
     *yaw = atan2(2.0*(q0*q3 + q1*q2), 1.0 - 2.0*(q2*q2 + q3*q3));
     if (*yaw < 0) *yaw += 2.0*M_PI;
 }
 
 //==============================================================================
 // Internal structure for CMMotionManager (private)
 //==============================================================================
 
 typedef struct {
     MadgwickFilter filter;
     uint64_t lastUpdateMs;
     bool haveMag;
     double lastAccel[3];   // optional for delta time calculation
 } PrivateState;
 
 //==============================================================================
 // Public API Implementation
 //==============================================================================
 
 void CMMotionManager_init(CMMotionManager* manager) {
     memset(manager, 0, sizeof(CMMotionManager));
 
     manager->gyroUpdateInterval = 0.02;     // 50 Hz
     manager->deviceMotionUpdateInterval = 0.02;
     manager->referenceFrame = CMAttitudeReferenceFrameXArbitraryZVertical;
     manager->isGyroActive = false;
     manager->isDeviceMotionActive = false;
 
     // Zero calibration biases
     manager->gyroBias[0] = manager->gyroBias[1] = manager->gyroBias[2] = 0.0;
     manager->magHardIron[0] = manager->magHardIron[1] = manager->magHardIron[2] = 0.0;
 
     // Allocate private state
     PrivateState* priv = (PrivateState*)malloc(sizeof(PrivateState));
     if (priv) {
         memset(priv, 0, sizeof(PrivateState));
         manager->internal = priv;
     }
 
     // Initialise hardware
     HAL_Gyro_Init();
     HAL_Accel_Init();   // assume exists
     priv->haveMag = HAL_Mag_Init();   // try to initialise magnetometer
 
     // Set initial quaternion to identity
     if (priv) {
         Madgwick_init(&priv->filter, priv->haveMag);
     }
 }
 
 bool CMMotionManager_isGyroAvailable(CMMotionManager* manager) {
     (void)manager;
     // In real code: check sensor WHO_AM_I, return true if available
     return true;
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
     // Requires at least gyro + accelerometer
     return CMMotionManager_isGyroAvailable(manager);
 }
 
 void CMMotionManager_startDeviceMotionUpdates(CMMotionManager* manager) {
     if (manager->isDeviceMotionActive) return;
     manager->isDeviceMotionActive = true;
 
     PrivateState* priv = (PrivateState*)manager->internal;
     if (priv) {
         // Reset filter (optional)
         Madgwick_init(&priv->filter, priv->haveMag);
         priv->lastUpdateMs = HAL_GetTickMs();
     }
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
 
 // Calibrate gyroscope bias: average N samples while stationary
 void CMMotionManager_calibrateGyroBias(CMMotionManager* manager, int numSamples) {
     double sum[3] = {0,0,0};
     int count = 0;
 
     for (int i = 0; i < numSamples; i++) {
         double gx, gy, gz;
         if (HAL_Gyro_ReadRaw(&gx, &gy, &gz)) {
             sum[0] += gx; sum[1] += gy; sum[2] += gz;
             count++;
         }
         // small delay (e.g., 10 ms) – implement with HAL_Delay
         // HAL_Delay(10);
     }
 
     if (count > 0) {
         manager->gyroBias[0] = sum[0] / count;
         manager->gyroBias[1] = sum[1] / count;
         manager->gyroBias[2] = sum[2] / count;
     }
 }
 
 // Calibrate magnetometer hard‑iron offsets (simple 3‑axis max/min)
 void CMMotionManager_calibrateMagnetometer(CMMotionManager* manager,
                                            double* hardIronOut, double* softIronOut) {
     // This is a placeholder for a simple calibration routine.
     // In practice, you would rotate the device in all orientations and record min/max.
     // Hard‑iron offsets are the midpoint of each axis.
     double minX = 0, maxX = 0, minY = 0, maxY = 0, minZ = 0, maxZ = 0;
     // ... collect samples while moving the device ...
 
     // Set hard‑iron offsets
     manager->magHardIron[0] = (minX + maxX) / 2.0;
     manager->magHardIron[1] = (minY + maxY) / 2.0;
     manager->magHardIron[2] = (minZ + maxZ) / 2.0;
 
     if (hardIronOut) {
         hardIronOut[0] = manager->magHardIron[0];
         hardIronOut[1] = manager->magHardIron[1];
         hardIronOut[2] = manager->magHardIron[2];
     }
     // Soft‑iron (3x3 matrix) omitted – would require more complex calibration.
 }
 
 void CMMotionManager_setLowPowerMode(CMMotionManager* manager, bool enable) {
     if (enable) {
         HAL_SetGyroPowerMode(true);
         HAL_SetAccelPowerMode(true);
         HAL_SetMagPowerMode(true);
     } else {
         HAL_SetGyroPowerMode(false);
         HAL_SetAccelPowerMode(false);
         HAL_SetMagPowerMode(false);
     }
 }
 
 // Called periodically (e.g., in a timer ISR) – must be called at a rate >= desired output rate
 void CMMotionManager_update(CMMotionManager* manager) {
     PrivateState* priv = (PrivateState*)manager->internal;
     if (!priv) return;
 
     uint64_t now = HAL_GetTickMs();
     double dt = (now - priv->lastUpdateMs) / 1000.0;
     if (dt <= 0.0) dt = 0.01; // fallback to 10ms
     priv->lastUpdateMs = now;
 
     //--------------------------------------------------------------------------
     // 1. Read raw gyroscope (apply bias calibration)
     //--------------------------------------------------------------------------
     double gx = 0, gy = 0, gz = 0;
     if (HAL_Gyro_ReadRaw(&gx, &gy, &gz)) {
         gx -= manager->gyroBias[0];
         gy -= manager->gyroBias[1];
         gz -= manager->gyroBias[2];
 
         manager->latestGyroData.rotationRate_x = gx;
         manager->latestGyroData.rotationRate_y = gy;
         manager->latestGyroData.rotationRate_z = gz;
         manager->latestGyroData.timestamp_ms = now;
     } else {
         return; // no new data, keep old
     }
 
     //--------------------------------------------------------------------------
     // 2. Read accelerometer
     //--------------------------------------------------------------------------
     double ax = 0, ay = 0, az = 0;
     HAL_Accel_ReadRaw(&ax, &ay, &az);  // already in g units
 
     //--------------------------------------------------------------------------
     // 3. If device‑motion active, run sensor fusion
     //--------------------------------------------------------------------------
     if (manager->isDeviceMotionActive) {
         // Read magnetometer if available and if reference frame requires it
         double mx = 0, my = 0, mz = 0;
         bool useMag = (priv->haveMag &&
                        (manager->referenceFrame == CMAttitudeReferenceFrameXArbitraryCorrectedZVertical ||
                         manager->referenceFrame == CMAttitudeReferenceFrameXMagneticNorthZVertical));
 
         if (useMag) {
             if (HAL_Mag_ReadRaw(&mx, &my, &mz)) {
                 // Apply hard‑iron offset
                 mx -= manager->magHardIron[0];
                 my -= manager->magHardIron[1];
                 mz -= manager->magHardIron[2];
             } else {
                 useMag = false; // fallback to 6‑DOF
             }
         }
 
         if (useMag) {
             Madgwick_update9DOF(&priv->filter, gx, gy, gz, ax, ay, az, mx, my, mz, dt);
         } else {
             Madgwick_update6DOF(&priv->filter, gx, gy, gz, ax, ay, az, dt);
         }
 
         // Extract Euler angles
         double roll, pitch, yaw;
         Madgwick_getEuler(&priv->filter, &roll, &pitch, &yaw);
 
         // Fill latestDeviceMotion
         manager->latestDeviceMotion.roll = roll;
         manager->latestDeviceMotion.pitch = pitch;
         manager->latestDeviceMotion.yaw = yaw;
         manager->latestDeviceMotion.rotationRate_x = gx;
         manager->latestDeviceMotion.rotationRate_y = gy;
         manager->latestDeviceMotion.rotationRate_z = gz;
         manager->latestDeviceMotion.timestamp_ms = now;
     }
 }