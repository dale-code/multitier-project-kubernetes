# Multi-stage build for the Java app.
# Stage 1 builds the WAR with Maven; stage 2 runs it on Tomcat.
# The final image contains only Tomcat + the WAR — no Maven, no JDK build layers.

# --- Stage 1: build the .war with Maven ----------------------------
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /src
# Copy the POM first and build with dependency caching.
# This layer is cached and only re-runs when pom.xml or src changes.
COPY pom.xml .
COPY src ./src
RUN mvn -q clean package -DskipTests

# --- Stage 2: run on Tomcat ----------------------------------------
FROM tomcat:10.1-jdk17-temurin
# Remove Tomcat's bundled sample apps.
RUN rm -rf /usr/local/tomcat/webapps/*
# Deploy our WAR as ROOT so it serves at "/" (not "/capstone").
COPY --from=build /src/target/capstone.war /usr/local/tomcat/webapps/ROOT.war
EXPOSE 8080
# The tomcat base image already starts Tomcat in the foreground.
    `           ``  
    `a