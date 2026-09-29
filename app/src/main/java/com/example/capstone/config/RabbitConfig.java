package com.example.capstone.config;

import org.springframework.amqp.core.Queue;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/** Declares the queue the app publishes to. Spring Boot autoconfigures
 *  the connection from spring.rabbitmq.* properties. */
@Configuration
public class RabbitConfig {

    public static final String QUEUE_NAME = "note.events";

    @Bean
    public Queue noteEventsQueue() {
        return new Queue(QUEUE_NAME, true);
    }
}
