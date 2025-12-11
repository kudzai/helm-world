# Scala Service Configuration Design

## Objective
Enable the Scala Service to parse the mounted configuration files (`application.conf` and `global.conf`) and log the result at startup.

## 1. Libraries
The current `build.sbt` lacks a dedicated configuration library. We recommend **PureConfig** for type-safe loading, which wraps **Typesafe Config** (HOCON).

### Recommended Dependencies
Add to `charts/service/build.sbt`:
```scala
val pureConfigVersion = "0.17.6"

libraryDependencies ++= Seq(
  "com.github.pureconfig" %% "pureconfig" % pureConfigVersion,
  "com.typesafe.scala-logging" %% "scala-logging" % "3.9.5", // Better logging than println
  // ... existing dependencies
)
```

## 2. Configuration Structure
Define Scala case classes that match your HOCON structure.

**HOCON (`application.conf`)**:
```hocon
include "/etc/config/global/global.conf"

garage {
  capacity = 50
  maintenance-mode = false
}
```

**Scala Models**:
```scala
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

// The root config structure
case class AppConfig(
  garage: GarageConfig,
  // If global values are at the root level in global.conf, 
  // they will be merged into the root.
  env: String,
  region: String,
  domain: String
)
```

## 3. Implementation Steps

### 3.1 Loading Configuration
Use `ConfigSource` to load from the mounted file. Standard Akka/Typesafe behavior looks for `application.conf` in the classpath, but here we want to load from a specific file path `/etc/config/app/application.conf`.

```scala
import pureconfig._
import pureconfig.generic.auto._
import java.nio.file.Paths

val configPath = Paths.get("/etc/config/app/application.conf")
val configSource = ConfigSource.file(configPath)

// Fallback to classpath if file doesn't exist (e.g. local run without mounts)
val finalSource = configSource.optional.withFallback(ConfigSource.default)

val appConfig = finalSource.loadOrThrow[AppConfig]
```

### 3.2 Logging
Using `scala-logging` (wraps SLF4J/Logback).

```scala
import com.typesafe.scalalogging.LazyLogging

object Main extends LazyLogging {
  def main(args: Array[String]): Unit = {
    logger.info("Starting Service...")
    
    // Load Config
    // ... (code from 3.1)
    
    logger.info(s"Loaded Configuration: $appConfig")
    
    // Use config
    if (appConfig.garage.maintenanceMode) {
      logger.warn("Maintenance Mode is ACTIVE")
    }
  }
}
```

## 4. Addressing "Includes" in Kubernetes
When `application.conf` contains `include "/etc/config/global/global.conf"`, Typesafe Config needs to be able to resolve that path.

- **Absolute Paths**: If the include string is an absolute path (starts with `/`), it works out-of-the-box provided the file exists at that path in the container.
- **Our Helm Chart**: We mount `global-config-vol` to `/etc/config/global`. So the file `/etc/config/global/global.conf` will exist.
- **Conclusion**: The include will work seamlessly.

## 5. Next Steps
When you are ready to implement:
1.  Update `build.sbt` with PureConfig.
2.  Create `AppConfig.scala` case classes.
3.  Update `Main.scala` to load and print the config object at the start of `main()`.
