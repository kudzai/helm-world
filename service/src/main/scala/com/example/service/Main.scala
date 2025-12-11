package com.example.service

import akka.actor.typed.ActorSystem
import akka.actor.typed.scaladsl.Behaviors
import akka.http.scaladsl.Http
import akka.http.scaladsl.model._
import akka.http.scaladsl.server.Directives._
import akka.http.scaladsl.server.Route
import scala.concurrent.ExecutionContext
import scala.util.{Failure, Success}
import com.typesafe.scalalogging.LazyLogging
import pureconfig._
import pureconfig.generic.auto._
import java.nio.file.Paths
import com.example.service.config.AppConfig

object Main extends LazyLogging {
  def main(args: Array[String]): Unit = {
    logger.info("Starting API Service...")

    val configPath = Paths.get("/etc/config/app/application.conf")
    val configSource = ConfigSource.file(configPath)
    // Fallback to classpath
    val finalSource = configSource.optional.withFallback(ConfigSource.default)

    // We try/catch here to log a nice error if config is invalid, or just let it crash
    val appConfig = finalSource.load[AppConfig] match {
      case Right(conf) =>
        logger.info(s"Loaded Configuration: $conf")
        conf
      case Left(errors) =>
        logger.error(s"Failed to load configuration: $errors")
        sys.exit(1)
    }

    implicit val system = ActorSystem(Behaviors.empty, "api-service")
    implicit val ec: ExecutionContext = system.executionContext

    val sparkMasterUrl =
      sys.env.getOrElse("SPARK_MASTER_URL", "spark://localhost:7077")
    val jobSubmitter = new SparkJobSubmitter(sparkMasterUrl)

    val route: Route =
      path("api" / "v1" / "jobs" / "submit") {
        post {
          // OAuth extraction: In OpenShift with sidecar, the user info is often in headers.
          // For now we just log the headers to show authentication happening.
          headerValueByName("X-Forwarded-User") { user =>
            logger.info(s"Request from user: $user")
            val submissionFuture = jobSubmitter.submitJob()
            onComplete(submissionFuture) {
              case Success(msg) => complete(StatusCodes.OK, msg)
              case Failure(ex)  =>
                logger.error(s"Job submission failed: ${ex.getMessage}")
                complete(
                  StatusCodes.InternalServerError,
                  s"Failed to submit job: ${ex.getMessage}"
                )
            }
          } ~
            // Fallback if header is missing (e.g. testing locally w/o oauth proxy)
            {
              logger.warn("Warning: X-Forwarded-User header missing")
              val submissionFuture = jobSubmitter.submitJob()
              onComplete(submissionFuture) {
                case Success(msg) => complete(StatusCodes.OK, msg)
                case Failure(ex)  =>
                  complete(StatusCodes.InternalServerError, ex.getMessage)
              }
            }
        }
      } ~
        path("info") {
          get {
            complete(StatusCodes.OK, "Service: api-service, Version: 0.1")
          }
        }

    val bindingFuture = Http().newServerAt("0.0.0.0", 8080).bind(route)
    logger.info(s"Server online at http://0.0.0.0:8080/")
  }
}
