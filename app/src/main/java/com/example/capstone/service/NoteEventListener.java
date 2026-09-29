package com.example.capstone.service;

import com.example.capstone.config.RabbitConfig;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Component;

/** Consumes the queue so RabbitMQ is exercised end-to-end, not just written to. */
@Component
public class NoteEventListener {

    @RabbitListener(queues = RabbitConfig.QUEUE_NAME)
    public void handle(String message) {
        System.out.println("[rabbitmq] received event: " + message);
    }
}
