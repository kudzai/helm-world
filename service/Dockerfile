FROM sbtscala/scala-sbt:eclipse-temurin-17.0.4_1.7.1_3.2.0 AS builder
WORKDIR /app
COPY . .
RUN sbt stage

FROM eclipse-temurin:17-jre
WORKDIR /app
COPY --from=builder /app/target/universal/stage/ .
RUN chmod +x /app/bin/api-service
RUN ls -al /app/bin
CMD ["bin/api-service"]
