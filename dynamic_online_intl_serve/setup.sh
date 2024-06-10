#!/bin/bash

# 询问用户输入目录
read -p "Enter your Flutter project directory: " project_dir

# 检查目录是否存在
if [ ! -d "$project_dir" ]; then
  echo "The directory does not exist."
  exit 1
fi

# 检查目录中是否包含 pubspec.yaml 文件
pubspec_path="$project_dir/pubspec.yaml"
if [ ! -f "$pubspec_path" ]; then
  echo "No pubspec.yaml found in the directory."
  exit 1
fi

# 检查 pubspec.yaml 是否包含 intl 依赖
if ! grep -q "intl:" "$pubspec_path"; then
  echo "intl dependency not found in pubspec.yaml."
  exit 1
fi

# 检查是否配置了 flutter_intl 插件，并获取 arb_dir
arb_dir=$(awk '/flutter_intl:/,/output_dir:/' $pubspec_path | grep 'arb_dir:' | cut -d ':' -f 2 | xargs)
if [ -z "$arb_dir" ]; then
  echo "No arb_dir found in the flutter_intl configuration."
  exit 1
fi

# 计算完整的 ARB 目录路径
full_arb_dir="$project_dir/$arb_dir"

# 创建 serve.env 文件
cat > "$PWD/lib/env/serve.env" <<EOF
PROJECT_DIR=$project_dir
ARB_DIR=$full_arb_dir
EOF

echo "serve.env created successfully."
echo "PROJECT_DIR: $project_dir"
echo "ARB_DIR: $full_arb_dir"