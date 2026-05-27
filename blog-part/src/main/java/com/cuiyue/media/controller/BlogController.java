package com.cuiyue.media.controller;

import com.cuiyue.media.pojo.BlogMetaData;
import com.cuiyue.media.pojo.MenuObj;
import com.cuiyue.media.service.IndexService;
import com.cuiyue.media.service.impl.BlogServiceImpl;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Controller
@RequestMapping("/blogs")
public class BlogController {

    @Autowired
    private BlogServiceImpl blogServiceImpl;

    @Autowired
    private IndexService indexService;

    @Value("${blogs.baseDir}")
    private String baseDirectory;

    @GetMapping("")
    public String showBlogs(Model model) {
        List<MenuObj> menuItems = indexService.getMenuItems();

        List<BlogMetaData> allBlogs = blogServiceImpl.getAllBlogs();
        BlogMetaData selectedBlog = allBlogs.isEmpty() ? new BlogMetaData() : allBlogs.getFirst();

        model.addAttribute("menuItems", menuItems);
        model.addAttribute("allBlogs", allBlogs);
        model.addAttribute("selectedBlog", selectedBlog);
        return "blogs";
    }

    @GetMapping("/{id}/")
    public String showBlog(@PathVariable String id, Model model) {
        List<MenuObj> menuItems = indexService.getMenuItems();

        BlogMetaData blog = null;
        List<BlogMetaData> allBlogs = null;
        blog = blogServiceImpl.getBlogByName(id);
        allBlogs = blogServiceImpl.getAllBlogs();
        model.addAttribute("menuItems", menuItems);
        model.addAttribute("selectedBlog", blog == null ? new BlogMetaData() : blog);
        model.addAttribute("allBlogs", allBlogs);
        return "blogs";
    }

    @PostMapping("/upload")
    @ResponseBody
    public Map<String, Object> handleFileUpload(
            @RequestParam("file") MultipartFile file,
            @RequestParam("targetDir") String targetDir,
            @RequestParam("targetName") String targetName) {

        Map<String, Object> result = new HashMap<>();

        if (file.isEmpty()) {
            result.put("success", false);
            result.put("error", "请选择一个文件");
            return result;
        }

        if (!targetDir.matches("^\\d{4}-\\d{1,2}-\\d{1,2}-.+$")) {
            result.put("success", false);
            result.put("error", "目录名格式错误，应为 YYYY-M-D");
            return result;
        }

        try {
            Path basePath = Paths.get(baseDirectory);
            Path blogDir = basePath.resolve(targetDir).normalize();

            if (!blogDir.startsWith(basePath)) {
                result.put("success", false);
                result.put("error", "非法目录名");
                return result;
            }

            if (!Files.exists(blogDir)) {
                Files.createDirectories(blogDir);
            }

            String filename = "index.md".equals(targetName)
                    ? "index.md"
                    : file.getOriginalFilename();
            Path targetPath = blogDir.resolve(filename).normalize();
            if (!targetPath.startsWith(blogDir)) {
                result.put("success", false);
                result.put("error", "非法文件名");
                return result;
            }

            Files.copy(file.getInputStream(), targetPath, StandardCopyOption.REPLACE_EXISTING);

            result.put("success", true);
            result.put("blogId", targetDir);
        } catch (IOException e) {
            result.put("success", false);
            result.put("error", "上传失败: " + e.getMessage());
        }

        return result;
    }
}
