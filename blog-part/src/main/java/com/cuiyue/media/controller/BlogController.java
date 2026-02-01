package com.cuiyue.media.controller;

import com.cuiyue.media.pojo.BlogMetaData;
import com.cuiyue.media.pojo.MenuObj;
import com.cuiyue.media.service.impl.BlogServiceImpl;
import com.cuiyue.media.service.IndexService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;

import java.util.List;

@Controller
@RequestMapping("/blogs")
public class BlogController {
    @Autowired
    private BlogServiceImpl blogServiceImpl;

    @Autowired
    private IndexService indexService;

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

    @GetMapping("/{id}")
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
}
