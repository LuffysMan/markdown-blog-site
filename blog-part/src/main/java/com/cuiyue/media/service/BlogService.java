package com.cuiyue.media.service;

import com.cuiyue.media.pojo.BlogMetadata;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.Resource;
import org.springframework.core.io.support.PathMatchingResourcePatternResolver;
import org.springframework.stereotype.Service;

import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardOpenOption;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Objects;
import java.util.stream.Collectors;

@Service
public class BlogService {

    private static final Logger log = LoggerFactory.getLogger(BlogService.class);
    @Value("${blogs.baseDir}")
    private String baseDirectory;

    public List<BlogMetadata> getAllBlogs() throws IOException {
        Path blogsPath = Paths.get(baseDirectory);
        if (!Files.exists(blogsPath)) {
            Files.createDirectories(blogsPath);
            return new ArrayList<>();
        }

        List<BlogMetadata> blogs = new ArrayList<>();
        try {

            blogs = Files.list(blogsPath)
                    .filter(Files::isDirectory)
                    .map(this::parseBlogMetadata)
                    .filter(Objects::nonNull)
                    .sorted((b1, b2) -> b2.getDate().compareTo(b1.getDate()))
                    .collect(Collectors.toList());
        } catch (IOException e) {
            log.info("empty posts");
        }

        PathMatchingResourcePatternResolver resolver = new PathMatchingResourcePatternResolver();
        // 按日期倒序排列（最新的在前）
        blogs.sort(Comparator.comparing(BlogMetadata::getDate).reversed());

        return blogs;
    }

    public BlogMetadata getBlog(String dirName) throws IOException {
        Path blogDir = Paths.get(baseDirectory, dirName);
        if (!Files.exists(blogDir)) {
            throw new FileNotFoundException("File not found: " + dirName);
        }
        return parseBlogMetadata(blogDir);
    }

    private BlogMetadata parseBlogMetadata(Path blogDir) {
        String dirName = blogDir.getFileName().toString();
        // 解析日期 + 标题
        String[] parts = dirName.split("-", 4); // [2025, 9, 7, my-first-blog]
        LocalDate date = LocalDate.of(
                Integer.parseInt(parts[0]),
                Integer.parseInt(parts[1]),
                Integer.parseInt(parts[2])
        );
        String title = parts[3].replace("-", " ");

        Path blogPath = blogDir.resolve("index.md");
        if (!Files.exists(blogPath)) {
            return null;
        }
        File blogFile = new File(blogPath.toString());

        try {
            // 使用 Files.readString() 读取文件内容并保存到字符串
            String content = Files.readString(blogFile.toPath());
            return new BlogMetadata(dirName, title, date, content);
        } catch (IOException e) {
            e.printStackTrace();
        }
        return null;
    }

    public void saveBlog(String fileName, String fileContent) throws IOException {
        Path filePath = getSafePath(fileName);
        Files.createDirectories(filePath.getParent());
        Files.writeString(filePath, fileContent, StandardOpenOption.CREATE, StandardOpenOption.TRUNCATE_EXISTING);

    }

    private Path getSafePath(String filename) {
        String safeFilename = filename.replaceAll("[^a-zA-Z0-9._-]", "_");
        String workDir = System.getProperty("user.dir");
        System.out.println(workDir);
        return Paths.get(workDir, safeFilename);
    }

    public List<BlogMetadata> getLatestBlogs(int count) throws IOException {
        // 遍历静态目录下 blogs 目录, 枚举所有目录名, 保存到列表并返回
        List<BlogMetadata> allBlogs = getAllBlogs();
        return allBlogs.stream().limit(count).collect(Collectors.toList());
    }
}
