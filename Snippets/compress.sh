#!/bin/bash

# 指定要遍历的文件夹路径
input_folder="."
max_size_gb=1.7  # 你可以在这里指定以 GB 为单位的目标文件大小

# 将 max_size 转换为字节数，使用 bc 进行浮点运算
max_size=$(echo "$max_size_gb * 1024 * 1024 * 1024" | bc)


# 遍历文件夹中的所有 MP4 文件
for file in "$input_folder"/*.mp4; do
  # 获取不带扩展名的文件名
  filename=$(basename "$file" .mp4)
  
  # 获取视频时长（单位：秒，允许小数）
  duration=$(ffmpeg -i "$file" 2>&1 | grep "Duration" | awk '{print $2}' | tr -d , | awk -F: '{print ($1 * 3600) + ($2 * 60) + $3}')
  
  # 获取当前视频的比特率（单位：bps）
  current_bitrate=$(ffmpeg -i "$file" 2>&1 | grep "bitrate:" | awk '{print $6 * 1000}') # 转换为 bps
  
  # 检查是否成功获取时长和比特率
  if [ -z "$duration" ] || [ -z "$current_bitrate" ]; then
    echo "无法获取视频时长或比特率：$file"
    continue
  fi
  
  # 根据时长计算目标比特率（2GB 除以视频时长），使用 bc 进行浮点计算
  target_bitrate=$(echo "$max_size * 8 / $duration" | bc)
  
  # 将比特率转换为 kbps，继续使用 bc 处理
  target_bitrate_kbps=$(echo "$target_bitrate / 1000" | bc)
  
  # 如果目标比特率比当前比特率高，跳过压缩
  if [ "$target_bitrate" -ge "$current_bitrate" ]; then
    echo "当前文件的比特率已经高于目标比特率，跳过压缩：$file"
    continue
  fi
  
  # 压缩视频到计算出的比特率
  echo "Compressing: ${filename}_compressed.mp4 with bitrate ${target_bitrate_kbps} kbps"

  ffmpeg -i "$file" -b:v "${target_bitrate_kbps}k" -c:v h264_videotoolbox -preset slow "${input_folder}/${filename}_compressed.mp4"
  
  echo "Compressed: ${filename}_compressed.mp4 with bitrate ${target_bitrate_kbps} kbps"
done