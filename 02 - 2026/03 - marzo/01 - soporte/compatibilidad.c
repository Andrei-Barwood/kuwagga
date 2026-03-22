// Example HAL implementation for MPU6050 or similar (pseudo-code)
bool HAL_Gyro_Init(void) {
    // Initialize I2C/SPI, configure sensor registers (ODR, full scale, etc.)
    // For taximeter, set gyro range to ±250 deg/s (4.363 rad/s) typical.
    // Write register 0x6B = 0x00 to wake up MPU6050.
    return true;
}

bool HAL_Gyro_ReadRaw(double* out_x, double* out_y, double* out_z) {
    // Read 6 bytes from gyro registers (e.g., 0x43 to 0x48)
    // Convert to rad/s based on sensitivity (e.g., 131 LSB per deg/s for ±250°/s)
    int16_t raw_x, raw_y, raw_z;
    // raw_x = (register[0] << 8) | register[1]; etc.
    const double sensitivity = 131.0; // LSB per deg/s
    *out_x = ((double)raw_x / sensitivity) * (M_PI / 180.0);
    *out_y = ((double)raw_y / sensitivity) * (M_PI / 180.0);
    *out_z = ((double)raw_z / sensitivity) * (M_PI / 180.0);
    return true;
}

bool HAL_Accel_ReadRaw(double* out_x, double* out_y, double* out_z) {
    // Read accelerometer registers (e.g., 0x3B to 0x40 for MPU6050)
    // Convert to g (9.81 m/s²) based on sensitivity (e.g., 16384 LSB/g for ±2g)
    int16_t raw_x, raw_y, raw_z;
    const double sensitivity = 16384.0;
    *out_x = (double)raw_x / sensitivity;
    *out_y = (double)raw_y / sensitivity;
    *out_z = (double)raw_z / sensitivity;
    return true;
}