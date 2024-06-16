#!/bin/bash

# 获取参数
branch=$1
dir=$2
message=$3

# 检查是否提供了 branch 参数，如果没有，使用默认 branch
if [ -z "$branch" ]
then
  branch="main"
fi
echo "Will handle branch: $branch"

# 如果没有提供 message，使用默认 message
if [ -z "$message" ]
then
  message="[MDF] update at $(date)"
fi

# 切换到指定目录
# shellcheck disable=SC2164
cd $dir
echo "Changed to directory: $dir"

# 检查是否有未暂存的修改
if git diff-index --quiet HEAD --; then
  echo "No unstaged changes."
else
  # 暂存所有修改
  git add .
  echo "Staged all changes."
fi

# 检查是否有暂存的修改
if git diff-index --cached --quiet HEAD --; then
  echo "No staged changes."
else
  # 提交所有暂存的修改
  git commit -m "$message"
  echo "Committed all staged changes."
fi

# 检查是否有未推送的修改
if git diff --quiet origin/$branch; then
  echo "No changes to push."
else
  # 推送所有修改
  git push origin $branch
  echo "Pushed all changes."
fi