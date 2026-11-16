# officejoker —— 多架构镜像（amd64 + arm64）
# 项目零 npm 依赖，只用 Node 内置模块，构建就是拷文件，极快。
FROM --platform=$BUILDPLATFORM node:20-alpine

# 固定 UID/GID = 10001：挂载宿主机目录时，直接
#   chown -R 10001:10001 ./data ./logs
# 不用去镜像里查运行用户是谁。
# tini 做 PID 1：正确转发 SIGTERM，容器 stop 时优雅退出（保证 refresh_token 状态落盘）
RUN apk add --no-cache tini ca-certificates \
    && addgroup -g 10001 -S app \
    && adduser -u 10001 -G app -S -D -H -h /app app

WORKDIR /app

# 先只拷 package.json 以利用层缓存（本项目无依赖，npm install 是空操作，仅为保险）
COPY package.json ./
RUN npm install --ignore-scripts --no-audit --no-fund || true

# 再拷源码
COPY src/ ./src/
COPY tools/ ./tools/

# data/（凭据与状态）、logs/ 挂出来，容器重建后状态不丢
RUN mkdir -p /app/data /app/logs && chown -R 10001:10001 /app
VOLUME ["/app/data", "/app/logs"]

USER 10001:10001

ENV NODE_ENV=production \
    OFFICEJOKER_HOST=0.0.0.0 \
    OFFICEJOKER_PORT=7864

EXPOSE 7864

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "src/index.mjs"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD node -e "fetch('http://127.0.0.1:'+(process.env.OFFICEJOKER_PORT||7864)+'/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
