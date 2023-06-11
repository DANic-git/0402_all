package org.example.springboot;

import org.example.springboot.item.Item;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.http.HttpMethod;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.jdbc.JdbcTestUtils;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class SpringbootApplicationTests {
  @Autowired
  TestRestTemplate restTemplate;

  @Autowired
  JdbcTemplate jdbcTemplate;

  @Test
  void shouldGetAll() {
    // Just simple test emulation
    // DON'T USE AS REFERENCE!

    final int expected = JdbcTestUtils.countRowsInTable(jdbcTemplate, "items");

    final List<Item> items = restTemplate.exchange("/api/items", HttpMethod.GET, null, new ParameterizedTypeReference<List<Item>>() {
    }).getBody();
    final int actual = items.size();

    assertEquals(expected, actual);
  }
}
