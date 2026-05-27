document.addEventListener('DOMContentLoaded', function() {
    const markdownContent = document.getElementById('markdown-content');
    if (markdownContent) {
        const html = marked.parse(markdownContent.textContent);
        markdownContent.innerHTML = html;
    }

    document.getElementById('addBlogBtn').addEventListener('click', function() {
        var article = document.querySelector('.blog-content article');
        var noBlog = document.querySelector('.no-blog');
        if (article) article.style.display = 'none';
        if (noBlog) noBlog.style.display = 'none';
        document.getElementById('upload-panel').style.display = 'block';
        var d = new Date();
        document.getElementById('targetDir').value = d.getFullYear() + '-' + (d.getMonth() + 1) + '-' + d.getDate();
    });

    document.getElementById('cancelUpload').addEventListener('click', function() {
        document.getElementById('upload-panel').style.display = 'none';
        var article = document.querySelector('.blog-content article');
        var noBlog = document.querySelector('.no-blog');
        if (article) article.style.display = '';
        if (noBlog) noBlog.style.display = '';
    });

    document.getElementById('newBlogForm').addEventListener('submit', function(e) {
        e.preventDefault();
        var msgEl = document.getElementById('upload-message');
        var formData = new FormData(e.target);

        fetch('/blogs/upload', { method: 'POST', body: formData })
            .then(function(r) { return r.json(); })
            .then(function(data) {
                if (data.success) {
                    msgEl.textContent = '上传成功！即将跳转...';
                    msgEl.className = 'upload-message success';
                    msgEl.style.display = 'block';
                    setTimeout(function() {
                        window.location.href = '/blogs/' + data.blogId + '/';
                    }, 800);
                } else {
                    msgEl.textContent = '上传失败: ' + data.error;
                    msgEl.className = 'upload-message error';
                    msgEl.style.display = 'block';
                }
            })
            .catch(function(err) {
                msgEl.textContent = '请求失败: ' + err.message;
                msgEl.className = 'upload-message error';
                msgEl.style.display = 'block';
            });
    });
});
