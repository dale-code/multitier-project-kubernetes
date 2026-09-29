package com.example.capstone.controller;

import com.example.capstone.model.Note;
import com.example.capstone.service.NoteService;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Minimal API to demonstrate the full stack:
 *   GET  /            -> friendly landing text
 *   POST /notes       -> writes to DB + queue + invalidates cache
 *   GET  /notes/count -> read, served from cache when warm
 */
@RestController
public class NoteController {

    private final NoteService service;

    public NoteController(NoteService service) {
        this.service = service;
    }

    @GetMapping("/")
    public String home() {
        return "Multi-tier capstone app is running. "
                + "POST /notes {\"content\":\"...\"} then GET /notes/count";
    }

    @PostMapping("/notes")
    public Note create(@RequestBody Map<String, String> body) {
        return service.create(body.getOrDefault("content", ""));
    }

    @GetMapping("/notes/count")
    public Map<String, Object> count() {
        NoteService.CountResult result = service.count();
        Map<String, Object> response = new HashMap<>();
        response.put("count", result.value());
        response.put("served_from_cache", result.fromCache());
        return response;
    }
}
