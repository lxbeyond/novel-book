#!/bin/bash
# preprocess.sh - 从小说原始 Markdown 中提取正文，生成 mdBook 所需的 src/ 目录
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
NOVEL_DIR="$PROJECT_DIR/novels/逆天龙帝"
SRC_DIR="$PROJECT_DIR/src"

# 清理并重建 src 目录
rm -rf "$SRC_DIR"
mkdir -p "$SRC_DIR"

# 生成首页 README.md
cat > "$SRC_DIR/README.md" << 'EOF'
# 逆天龙帝

> 苍穹大陆，以宗门为核心，四大宗门争霸天下。
> 废材龙傲天觉醒吞天龙体，逆天崛起，镇压诸天！

---

**修炼体系**：炼气 → 筑基 → 金丹 → 元婴 → 化神 → 渡劫 → 大乘 → 飞升

**势力格局**：天剑宗 · 万兽宗 · 幽冥殿 · 玄天圣地

---

*请从左侧目录选择章节开始阅读。*
EOF

# 开始生成 SUMMARY.md
cat > "$SRC_DIR/SUMMARY.md" << 'EOF'
# 目录

[简介](README.md)

---

EOF

# 处理每个章节文件（按文件名排序）
chapter_count=0
for file in "$NOVEL_DIR"/第*章-*.md; do
    [ -f "$file" ] || continue

    filename=$(basename "$file")
    chapter_count=$((chapter_count + 1))

    # 从文件名提取章节信息：第01章-废物龙傲天.md -> 01, 废物龙傲天
    chapter_num=$(echo "$filename" | sed -n 's/第\([0-9]*\)章-.*/\1/p')
    chapter_title=$(echo "$filename" | sed -n 's/第[0-9]*章-\(.*\)\.md/\1/p')

    # 从文件第一行提取完整标题（如 "# 第01章：废物龙傲天"）
    full_title=$(head -n 1 "$file" | sed 's/^# *//')

    # 目标文件名
    target_file="chapter-${chapter_num}.md"

    # 提取正文内容（## 正文 之后的所有内容）
    {
        echo "# ${full_title}"
        echo ""
        # 使用 awk 提取 "## 正文" 之后的内容（跳过 "## 正文" 行本身）
        awk '/^## 正文/{found=1; next} found{print}' "$file"
    } > "$SRC_DIR/$target_file"

    # 写入 SUMMARY.md 条目
    echo "- [${full_title}](${target_file})" >> "$SRC_DIR/SUMMARY.md"
done

echo "预处理完成：共处理 ${chapter_count} 个章节，输出到 ${SRC_DIR}/"
