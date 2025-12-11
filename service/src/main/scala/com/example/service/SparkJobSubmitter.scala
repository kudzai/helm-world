package com.example.service

import org.apache.spark.launcher.SparkLauncher
import scala.concurrent.{Future, ExecutionContext}
import scala.util.Try

class SparkJobSubmitter(sparkMasterUrl: String)(implicit ec: ExecutionContext) {

  def submitJob(): Future[String] = Future {
    val handle = new SparkLauncher()
      .setAppResource("/opt/bitnami/spark/examples/jars/spark-examples_2.12-3.5.6.jar") // Using the example jar for now as per previous context
      .setMainClass("org.apache.spark.examples.SparkPi")
      .setMaster(sparkMasterUrl)
      .setConf("spark.executor.memory", "512m")
      .setConf("spark.driver.memory", "512m")
      .addAppArgs("1000")
      .startApplication()

    // In a real world scenario we might want to track the handle ID or status
    s"Job submitted with AppId: ${handle.getAppId}"
  }
}
