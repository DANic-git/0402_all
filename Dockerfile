# Start by building the application.
FROM maven:3-eclipse-temurin-17 as build
ENV JDBC_URL=jdbc:postgresql://host.docker.internal:5432/db?user=app&password=pass
WORKDIR /app

COPY  pom.xml pom.xml
RUN mvn dependency:resolve

COPY src ./src
RUN mvn verify

FROM eclipse-temurin:17 as final
ENV JDBC_URL=jdbc:postgresql://host.docker.internal:5432/db?user=app&password=pass
WORKDIR /app
COPY --from=build /app/target/app.jar /app/app.jar
EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]
HEALTHCHECK --interval=5m --timeout=3s \
  CMD curl -f localhost:8080/actuator/health || exit 1