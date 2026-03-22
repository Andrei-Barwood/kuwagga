/**
 * @brief Initialize MPU6050 gyroscope.
 *        Sets power mode, gyro range (±250 deg/s), and accelerometer range (±2g).
 * @return true on success, false otherwise.
 */
 bool HAL_Gyro_Init(void) {
    uint8_t data;

    // Check WHO_AM_I register (should be 0x68)
    if (HAL_I2C_Mem_Read(&hi2c1, MPU6050_ADDR, MPU6050_WHO_AM_I, 1, &data, 1, 100) != HAL_OK)
        return false;
    if (data != 0x68)
        return false;

    // Wake up MPU6050 (write 0 to power management register)
    data = 0x00;
    if (HAL_I2C_Mem_Write(&hi2c1, MPU6050_ADDR, MPU6050_PWR_MGMT_1, 1, &data, 1, 100) != HAL_OK)
        return false;

    // Set gyro full scale to ±250 deg/s (register value 0x00)
    data = 0x00;
    if (HAL_I2C_Mem_Write(&hi2c1, MPU6050_ADDR, MPU6050_GYRO_CONFIG, 1, &data, 1, 100) != HAL_OK)
        return false;

    // Set accelerometer full scale to ±2g (register value 0x00)
    data = 0x00;
    if (HAL_I2C_Mem_Write(&hi2c1, MPU6050_ADDR, MPU6050_ACCEL_CONFIG, 1, &data, 1, 100) != HAL_OK)
        return false;

    return true;
}

/**
 * @brief Read raw gyroscope data from MPU6050.
 * @param out_x, out_y, out_z: pointers to store rotation rates (rad/s).
 * @return true on success, false otherwise.
 */
bool HAL_Gyro_ReadRaw(double* out_x, double* out_y, double* out_z) {
    uint8_t buf[6];

    // Read 6 bytes from GYRO_XOUT_H (0x43)
    if (HAL_I2C_Mem_Read(&hi2c1, MPU6050_ADDR, MPU6050_GYRO_XOUT_H, 1, buf, 6, 100) != HAL_OK)
        return false;

    // Convert to 16-bit signed values
    int16_t raw_x = (buf[0] << 8) | buf[1];
    int16_t raw_y = (buf[2] << 8) | buf[3];
    int16_t raw_z = (buf[4] << 8) | buf[5];

    // Convert to rad/s: (raw / sensitivity) * (π/180)
    const double deg_to_rad = M_PI / 180.0;
    *out_x = ((double)raw_x / MPU6050_GYRO_SENSITIVITY_250) * deg_to_rad;
    *out_y = ((double)raw_y / MPU6050_GYRO_SENSITIVITY_250) * deg_to_rad;
    *out_z = ((double)raw_z / MPU6050_GYRO_SENSITIVITY_250) * deg_to_rad;

    return true;
}