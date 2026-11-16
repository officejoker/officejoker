# officejoker

**简体中文**

把模型网关反代成一整套标准 **OpenAI 兼容 API**，自带中文控制台，容器化部署，支持 **amd64 + arm64** 双架构。

**零依赖** —— 只用 Node.js 内置模块，不用 `npm install`。

> 本项目由 officeace2api 改造而来：移除全部 Windows 专属逻辑（`.cmd` 启动脚本、
> DPAPI 解密、icacls、PowerShell 判活、桌面端扫盘路径），面向 Linux 容器运行。
> 账号请通过**控制台自助登录**或手工导入 / 上游直连模式提供。

![控制台](docs/panel-accounts.png)

---

## 一、有什么功能

### API 层

| 能力 | 说明 |
|---|---|
| `/v1/chat/completions` | 流式 SSE + 非流式 |
| `/v1/models` | 模型列表 |
| Function Calling | 工具调用原样透传 |
| `reasoning_content` | 推理模型的思维链，单独字段返回 |
| `usage` | token 统计（含 `reasoning_tokens`、`cached_tokens`） |
| `/healthz`、`/health` | 健康检查，返回版本信息 |

任何能填 Base URL 的客户端都能接：Cherry Studio、NextChat、LobeChat、Cline、Roo Code、
Continue、Cursor、Dify、沉浸式翻译、OpenAI SDK……

### 控制台（`http://<host>:7864/admin`）

> 控制台默认带**面板口令**校验（首次启动自动生成）。
> 打开时地址要带 `?token=`，或者请求头带 `x-admin-token`。

| 菜单 | 干什么 |
|---|---|
| **概览** | 一屏看运行状态、剩余积分、今日签到和最近调用（失败调用直接显示原因） |
| **账号池** | 多账号的凭据、剩余积分、健康度一览；批量续期 / 签到 / 停用；导出 / 导入凭证 |
| **用量** | 请求数、token 消耗、近 7 天走势、失败原因分类 |
| **积分构成** | 每个账号还剩多少积分 —— 直接问云端，不是估算 |
| **模型与档位** | 模型清单、别名、隐藏、手工补录；**账号 × 模型可用性矩阵**；自带测试台 |
| **接入信息** | 各种客户端该填什么，一键复制 JSON / .env / curl |
| **运行日志** | 实时日志，按级别过滤 |
| **配置** | 改端口、API Key、上游、刷新间隔，存回 `config.json` |

### 自动化

- **多账号号池**：首包延迟 + 在途数调度、会话黏性、满员短队列、限流指数退避、连续失败熔断、积分熔断；状态落盘，重启不重置
- **模型兜底**：`models.fallback` 里配好备用模型，主模型 429/5xx 时自动换一个重试
- **凭据自动续期**：临时凭据到期前自动换新
- **换机搬家**：一键导出全部账号凭证（可加口令加密），新机器一键导入
- **每日自动签到**：定时领积分

---

## 二、Docker 部署（推荐）

### 1. 拉镜像

```bash
# 最新版（amd64 / arm64 自动匹配）
docker pull ghcr.io/officejoker/officejoker:latest

# 按版本 / commit 固定
docker pull ghcr.io/officejoker/officejoker:1.0.0
docker pull ghcr.io/officejoker/officejoker:sha-abcdef1
```

### 2. `docker run` 快速上手

**最简启动**（数据落在容器内，重建即丢，仅试玩用）：

```bash
docker run -d \
  --name officejoker \
  -p 7864:7864 \
  ghcr.io/officejoker/officejoker:latest
```

**生产推荐**（挂载持久化目录 + 自动重启）：

```bash
mkdir -p ./data ./logs

docker run -d \
  --name officejoker \
  --restart unless-stopped \
  -p 7864:7864 \
  -v "$(pwd)/data:/app/data" \
  -v "$(pwd)/logs:/app/logs" \
  ghcr.io/officejoker/officejoker:latest
```

**带环境变量**（免 config 文件，直接覆盖默认配置）：

```bash
docker run -d \
  --name officejoker \
  --restart unless-stopped \
  -p 7864:7864 \
  -v "$(pwd)/data:/app/data" \
  -v "$(pwd)/logs:/app/logs" \
  -e OFFICEJOKER_KEYS="sk-your-key-1,sk-your-key-2" \
  -e TZ=Asia/Shanghai \
  ghcr.io/officejoker/officejoker:latest
```

**上游直连模式**（不登录账号，当通用 OpenAI 反代）：

```bash
docker run -d \
  --name officejoker \
  --restart unless-stopped \
  -p 7864:7864 \
  -v "$(pwd)/data:/app/data" \
  -v "$(pwd)/logs:/app/logs" \
  -e OFFICEJOKER_BASE_URL="https://your-upstream.example.com" \
  -e OFFICEJOKER_AUTHORIZATION="Bearer sk-upstream-key" \
  -e OFFICEJOKER_KEYS="sk-your-key" \
  ghcr.io/officejoker/officejoker:latest
```

