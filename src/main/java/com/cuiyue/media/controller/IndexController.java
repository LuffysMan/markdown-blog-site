package com.cuiyue.media.controller;

import com.cuiyue.media.pojo.BlogMetaData;
import com.cuiyue.media.pojo.MenuObj;
import com.cuiyue.media.service.impl.BlogServiceImpl;
import com.cuiyue.media.service.IndexService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;

import java.util.List;

@Controller
@RequestMapping("/")
public class IndexController {
    @Autowired
    private BlogServiceImpl blogServiceImpl;

    @Autowired
    private IndexService indexService;

    @GetMapping("/")
    public String redirectToHome() {
        return "redirect:/home";
    }

    @GetMapping("/home")
    public String homePage(Model model) {
        List<MenuObj> menuItems = indexService.getMenuItems();
        model.addAttribute("menuItems", menuItems);

        List<BlogMetaData> latestBlogs = null;
        latestBlogs = blogServiceImpl.getLatestBlogs(10);
        model.addAttribute("latestBlogs", latestBlogs);
        return "index";
    }
}
