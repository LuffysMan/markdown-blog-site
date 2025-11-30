package com.cuiyue.media.service;

import com.cuiyue.media.pojo.BlogMetaData;
import com.cuiyue.media.service.impl.BlogServiceImpl;
import com.cuiyue.media.service.support.BlogFileSystemReader;
import com.cuiyue.media.service.support.BlogMetaDataParser;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.LocalDate;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class BlogServiceImplTest {
    private static final String blogDirStub = "/path/to/blogs";

    @Mock
    private BlogFileSystemReader blogFileSystemReader;

    @Mock
    private BlogMetaDataParser blogMetaDataParser;

    @InjectMocks
    private BlogServiceImpl blogServiceImpl;


    @Test
    void shouldGetBlogByName() {
        // arrange
        String blogTile1 = "blog-1";
        String blogId1 = "2025-9-17-" + blogTile1;
        LocalDate blogDate1 = LocalDate.of(2025, 9, 17);
        String blogContent1 = "content1";

        Path blogDir1 = Paths.get(blogDirStub, blogId1);
        BlogMetaData blogMetaData1 = new BlogMetaData(blogId1, blogTile1, blogDate1, blogContent1);
        when(blogFileSystemReader.getBlogDirectoryByName(blogId1)).thenReturn(blogDir1);
        when(blogMetaDataParser.parseBlogMetaData(blogDir1)).thenReturn(blogMetaData1);

        // act
        BlogMetaData blogMetaData = blogServiceImpl.getBlogByName(blogId1);

        // assert
        assertThat(blogMetaData).isEqualTo(blogMetaData1);
    }

    @Test
    void shouldReturnNullWhenGetBlogByNameGivenNonExistBlogID() {
        // act
        BlogMetaData blogMetaData = blogServiceImpl.getBlogByName("non-exist-blog-id");

        // assert
        assertThat(blogMetaData).isNull();
    }

    @Test
    void shouldGetAllBlogs() {
        // arrange
        String blogTile1 = "blog-1";
        String blogTile2 = "blog-2";
        String blogId1 = "2025-9-17-" + blogTile1;
        String blogId2 = "2025-9-18-" + blogTile1;
        LocalDate blogDate1 = LocalDate.of(2025, 9, 17);
        LocalDate blogDate2 = LocalDate.of(2025, 9, 18);
        String blogContent1 = "content1";
        String blogContent2 = "content2";

        Path blogDir1 = Paths.get(blogDirStub, blogId1);
        Path blogDir2 = Paths.get(blogDirStub, blogId2);
        BlogMetaData blogMetaData1 = new BlogMetaData(blogId1, blogTile1, blogDate1, blogContent1);
        BlogMetaData blogMetaData2 = new BlogMetaData(blogId2, blogTile2, blogDate2, blogContent2);
        when(blogFileSystemReader.getAllBlogDirectories()).thenReturn(List.of(blogDir1, blogDir2));
        when(blogMetaDataParser.parseBlogMetaData(blogDir1)).thenReturn(blogMetaData1);
        when(blogMetaDataParser.parseBlogMetaData(blogDir2)).thenReturn(blogMetaData2);

        // act
        List<BlogMetaData> blogs = blogServiceImpl.getAllBlogs();

        // assert
        assertThat(blogs).hasSize(2);
        assertThat(blogs).containsExactly(blogMetaData2, blogMetaData1);
    }

    @Test
    void shouldGetLatestBlogs() {
        // arrange
        String blogTile1 = "blog-1";
        String blogTile2 = "blog-2";
        String blogId1 = "2025-9-17-" + blogTile1;
        String blogId2 = "2025-9-18-" + blogTile1;
        LocalDate blogDate1 = LocalDate.of(2025, 9, 17);
        LocalDate blogDate2 = LocalDate.of(2025, 9, 18);
        String blogContent1 = "content1";
        String blogContent2 = "content2";

        Path blogDir1 = Paths.get(blogDirStub, blogId1);
        Path blogDir2 = Paths.get(blogDirStub, blogId2);
        BlogMetaData blogMetaData1 = new BlogMetaData(blogId1, blogTile1, blogDate1, blogContent1);
        BlogMetaData blogMetaData2 = new BlogMetaData(blogId2, blogTile2, blogDate2, blogContent2);
        when(blogFileSystemReader.getAllBlogDirectories()).thenReturn(List.of(blogDir1, blogDir2));
        when(blogMetaDataParser.parseBlogMetaData(blogDir1)).thenReturn(blogMetaData1);
        when(blogMetaDataParser.parseBlogMetaData(blogDir2)).thenReturn(blogMetaData2);

        // act
        List<BlogMetaData> blogs = blogServiceImpl.getLatestBlogs(1);

        // assert
        assertThat(blogs).hasSize(1);
        assertThat(blogs).containsExactly(blogMetaData2);
    }
}