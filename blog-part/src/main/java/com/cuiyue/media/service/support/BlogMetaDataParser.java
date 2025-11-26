package com.cuiyue.media.service.support;

import com.cuiyue.media.exception.BlogMetaDataParseException;
import com.cuiyue.media.pojo.BlogMetaData;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.DateTimeException;
import java.time.LocalDate;

public class BlogMetaDataParser {
    private static final Logger log = LoggerFactory.getLogger(BlogMetaDataParser.class);

    public BlogMetaData parseBlogMetaData(Path blogDir) {
        String folderName = blogDir.getFileName().toString();
        String[] parts = folderName.split("-", 4); //  [2025-9-7-my-first-blog] --> [2025, 9, 7, my-first-blog]
        if (parts.length < 4) {
            log.warn("Invalid blog folder name format: {}", folderName);
            return null;
        }

        try {
            LocalDate date = LocalDate.of(Integer.parseInt(parts[0]), Integer.parseInt(parts[1]), Integer.parseInt(parts[2]));
            String title = parts[3].replace("-", " ");

            Path blogPath = blogDir.resolve("index.md");
            if (!Files.exists(blogPath)) {
                log.error("blog file not exists: {}", blogPath);
                return null;
            }
            File blogFile = new File(blogPath.toString());
            String content = Files.readString(blogFile.toPath());
            return new BlogMetaData(folderName, title, date, content);
        } catch (DateTimeException e) {
            log.error("Illegal folderName: {}. should be year-month-day-title", folderName);
            throw new BlogMetaDataParseException("Illegal folderName: {}" + folderName);
        } catch (IOException e) {
            log.error("Failed to read blog:{}", blogDir.resolve("index.md"));
            throw new BlogMetaDataParseException("Failed to read blog from " + folderName);
        }
    }
}
