package com.cuiyue.media.service.support;

import com.cuiyue.media.exception.BlogFileIOException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;
import java.util.stream.Stream;

@Component
public class BlogFileSystemReader {
    @Value("${blogs.baseDir}")
    private String baseDirectory;

    private static final Logger log = LoggerFactory.getLogger(BlogFileSystemReader.class);

    public List<Path> getAllBlogDirectories() {
        Path baseDir = Paths.get(baseDirectory);
        try (Stream<Path> paths = Files.list(baseDir)) {
            return paths.filter(Files::isDirectory).toList();
        } catch (IOException e) {
            log.error("list blogs.baseDir failed.");
        }
        return new ArrayList<>();
    }

    public Path getBlogDirectoryByName(String blogName) {
        Path blogDir = Paths.get(baseDirectory, blogName);
        if (!Files.isDirectory(blogDir)) {
            log.error("blog dir not exists: {}", blogDir);
            return null;
        }
        return blogDir;
    }
}
