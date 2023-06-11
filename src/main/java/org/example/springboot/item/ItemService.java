package org.example.springboot.item;

import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@Transactional
@RequiredArgsConstructor
public class ItemService {
  private final ItemRepository repository;

  public List<Item> getAll() {
    return repository.getAll();
  }
}
