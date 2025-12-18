# Bash set 指令實務筆記

`set` 用來改變整個 shell script 的行為規則。
通常會放在腳本最前面，當作「執行安全模式」。

1️⃣ set -e
❯ 遇到錯誤就停止

行為:  

- 任何指令 exit code ≠ 0
- script 立刻中止

```sh
set -e
cp /not/exist/file /tmp
echo "完成"
```

👉 echo 不會執行

解決的問題

- 防止「部署失敗卻顯示成功」
- 防止後續動作破壞系統

2️⃣ set -u

❯ 使用未定義變數就爆

行為:  

- 使用未宣告或 typo 的變數
- script 立刻中止

```sh
set -u
echo "$TARGET_DRI"
```

👉 直接錯誤（而不是空字串）

解決的問題

- 變數拼錯刪錯目錄
- `$VAR`其實是空的卻沒發現

3️⃣ set -o pipefail

❯ 管線任何一段失敗都算失敗

行為

```text
cmd1 | cmd2 | cmd3
```

- 只要 其中一個失敗
- 整個 pipeline exit code ≠ 0

```sh
grep nginx /not/exist/file | wc -l
```

| 狀況          | exit code |
| ----------- | --------- |
| 沒有 pipefail | 0（錯誤被吃掉）  |
| 有 pipefail  | 非 0（正確）   |

解決的問題

- log 檔不存在卻顯示 0 筆
- 指令錯誤被隱藏

### 標準寫法

```sh
set -euo pipefail
```

| 參數         | 防什麼          |
| ---------- | ------------ |
| `-e`       | 指令失敗還繼續跑     |
| `-u`       | 變數 typo / 空值 |
| `pipefail` | 管線錯誤被吃       |

📌 部署、刪檔、系統操作腳本

### 進階但常見的`set`用法

```sh
#除錯用
set -x
```

- 每一行指令都會印出來
- 用來 debug shell 流程

📌 不要留在正式部署腳本

set +e / set +u（暫時關閉）

```sh
set +e
some_command_that_may_fail
set -e
```

📌 用在「預期會失敗」的指令