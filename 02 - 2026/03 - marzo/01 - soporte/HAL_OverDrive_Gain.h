/**
 * @brief Initialize HMC5883L magnetometer.
 *        Sets measurement mode, gain, and continuous conversion.
 * @return true on success, false otherwise.
 */
 bool HAL_Mag_Init(void) {
    uint8_t data;

    // Check device ID? HMC5883L doesn't have a WHO_AM_I. We'll rely on read success.

    // Set configuration A: 8 samples average, 75 Hz output rate, normal measurement
    data = 0x70;  // 0b01110000
    if (HAL_I2C_Mem_Write(&hi2c1, HMC5883L_ADDR, HMC5883L_CONFIG_A, 1, &data, 1, 100) != HAL_OK)
        return false;

    // Set configuration B: gain = ±1.3 Ga (0x20)
    data = 0x20;
    if (HAL_I2C_Mem_Write(&hi2c1, HMC5883L_ADDR, HMC5883L_CONFIG_B, 1, &data, 1, 100) != HAL_OK)
        return false;

    // Set mode: continuous measurement (0x00)
    data = 0x00;
    if (HAL_I2C_Mem_Write(&hi2c1, HMC5883L_ADDR, HMC5883L_MODE, 1, &data, 1, 100) != HAL_OK)
        return false;

    return true;
}

/**
 * @brief Read raw magnetometer data from HMC5883L.
 * @param out_x, out_y, out_z: pointers to store magnetic field (µT).
 * @return true on success, false otherwise.
 */
bool HAL_Mag_ReadRaw(double* out_x, double* out_y, double* out_z) {
    uint8_t buf[6];

    // Read 6 bytes from DATA_X_H (0x03)
    if (HAL_I2C_Mem_Read(&hi2c1, HMC5883L_ADDR, HMC5883L_DATA_X_H, 1, buf, 6, 100) != HAL_OK)
        return false;

    // Convert to 16-bit signed values (big-endian)
    int16_t raw_x = (buf[0] << 8) | buf[1];
    int16_t raw_y = (buf[4] << 8) | buf[5];   // NOTE: register order is X, Z, Y
    int16_t raw_z = (buf[2] << 8) | buf[3];

    // Convert to µT: raw / gain (gain = 1090 for ±1.3 Ga), then Gauss to µT (1 Gauss = 100 µT)
    const double gauss_to_ut = 100.0;
    *out_x = ((double)raw_x / HMC5883L_GAIN_1_3Ga) * gauss_to_ut;
    *out_y = ((double)raw_y / HMC5883L_GAIN_1_3Ga) * gauss_to_ut;
    *out_z = ((double)raw_z / HMC5883L_GAIN_1_3Ga) * gauss_to_ut;

    return true;
}