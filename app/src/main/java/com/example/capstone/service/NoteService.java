package com.example.capstone.service;

import com.example.capstone.config.RabbitConfig;
import com.example.capstone.model.Note;
import com.example.capstone.repository.NoteRepository;
import net.spy.memcached.MemcachedClient;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.stereotype.Service;

import java.util.concurrent.atomic.AtomicLong;

/**
 * Exercises all three backing services on a single write:
 *   1. persists the Note to PostgreSQL,
 *   2. publishes an event to RabbitMQ,
 *   3. bumps a counter in Memcached.
 * And a read path that is served from Memcached when warm.
 */
@Service
public class NoteService {

    private final NoteRepository repository;
    private final RabbitTemplate rabbitTemplate;
    private final MemcachedClient memcached;

    private static final String COUNT_KEY = "note.count";
    private static final int TTL_SECONDS = 3600;

    public NoteService(NoteRepository repository,
                       RabbitTemplate rabbitTemplate,
                       MemcachedClient memcached) {
        this.repository = repository;
        this.rabbitTemplate = rabbitTemplate;
        this.memcached = memcached;
    }

    public Note create(String content) {
        Note saved = repository.save(new Note(content));           // PostgreSQL
        rabbitTemplate.convertAndSend(RabbitConfig.QUEUE_NAME,      // RabbitMQ
                "created:" + saved.getId());
        memcached.delete(COUNT_KEY);   // invalidate cached count
        return saved;
    }

    /** Read the count; serve from Memcached when present, else hit the DB. */
    public CountResult count() {
        Object cached = memcached.get(COUNT_KEY);
        if (cached != null) {
            return new CountResult(Long.parseLong(cached.toString()), true);
        }
        long fromDb = repository.count();                          // PostgreSQL
        memcached.set(COUNT_KEY, TTL_SECONDS, Long.toString(fromDb));
        return new CountResult(fromDb, false);
    }

    /** Small DTO carrying the value plus whether it came from cache. */
    public record CountResult(long value, boolean fromCache) {
    }
}
