package org.example.springboot.item;

import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api")
@RequiredArgsConstructor
public class ItemController {
  private final ItemService service;

  @GetMapping("/items")
  public List<Item> getAll() {
    return service.getAll();
  }
}
