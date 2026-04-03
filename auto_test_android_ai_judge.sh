#!/bin/bash

if [ $# -ne 1 ]; then
    echo "用法: $0 <test_cases.csv>"
    exit 1
fi

CASE_FILE="$1"

# ==================== 你的配置 ====================
AUTOGLM_KEY="${AUTOGLM_KEY:-}"
AI_API_KEY="${AI_API_KEY:-}"
AI_MODEL="${AI_MODEL:-}"
TEST_RES="1080x2048"
# ====================================================

TIME_TAG=$(date +%Y%m%d_%H%M%S)
LOG_DIR="execution_logs"
REPORT_DIR="test_reports"
mkdir -p "$LOG_DIR" "$REPORT_DIR"

LOG_FILE="$LOG_DIR/run_${TIME_TAG}.log"
REPORT_CSV="$REPORT_DIR/result_${TIME_TAG}.csv"

echo "用例ID,执行时间,用例文件,步骤,预期结果,实际结果,AI判断" > "$REPORT_CSV"

{
echo "================================================"
echo "测试开始: $(date '+%Y-%m-%d %H:%M:%S')"
echo "用例文件: $CASE_FILE"
echo "================================================"
} >> "$LOG_FILE"

# 分辨率
ORIGIN_RES=$(adb shell wm size 2>/dev/null | grep "Physical size" | awk '{print $3}')
#adb shell wm size "$TEST_RES" >/dev/null 2>&1
sleep 2

# 读取用例
sed '1d' "$CASE_FILE" | tr -d '\r' > /tmp/all_cases.txt
exec 3< /tmp/all_cases.txt

# ==================== ✅ AI 判断【恢复最稳定的原始版本】====================
ai_judge() {
    local expect="$1"
    local actual="$2"

    local prompt="你是专业自动化测试判定员，严格按规则输出：
【预期结果】${expect}
【实际结果】${actual}
规则：
1. 实际结果达到目标 → 输出 PASS
2. 未达到、失败、无结果 → 输出 FAIL
3. 只输出 PASS 或 FAIL，不要其他内容"

    local response=$(curl -s "https://ark.cn-beijing.volces.com/api/v3/chat/completions" \
        -H "Authorization: Bearer ${AI_API_KEY}" \
        -H "Content-Type: application/json" \
        --connect-timeout 15 \
        -d "{
        \"model\": \"${AI_MODEL}\",
        \"temperature\": 0.1,
        \"max_tokens\": 10,
        \"messages\": [{\"role\":\"user\",\"content\":\"$(echo "$prompt" | tr '\n' ' ' | sed 's/"/\\\\\\"/g')\"}]
    }")

    local result=$(echo "$response" | sed -n 's/.*"content":"//;s/".*//p' | head -n1 | tr -d '[:space:]' | cut -c1-4)
    if [ "$result" = "PASS" ] || [ "$result" = "FAIL" ]; then
        echo "$result"
    else
        echo "FAIL"
    fi
}

# 执行用例
while read -r line <&3; do
    [ -z "$line" ] && continue
    case_id=$(echo "$line" | cut -d',' -f1 | xargs)
    step=$(echo "$line" | cut -d',' -f2 | xargs)
    expect=$(echo "$line" | cut -d',' -f3 | xargs)

    echo -e "\n====================================="
    echo "用例ID: $case_id"
    echo "步骤: $step"

    {
    echo ""
    echo "====================================="
    echo "用例ID: $case_id"
    echo "步骤: $step"
    echo "预期: $expect"
    echo "====================================="
    } >> "$LOG_FILE"

    # 执行自动化
    output=$(python main.py \
        --base-url https://api-inference.modelscope.cn/v1 \
        --model ZhipuAI/AutoGLM-Phone-9B \
        --apikey "$AUTOGLM_KEY" \
        "$step" 2>&1)

    echo "$output" | tee -a "$LOG_FILE"

# ==================== ✅ 结果提取【完全不修改 · 原样保留 · 无报错】====================
actual=$(echo "$output" \
| sed -n '/^Result: /,$p' \
| sed '/^===*/d' \
| tr '\n' ' ' \
| sed 's/,/ /g' \
| sed 's/  */ /g' \
| sed 's/^ //;s/ $//g')

actual=${actual:-未获取到结果}
# ====================================================================================

    status=$(ai_judge "$expect" "$actual")

    echo "✅ 实际结果: $actual"
    echo "🤖 AI 判断: $status"
    echo "实际结果: $actual" >> "$LOG_FILE"
    echo "AI 判断: $status" >> "$LOG_FILE"

    echo "$case_id,$(date '+%Y-%m-%d %H:%M:%S'),$CASE_FILE,$step,$expect,$actual,$status" >> "$REPORT_CSV"

done

# 恢复分辨率
exec 3<&-
rm -f /tmp/all_cases.txt
#[ -n "$ORIGIN_RES" ] && adb shell wm size "$ORIGIN_RES" >/dev/null 2>&1

echo -e "\n🎉 执行完成！AI 恢复正常！"
echo "📄 日志: $LOG_FILE"
echo "📊 报告: $REPORT_CSV"
