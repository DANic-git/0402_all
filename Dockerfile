# Start by building the application.
FROM bitnami/java:17 as build
ENV JDBC_URL=jdbc:postgresql://host.docker.internal:5432/db?user=app&password=pass
ENV HOME=/usr/app
RUN mkdir -p $HOME
WORKDIR $HOME
COPY pom.xml pom.xml
COPY mvnw mvnw
COPY .mvn .mvn
RUN --mount=type=cache,target=/root/.m2 ./mvnw -ntp -B -pl . -am dependency:go-offline
COPY src src
RUN --mount=type=cache,target=/root/.m2 ./mvnw verify


FROM bitnami/java:17 as final
ENV JDBC_URL=jdbc:postgresql://host.docker.internal:5432/db?user=app&password=pass
WORKDIR /app
COPY --from=build /usr/app/target/app.jar /app/app.jar
EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]
HEALTHCHECK --interval=5m --timeout=3s \
  CMD curl -f localhost:8080/actuator/health || exit 1