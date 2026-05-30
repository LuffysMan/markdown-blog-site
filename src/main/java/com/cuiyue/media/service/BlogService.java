package com.cuiyue.media.service;

import com.cuiyue.media.pojo.BlogMetaData;

import java.io.IOException;
import java.util.List;

public interface BlogService {
    public List<BlogMetaData> getAllBlogs() throws IOException;

    public BlogMetaData getBlogByName(String blogName) throws IOException;
}
