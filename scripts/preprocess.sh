#!/bin/bash
# preprocess.sh - 自动扫描 novels/ 下所有小说，提取正文，生成 mdBook 所需的 src/ 目录
# 支持多本小说：novels/ 下每个子目录视为一本独立的小说
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
NOVELS_DIR="$PROJECT_DIR/novels"
SRC_DIR="$PROJECT_DIR/src"

# 清理并重建 src 目录
rm -rf "$SRC_DIR"
mkdir -p "$SRC_DIR"

# 收集所有小说目录
novel_count=0
novel_list=""

for novel_dir in "$NOVELS_DIR"/*/; do
    [ -d "$novel_dir" ] || continue
    novel_name=$(basename "$novel_dir")

    # 检查是否有章节文件
    has_chapters=false
    for f in "$novel_dir"/第*章-*.md; do
        [ -f "$f" ] && has_chapters=true && break
    done
    $has_chapters || continue

    novel_count=$((novel_count + 1))

    # 从大纲文件提取简介（如果有）
    description=""
    if [ -f "$novel_dir/00-大纲.md" ]; then
        # 提取 "基本信息" 段落中的题材描述
        description=$(awk '/^- \*\*题材\*\*/{gsub(/^- \*\*题材\*\*：/, ""); print; exit}' "$novel_dir/00-大纲.md")
    fi

    # 创建小说子目录
    novel_slug="novel-${novel_count}"
    mkdir -p "$SRC_DIR/$novel_slug"

    # 生成小说首页
    {
        echo "# ${novel_name}"
        echo ""
        if [ -n "$description" ]; then
            echo "> ${description}"
            echo ""
        fi
        echo "---"
        echo ""
        echo "*请从左侧目录选择章节开始阅读。*"
    } > "$SRC_DIR/$novel_slug/index.md"

    # 处理章节文件
    chapter_count=0
    for file in "$novel_dir"/第*章-*.md; do
        [ -f "$file" ] || continue

        filename=$(basename "$file")
        chapter_count=$((chapter_count + 1))

        # 从文件名提取章节编号
        chapter_num=$(echo "$filename" | sed -n 's/第\([0-9]*\)章-.*/\1/p')

        # 从文件第一行提取完整标题
        full_title=$(head -n 1 "$file" | sed 's/^# *//')

        # 目标文件名
        target_file="chapter-${chapter_num}.md"

        # 提取正文内容（## 正文 之后的所有内容）
        {
            echo "# ${full_title}"
            echo ""
            awk '/^## 正文/{found=1; next} found{print}' "$file"
        } > "$SRC_DIR/$novel_slug/$target_file"
    done

    # 记录小说信息供 SUMMARY 使用
    novel_list="${novel_list}${novel_slug}|${novel_name}|${chapter_count}\n"

    echo "  [${novel_name}] 处理完成：${chapter_count} 个章节"
done

# 生成首页 README.md
{
    echo "# 小说书架"
    echo ""
    echo "欢迎来到我的小说书架！以下是所有作品："
    echo ""
    echo "| 小说 | 章节数 |"
    echo "|------|--------|"

    echo -e "$novel_list" | while IFS='|' read -r slug name chapters; do
        [ -z "$slug" ] && continue
        echo "| [${name}](${slug}/index.md) | ${chapters} 章 |"
    done

    echo ""
    echo "---"
    echo "*从左侧目录或上方表格选择小说开始阅读。*"
} > "$SRC_DIR/README.md"

# 生成 SUMMARY.md
{
    echo "# 目录"
    echo ""
    echo "[书架首页](README.md)"
    echo ""
    echo "---"
    echo ""

    echo -e "$novel_list" | while IFS='|' read -r slug name chapters; do
        [ -z "$slug" ] && continue
        echo "# ${name}"
        echo ""
        echo "- [简介](${slug}/index.md)"

        # 列出该小说的所有章节
        for chapter_file in "$SRC_DIR/$slug"/chapter-*.md; do
            [ -f "$chapter_file" ] || continue
            chapter_basename=$(basename "$chapter_file")
            chapter_title=$(head -n 1 "$chapter_file" | sed 's/^# *//')
            echo "  - [${chapter_title}](${slug}/${chapter_basename})"
        done
        echo ""
    done
} > "$SRC_DIR/SUMMARY.md"

echo "预处理完成：共处理 ${novel_count} 本小说"
