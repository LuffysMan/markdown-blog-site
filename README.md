markdown 博客网站.  支持将本地 markdown 文档展示到网页. 

## 编译要求
- JDK21

## 博客目录组织要求
1. 要求每一篇 markdown 文档都放到名称格式为 "年-月-日-博客名称" 的目录下
2. 要求每一篇 markdown 文档名称都是 index.md
3. 要求每一篇 markdown 文档引用的本地图片都跟自身在同一个目录下
```
├─blogs
│  ├─2025-9-17-for-test
│  │      image.png
│  │      index.md
│  │
│  └─2025-9-20-eat-better
│          index.md
```

## 启动方法
```bash
export BLOG_BASE_DIR="/path/to/blogs"
export LOG_FILE_PATH="/path/to/logs"
java -jar blog-part-1.0-SNAPSHOT.jar
```