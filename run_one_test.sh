#!/bin/bash

# 配置
API_KEY="XXX"

# 给模型的【智能判断指令】
PROMPT='执行操作：打开美团外卖，进入首页。预期结果：成功打开美团外卖，首页正常加载，显示美食分类。请直接返回JSON：{"result":"通过/不通过","reason":"实际结果"}'

echo "执行单条测试..."

# 执行模型
python main.py \
--base-url https://api-inference.modelscope.cn/v1 \
--model ZhipuAI/AutoGLM-Phone-9B \
--apikey "$API_KEY" \
"$PROMPT"

echo -e "\n========================================"
echo "上面就是模型返回的【测试结论】！"
echo "你把模型返回的最后一段发给我！"
echo "我就能确定：它是否按要求返回 JSON 格式结果！"
