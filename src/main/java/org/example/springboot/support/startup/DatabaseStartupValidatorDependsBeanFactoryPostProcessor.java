package org.example.springboot.support.startup;

import org.springframework.beans.BeansException;
import org.springframework.beans.factory.config.BeanFactoryPostProcessor;
import org.springframework.beans.factory.config.ConfigurableListableBeanFactory;
import org.springframework.jdbc.core.JdbcOperations;
import org.springframework.jdbc.support.DatabaseStartupValidator;
import org.springframework.stereotype.Component;

@Component
public class DatabaseStartupValidatorDependsBeanFactoryPostProcessor implements BeanFactoryPostProcessor {
  @Override
  public void postProcessBeanFactory(final ConfigurableListableBeanFactory factory) throws BeansException {
    final String[] startups = factory.getBeanNamesForType(DatabaseStartupValidator.class);
    if (startups.length == 0) {
      return;
    }

    for (final String name : factory.getBeanNamesForType(JdbcOperations.class)) {
      factory.getBeanDefinition(name).setDependsOn(startups);
    }
  }
}
