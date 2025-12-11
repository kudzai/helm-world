package com.example.service.config

case class GlobalConfig(
    env: String,
    region: String,
    domain: String
)

case class GarageConfig(
    capacity: Int,
    maintenanceMode: Boolean
)

case class AppConfig(
    garage: GarageConfig,
    // Merged from global.conf include
    env: String,
    region: String,
    domain: String
)
