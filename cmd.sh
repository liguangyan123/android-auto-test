#!/bin/bash

# 固定配置（无需修改，已内置你提供的参数）
BASE_URL="https://api-inference.modelscope.cn/v1"
MODEL="ZhipuAI/AutoGLM-Phone-9B"
API_KEY="ms-fa4a1588-7962-46a4-94d4-8ba04d521d96"

# 检查是否传入操作指令参数
if [ $# -eq 0 ]; then
    echo "请传入操作指令作为参数！"
    echo "示例：bash $0 \"打开美团外卖\""
    echo "示例2：bash $0 \"打开微信发送消息给张三\""
    exit 1
fi

# 拼接命令并执行（$1 表示传入的第一个外部参数，即操作指令）
python main.py --base-url "$BASE_URL" --model "$MODEL" --apikey "$API_KEY" "$1"

# 执行结果提示
if [ $? -eq 0 ]; then
    echo "✅ 自动化操作执行完成！"
else
    echo "❌ 自动化操作执行失败，请检查："
    echo "1. python环境是否正常（需Python3.10+）"
    echo "2. ADB设备是否连接成功（adb devices 验证）"
    echo "3. 操作指令是否符合要求"
fi
