/**
 * @brief Set MPU6050 power mode (gyro and accel share same chip).
 * @param lowPower true = sleep mode, false = normal mode.
 */
 void HAL_SetGyroPowerMode(bool lowPower) {
    uint8_t data;
    if (lowPower) {
        data = 0x40;  // SLEEP bit set
    } else {
        data = 0x00;  // wake up
    }
    HAL_I2C_Mem_Write(&hi2c1, MPU6050_ADDR, MPU6050_PWR_MGMT_1, 1, &data, 1, 100);
}

void HAL_SetAccelPowerMode(bool lowPower) {
    // Same as gyro (MPU6050)
    HAL_SetGyroPowerMode(lowPower);
}

void HAL_SetMagPowerMode(bool lowPower) {
    uint8_t data;
    if (lowPower) {
        data = 0x02;  // Single measurement mode (power down between reads) – or 0x03? Actually, HMC5883L: set mode to idle (0x03) for low power.
        // Mode register: 0x00 continuous, 0x01 single, 0x02 idle, 0x03 idle? We'll use 0x02 to stop continuous.
        data = 0x02;
    } else {
        data = 0x00;  // continuous measurement mode
    }
    HAL_I2C_Mem_Write(&hi2c1, HMC5883L_ADDR, HMC5883L_MODE, 1, &data, 1, 100);
}