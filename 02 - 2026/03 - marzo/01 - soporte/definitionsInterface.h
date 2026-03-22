#include "stm32f1xx_hal.h"  // Example for STM32F1 – adjust to your MCU
#include <math.h>

// I2C handles (declare them globally or pass as parameters)
extern I2C_HandleTypeDef hi2c1;  // I2C bus for sensors

// Device addresses
#define MPU6050_ADDR         0xD0  // 8-bit address (0x68 << 1)
#define HMC5883L_ADDR        0x3C  // 8-bit address (0x1E << 1)

// MPU6050 register addresses
#define MPU6050_WHO_AM_I     0x75
#define MPU6050_PWR_MGMT_1   0x6B
#define MPU6050_GYRO_CONFIG  0x1B
#define MPU6050_ACCEL_CONFIG 0x1C
#define MPU6050_ACCEL_XOUT_H 0x3B
#define MPU6050_GYRO_XOUT_H  0x43

// HMC5883L register addresses
#define HMC5883L_CONFIG_A    0x00
#define HMC5883L_CONFIG_B    0x01
#define HMC5883L_MODE        0x02
#define HMC5883L_DATA_X_H    0x03

// Sensitivity constants
#define MPU6050_GYRO_SENSITIVITY_250   131.0   // LSB per deg/s
#define MPU6050_ACCEL_SENSITIVITY_2g   16384.0 // LSB per g
#define HMC5883L_GAIN_1_3Ga            1090.0  // LSB per Gauss (for ±1.3 Ga)