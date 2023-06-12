# Start by building the application.
FROM maven:3-eclipse-temurin-17 as build
WORKDIR /app

COPY  pom.xml pom.xml
RUN mvn dependency:resolve

COPY src ./src
RUN mvn verify -Dmaven.test.skip

FROM eclipse-temurin:17 as final

ENV JDBC_URL=jdbc:postgresql://localhost:5432/db?user=app&password=pass

RUN apt-get -qqy update \
  && apt-get -qqy --no-install-recommends install \
  supervisor \
  && rm -rf /var/lib/apt/lists/* /var/cache/apt/*


WORKDIR /app

COPY conf/entry_point.sh conf/start-app.sh /opt/bin/
COPY conf/supervisord.conf /etc
COPY conf/app.conf /etc/supervisor/conf.d/
COPY --from=build /app/target/app.jar /app/app.jar

EXPOSE 8080

CMD ["/opt/bin/entry_point.sh"]
# HEALTHCHECK --interval=5m --timeout=3s \
#   CMD curl -f localhost:8080/actuator/health || exit 1