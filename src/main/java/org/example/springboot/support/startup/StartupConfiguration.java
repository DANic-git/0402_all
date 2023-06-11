package org.example.springboot.support.startup;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.jdbc.support.DatabaseStartupValidator;

import javax.sql.DataSource;

@Configuration(proxyBeanMethods = false)
public class StartupConfiguration {
  @Bean
  public DatabaseStartupValidator databaseStartupValidator(final DataSource dataSource) {
    final DatabaseStartupValidator bean = new DatabaseStartupValidator();
    bean.setDataSource(dataSource);
    return bean;
  }
}
