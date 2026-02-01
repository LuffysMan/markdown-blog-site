package com.cuiyue.media.service;

import com.cuiyue.media.pojo.MenuObj;
import org.springframework.stereotype.Service;

import java.util.Arrays;
import java.util.List;

@Service
public class IndexService {

    public List<MenuObj> getMenuItems() {
        return Arrays.asList(
                new MenuObj("首页", "/home"),
                new MenuObj("博客", "/blogs")
        );
    }
}
