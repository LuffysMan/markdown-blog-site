package com.cuiyue.media.pojo;

import java.time.LocalDate;

public class BlogMetaData {
    private String id;      // 例如 "2025-9-7-my-first-blog"
    private String title;   // my first blog
    private LocalDate date; // 2025-09-07
    private String content; // index.md 内容

    public BlogMetaData() {
        this.id = "";
        this.title = "no blog";
        this.date = LocalDate.now();
        this.content = "# no content";
    }

    public BlogMetaData(String id, String title, LocalDate date, String content) {
        this.id = id;
        this.title = title;
        this.date = date;
        this.content = content;
    }

    // getters / setters

    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public String getTitle() {
        return title;
    }

    public void setTitle(String title) {
        this.title = title;
    }

    public LocalDate getDate() {
        return date;
    }

    public void setDate(LocalDate date) {
        this.date = date;
    }

    public String getContent() {
        return content;
    }

    public void setContent(String content) {
        this.content = content;
    }
}