#include "gyro_service.h"

CMMotionManager motionManager;

// Called once at system startup
void taximeter_init(void) {
    CMMotionManager_init(&motionManager);
    motionManager.deviceMotionUpdateInterval = 0.02; // 50 Hz

    if (CMMotionManager_isDeviceMotionAvailable(&motionManager)) {
        CMMotionManager_startDeviceMotionUpdates(&motionManager);
    }
}

// Called periodically (e.g., every 10 ms from a timer ISR or main loop)
void taximeter_timer_callback(void) {
    CMMotionManager_update(&motionManager);

    CMDeviceMotion motion;
    if (CMMotionManager_readCurrentDeviceMotion(&motionManager, &motion)) {
        // Use attitude data for taximeter functions
        double roll  = motion.roll;   // vehicle lean angle
        double pitch = motion.pitch;  // slope of road
        double yaw   = motion.yaw;    // heading change for distance calculation

        // Example: Detect turns for trip recording
        if (fabs(motion.rotationRate_z) > 0.5) { // > ~30 deg/s
            // Vehicle is turning sharply
        }
    }
}