**挂载自己的 config.json**：

```bash
docker run -d \
  --name officejoker \
  --restart unless-stopped \
  -p 7864:7864 \
  -v "$(pwd)/data:/app/data" \
  -v "$(pwd)/logs:/app/logs" \
  -v "$(pwd)/config.json:/app/config.json:ro" \
  ghcr.io/officejoker/officejoker:latest
```

### 3. 环境变量一览

| 变量 | 说明 | 默认 |
|---|---|---|
| `OFFICEJOKER_PORT` | 监听端口 | `7864` |
| `OFFICEJOKER_HOST` | 监听地址（容器内固定 `0.0.0.0`） | `0.0.0.0` |
| `OFFICEJOKER_KEYS` | API Key，多个逗号分隔 | `sk-officejoker` |
| `OFFICEJOKER_BASE_URL` | 上游地址（直连模式） | 空 |
| `OFFICEJOKER_AUTHORIZATION` | 上游鉴权头（直连模式） | 空 |
| `TZ` | 时区（影响日志与签到时间） | 容器内 UTC |

### 4. 启动之后

```bash
# 看日志，里面会打印带面板口令的控制台地址
docker logs officejoker
```

输出里找这两行：

```
控制台     http://0.0.0.0:7864/admin?token=xxxxxxxxxxxxxxxx
OpenAI 基址 http://0.0.0.0:7864/v1
```

浏览器打开**控制台**地址（把 `0.0.0.0` 换成你的主机 IP 或 `127.0.0.1`），
在「号池」页点「换个账号登录」，登录一次即可使用。

### 5. 常用运维命令

```bash
docker logs -f officejoker          # 跟踪日志
docker restart officejoker          # 重启
docker stop officejoker && docker rm officejoker   # 停止并删除
docker exec -it officejoker sh      # 进容器排查
curl http://127.0.0.1:7864/healthz  # 健康检查（返回版本）
```

### 6. Docker Compose

仓库自带 `docker-compose.yml`：

```bash
mkdir -p data logs
docker compose up -d
docker compose logs -f
```

### 7. 冒烟测试

```bash
curl http://127.0.0.1:7864/v1/chat/completions \
  -H "Authorization: Bearer sk-officejoker" \
  -H "Content-Type: application/json" \
  -d '{"model":"default","messages":[{"role":"user","content":"你好"}]}'
```

---

## 三、源码运行（不用 Docker）

要求 Node.js ≥ 20：

```bash
git clone https://github.com/officejoker/officejoker.git
cd officejoker
OFFICEJOKER_HOST=0.0.0.0 OFFICEJOKER_PORT=7864 node src/index.mjs
```

跑测试（无需任何依赖）：

```bash
node tools/run-tests.mjs
```

---

## 四、CI / 镜像发布

- **每次推送到 `main`**：自动跑单测 + 构建双架构镜像，发布 `latest` 和 `sha-xxxxxxx` 标签到 GHCR
- **手动发布**：GitHub 仓库 → Actions → **docker** → Run workflow，可自定义额外 tag
- **打版本 tag**（如 `v1.0.0`）：额外发布 `1.0.0` / `1.0` / `1` 标签

镜像发布在 GitHub Container Registry：`ghcr.io/officejoker/officejoker`。

---

## 五、与原版（officeace2api）的差异

| 项 | 原版 | 本版 |
|---|---|---|
| 运行平台 | Windows 为主 | Linux 容器（amd64 + arm64），任何能跑 Node 20 的地方 |
| 启动方式 | `start.cmd` 等批处理 | `node src/index.mjs` / Docker |
| DPAPI 加密档案 | 支持（PowerShell 解密） | 不支持：容器里没有 DPAPI，加密档案不可读（明文凭据、自助登录、上游直连均不受影响） |
| 桌面端扫盘 | 扫 `C:\…\OfficeAce` 等盘符 | 移除盘符路径；如需扫描指定目录，挂载后用 `OFFICEJOKER_INSTALL_DIR` 指向它 |
| Windows 文件权限（icacls） | 有 | POSIX `chmod 600` |
| 进程判活 | PowerShell 查进程创建时间 | `/proc` 语义（pid + kill 0） |
| 默认 API Key | `sk-officeace` | `sk-officejoker` |

其余功能逻辑、配置结构、面板交互与原版一致。

## 六、安全须知

- `data/` 里有**明文长效凭据**（refreshToken、DPoP 私钥等），务必挂载到可信磁盘并收紧宿主机权限
- 面板口令首次启动自动生成，写在启动日志里；生产环境建议通过 `config.json` 的 `admin.token` 固定下来
- 不要把服务端口直接暴露到公网；确有需要，前面加反向代理 + HTTPS + 额外鉴权

## 许可

见 [LICENSE](LICENSE)。
