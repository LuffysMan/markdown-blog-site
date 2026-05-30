package com.cuiyue.media.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class WebConfig implements WebMvcConfigurer {

    @Value("${blogs.baseDir}")
    private String baseDirectory;

    @Override
    public void addResourceHandlers(ResourceHandlerRegistry registry) {
        if (!baseDirectory.endsWith("/")) {
            baseDirectory += "/";
        }

        registry.addResourceHandler("/blogs/**").addResourceLocations("file:" + baseDirectory);
    }
}