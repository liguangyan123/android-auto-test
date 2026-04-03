#!/bin/bash

# 传入用例文件
if [ $# -ne 1 ]; then
    echo "用法：$0 <test_cases.csv>"
    exit 1
fi
CASE_FILE="$1"

API_KEY="XXXX"
TEST_RES="1080x2048"
TIME_TAG=$(date +%Y%m%d_%H%M%S)
CASE_BASE=$(basename "$CASE_FILE" .csv)

LOG_DIR="execution_logs"
REPORT_DIR="test_reports"
mkdir -p $LOG_DIR $REPORT_DIR

LOG_FILE="$LOG_DIR/${TIME_TAG}.log"
REPORT_CSV="$REPORT_DIR/${CASE_BASE}_result_${TIME_TAG}.csv"

echo "用例ID,执行时间,用例文件,步骤,预期结果,实际结果" > "$REPORT_CSV"

echo "================================================" > "$LOG_FILE"
echo "执行时间: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
echo "用例文件: $CASE_FILE" >> "$LOG_FILE"
echo "================================================" >> "$LOG_FILE"

ORIGIN_RES=$(adb shell wm size | grep "Physical size" | awk '{print $3}')
adb shell wm size "$TEST_RES"
sleep 1

# ============================
# 【稳定读取 - 你环境能跑多条的写法】
# ============================
sed '1d' "$CASE_FILE" | tr -d '\r' > /tmp/all_cases.txt
exec 3< /tmp/all_cases.txt

while read -r line <&3; do
    [ -z "$line" ] && continue

    case_id=$(echo "$line" | cut -d',' -f1 | xargs)
    step=$(echo "$line" | cut -d',' -f2 | xargs)
    expect=$(echo "$line" | cut -d',' -f3 | xargs)

    echo -e "\n====================================="
    echo "用例ID：$case_id"
    echo "步骤：$step"

    echo "================================================" >> "$LOG_FILE"
    echo "用例ID：$case_id" >> "$LOG_FILE"
    echo "步骤：$step" >> "$LOG_FILE"
    echo "预期：$expect" >> "$LOG_FILE"
    echo "================================================" >> "$LOG_FILE"

    # 执行命令
    output=$(python main.py \
        --base-url https://api-inference.modelscope.cn/v1 \
        --model ZhipuAI/AutoGLM-Phone-9B \
        --apikey "$API_KEY" \
        "$step" 2>&1)

    echo "$output" | tee -a "$LOG_FILE"

    # ============================
    # ✅ 结果完整提取（不截断、不丢失）
    # ============================
    actual=$(echo "$output" \
        | sed -n '/^Result: /,$p' \
        | sed '1d' \
        | sed '/^===/,$d' \
        | tr '\n' ' ' \
        | sed 's/[,"]//g; s/  */ /g; s/^ //; s/ $//')

    [ -z "$actual" ] && actual="未获取到结果"

    echo "✅ 实际结果：$actual"

    echo "$case_id,$(date '+%Y-%m-%d %H:%M:%S'),$CASE_FILE,$step,$expect,$actual" >> "$REPORT_CSV"

done

exec 3<&-
rm -f /tmp/all_cases.txt

adb shell wm size reset

echo -e "\n🎉 全部执行完成！多条用例正常运行！"
echo "📊 报告：$REPORT_CSV"
echo "📄 日志：$LOG_FILE"
