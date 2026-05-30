package com.cuiyue.media.service.impl;

import com.cuiyue.media.pojo.BlogMetaData;
import com.cuiyue.media.service.BlogService;
import com.cuiyue.media.service.support.BlogFileSystemReader;
import com.cuiyue.media.service.support.BlogMetaDataParser;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.nio.file.Path;
import java.util.Comparator;
import java.util.List;
import java.util.Objects;
import java.util.stream.Collectors;

@Service
public class BlogServiceImpl implements BlogService {
    @Autowired
    private BlogFileSystemReader blogFileSystemReader;

    @Autowired
    private BlogMetaDataParser blogMetaDataParser;

    private static final Logger log = LoggerFactory.getLogger(BlogServiceImpl.class);

    @Override
    public BlogMetaData getBlogByName(String blogName) {
        Path blogDir = blogFileSystemReader.getBlogDirectoryByName(blogName);
        return blogMetaDataParser.parseBlogMetaData(blogDir);
    }

    @Override
    public List<BlogMetaData> getAllBlogs() {
        List<Path> blogDirectories = blogFileSystemReader.getAllBlogDirectories();
        return blogDirectories.stream()
                .map(blogMetaDataParser::parseBlogMetaData)
                .filter(Objects::nonNull)
                .sorted(Comparator.comparing(BlogMetaData::getDate).reversed())
                .collect(Collectors.toList());
    }

    public List<BlogMetaData> getLatestBlogs(int count) {
        List<BlogMetaData> allBlogs = getAllBlogs();
        return allBlogs.stream().limit(count).collect(Collectors.toList());
    }
}
