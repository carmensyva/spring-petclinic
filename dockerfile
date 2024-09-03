FROM registry.access.redhat.com/ubi8/openjdk-17:latest
WORKDIR /app
COPY ./target/*.jar ./app.jar

ENV TZ="Asia/Jakarta"
RUN date

EXPOSE 8080
CMD ["java", "-Xms256m", "-Xmx512m", "-jar", "-Dspring.profiles.active=postgres", "-Dserver.port=8080", "/app/app.jar", "--server.servlet.context-path=/"]
