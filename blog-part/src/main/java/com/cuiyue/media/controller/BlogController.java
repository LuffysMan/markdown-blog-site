package com.cuiyue.media.controller;

import com.cuiyue.media.pojo.BlogMetaData;
import com.cuiyue.media.pojo.MenuObj;
import com.cuiyue.media.service.impl.BlogServiceImpl;
import com.cuiyue.media.service.IndexService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.util.List;
import java.util.regex.Pattern;

@Controller
@RequestMapping("/blogs")
public class BlogController {
    private static final String LOOSE_PATTERN = "^\\d{4}-\\d{2}-\\d{2}-.*$";

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
    public String handleFileUpload(@RequestParam("file") MultipartFile file, RedirectAttributes redirectAttributes) {
        System.out.println("handleFileUpload start");
        // 检查文件是否为空
        if (file.isEmpty()) {
            redirectAttributes.addFlashAttribute("message", "请选择一个文件");
            return "redirect:/blogs";
        }
        try {
            // 构建保存路径
            Path uploadDir = Paths.get(baseDirectory);
            // 如果目录不存在则创建
            if (!Files.exists(uploadDir)) {
                Files.createDirectories(uploadDir);
            }
            // 获取原始文件名
            String originalFilename = file.getOriginalFilename();

            // 防止穿越攻击
            Path targetPath = uploadDir.resolve(originalFilename).normalize();
            if (!targetPath.startsWith(uploadDir)) {
                return "redirect:/blogs";
            }
            // 校验文件名格式是否满足: 年-月-日-标题内容的格式
            Pattern pattern = Pattern.compile(LOOSE_PATTERN);
            if (!pattern.matcher(originalFilename).matches()) {
                System.out.println("Illegal file name. Should be year-month-day-title");
                return "redirect:/blogs";
            }

            // 保存文件
            Files.copy(file.getInputStream(), targetPath, StandardCopyOption.REPLACE_EXISTING);
            redirectAttributes.addFlashAttribute("message", "上传成功: " + originalFilename + "大小: " + file.getSize() + " 字节");
        } catch (IOException e) {
            redirectAttributes.addFlashAttribute("message", "上传失败" + e.getMessage());
        }
        System.out.println("handleFileUpload finish");
        return "redirect:/blogs";
    }
}
