package com.example.capstone;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.builder.SpringApplicationBuilder;
import org.springframework.boot.web.servlet.support.SpringBootServletInitializer;

/**
 * Entry point. Extends SpringBootServletInitializer so the app can be
 * deployed as a WAR onto an external Tomcat (as well as run standalone).
 */
@SpringBootApplication
public class CapstoneApplication extends SpringBootServletInitializer {

    @Override
    protected SpringApplicationBuilder configure(SpringApplicationBuilder builder) {
        return builder.sources(CapstoneApplication.class);
    }

    public static void main(String[] args) {
        SpringApplication.run(CapstoneApplication.class, args);
    }
}
