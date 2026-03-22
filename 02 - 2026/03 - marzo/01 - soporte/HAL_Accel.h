/**
 * @brief Initialize accelerometer (same MPU6050 already initialized).
 *        We can reuse the MPU6050 init from gyro, so this just returns true.
 * @return true always (since MPU6050 already initialized).
 */
 bool HAL_Accel_Init(void) {
    // MPU6050 accelerometer is already initialised in HAL_Gyro_Init()
    return true;
}

/**
 * @brief Read raw accelerometer data from MPU6050.
 * @param out_x, out_y, out_z: pointers to store acceleration (g).
 * @return true on success, false otherwise.
 */
bool HAL_Accel_ReadRaw(double* out_x, double* out_y, double* out_z) {
    uint8_t buf[6];

    // Read 6 bytes from ACCEL_XOUT_H (0x3B)
    if (HAL_I2C_Mem_Read(&hi2c1, MPU6050_ADDR, MPU6050_ACCEL_XOUT_H, 1, buf, 6, 100) != HAL_OK)
        return false;

    int16_t raw_x = (buf[0] << 8) | buf[1];
    int16_t raw_y = (buf[2] << 8) | buf[3];
    int16_t raw_z = (buf[4] << 8) | buf[5];

    // Convert to g: raw / sensitivity (16384 for ±2g)
    *out_x = (double)raw_x / MPU6050_ACCEL_SENSITIVITY_2g;
    *out_y = (double)raw_y / MPU6050_ACCEL_SENSITIVITY_2g;
    *out_z = (double)raw_z / MPU6050_ACCEL_SENSITIVITY_2g;

    return true;
}