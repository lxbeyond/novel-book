// 根据当前阅读的小说，自动折叠侧边栏中其他小说的章节列表
(function () {
  function filterSidebar() {
    var path = window.location.pathname;

    // 提取当前所在的 novel-N 目录
    var match = path.match(/novel-(\d+)/);
    var currentNovel = match ? 'novel-' + match[1] : null;

    // 找到所有 part-title（即小说分节标题）
    var parts = document.querySelectorAll('.sidebar .chapter li.part-title');
    if (!parts.length) return;

    parts.forEach(function (partTitle) {
      // 找到该 part 下面的所有章节项（直到下一个 part-title 或列表结束）
      var sibling = partTitle.nextElementSibling;
      var chapterItems = [];
      while (sibling && !sibling.classList.contains('part-title')) {
        chapterItems.push(sibling);
        sibling = sibling.nextElementSibling;
      }

      if (!currentNovel) {
        // 在首页时，折叠所有小说的章节列表，只显示分节标题
        chapterItems.forEach(function (item) {
          item.style.display = 'none';
        });
        return;
      }

      // 检查该 part 的章节链接是否属于当前小说
      var belongsToCurrent = chapterItems.some(function (item) {
        var link = item.querySelector('a');
        return link && link.getAttribute('href') && link.getAttribute('href').indexOf(currentNovel) !== -1;
      });

      if (!belongsToCurrent) {
        // 隐藏不属于当前小说的所有章节
        chapterItems.forEach(function (item) {
          item.style.display = 'none';
        });
      } else {
        // 确保当前小说的章节可见
        chapterItems.forEach(function (item) {
          item.style.display = '';
        });
      }
    });
  }

  // 页面加载时执行
  filterSidebar();

  // mdBook 使用 History API 导航，监听 URL 变化
  var pushState = history.pushState;
  history.pushState = function () {
    pushState.apply(history, arguments);
    setTimeout(filterSidebar, 100);
  };
  window.addEventListener('popstate', function () {
    setTimeout(filterSidebar, 100);
  });
})();
