package com.cuiyue.media.controller;

import com.cuiyue.media.pojo.BlogMetadata;
import com.cuiyue.media.pojo.MenuObj;
import com.cuiyue.media.service.BlogService;
import com.cuiyue.media.service.IndexService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;

import java.io.IOException;
import java.util.Arrays;
import java.util.List;

@Controller
@RequestMapping("/blogs")
public class BlogController {
    @Autowired
    private BlogService blogService;

    @Autowired
    private IndexService indexService;

    @GetMapping("")
    public String blogsPage(Model model) {
        List<MenuObj> menuItems = indexService.getMenuItems();

        BlogMetadata selectedBlog = new BlogMetadata();
        List<BlogMetadata> allBlogs = null;
        try {
            allBlogs = blogService.getAllBlogs();
            selectedBlog = allBlogs.isEmpty() ? new BlogMetadata() : allBlogs.getFirst();

        } catch (IOException e) {
            e.printStackTrace();
        }

        model.addAttribute("menuItems", menuItems);
        model.addAttribute("allBlogs", allBlogs);
        model.addAttribute("selectedBlog", selectedBlog);
        return "blogs";
    }

    @GetMapping("/{id}")
    public String getBlog(@PathVariable String id, Model model) {
        List<MenuObj> menuItems = indexService.getMenuItems();

        BlogMetadata blog = null;
        List<BlogMetadata> allBlogs = null;
        try {
            blog = blogService.getBlog(id);
            allBlogs = blogService.getAllBlogs();

        } catch (IOException e) {
            e.printStackTrace();
        }
        model.addAttribute("menuItems", menuItems);
        model.addAttribute("selectedBlog", blog == null ? new BlogMetadata() : blog);
        model.addAttribute("allBlogs", allBlogs);
        return "blogs";
    }
}
