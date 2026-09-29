package com.example.capstone.config;

import net.spy.memcached.MemcachedClient;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.io.IOException;
import java.net.InetSocketAddress;

/** Wires a single MemcachedClient bean from configurable host/port. */
@Configuration
public class MemcachedConfig {

    @Value("${cache.host:localhost}")
    private String cacheHost;

    @Value("${cache.port:11211}")
    private int cachePort;

    @Bean(destroyMethod = "shutdown")
    public MemcachedClient memcachedClient() throws IOException {
        return new MemcachedClient(new InetSocketAddress(cacheHost, cachePort));
    }
}
