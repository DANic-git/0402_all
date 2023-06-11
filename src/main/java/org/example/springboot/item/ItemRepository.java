package org.example.springboot.item;

import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcOperations;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
@RequiredArgsConstructor
public class ItemRepository {
  private final NamedParameterJdbcOperations jdbcOperations;
  private RowMapper<Item> rowMapper = (rs, i) -> new Item(rs.getLong("id"), rs.getString("name"));

  public List<Item> getAll() {
    return jdbcOperations.query(
        // language=PostgreSQL
        """
        SELECT "items"."id", "items"."name"
        FROM "items"
        ORDER BY "id"
        LIMIT 100
        """,
        rowMapper
    );
  }
}
