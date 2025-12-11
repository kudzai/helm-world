name := "api-service"

version := "0.1"

scalaVersion := "2.13.12"

val akkaVersion = "2.8.5"
val akkaHttpVersion = "10.5.3"

libraryDependencies ++= Seq(
  "com.typesafe.akka" %% "akka-actor-typed" % akkaVersion,
  "com.typesafe.akka" %% "akka-stream" % akkaVersion,
  "com.typesafe.akka" %% "akka-http" % akkaHttpVersion,
  "com.typesafe.akka" %% "akka-http-spray-json" % akkaHttpVersion,
  "org.apache.spark" %% "spark-launcher" % "3.5.6",
  "ch.qos.logback" % "logback-classic" % "1.4.11",
  "com.github.pureconfig" %% "pureconfig" % "0.17.6",
  "com.typesafe.scala-logging" %% "scala-logging" % "3.9.5"
)

enablePlugins(JavaAppPackaging)
enablePlugins(DockerPlugin)

dockerBaseImage := "eclipse-temurin:17-jre"
