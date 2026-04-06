# ========================================================
# Stage: Builder
# ========================================================
# 使用 golang 的 bookworm 镜像作为基础，但手动更新源到 trixie
# 或者直接使用 debian:trixie 作为基础手动安装 golang
FROM debian:trixie-slim AS builder

WORKDIR /app
ARG TARGETARCH

# 安装 Golang 1.26+ (Trixie 仓库通常包含较新版本) 及构建依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    golang-go \
    build-essential \
    gcc \
    curl \
    unzip \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY . .

ENV CGO_ENABLED=1
ENV CGO_CFLAGS="-D_LARGEFILE64_SOURCE"
# 注意：直接调用系统的 go 编译器
RUN go build -ldflags "-w -s" -o build/x-ui main.go
RUN chmod +x ./DockerInit.sh && ./DockerInit.sh "$TARGETARCH"

# ========================================================
# Stage: Final Image of 3x-ui
# ========================================================
FROM debian:trixie-slim
ENV TZ=Asia/Tehran
WORKDIR /app

# 安装运行所需的依赖
# Trixie 的包管理非常现代，基本不需要担心库过旧
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    tzdata \
    fail2ban \
    bash \
    curl \
    openssl \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/build/ /app/
COPY --from=builder /app/DockerEntrypoint.sh /app/
COPY --from=builder /app/x-ui.sh /usr/bin/x-ui

# Configure fail2ban
# Debian Trixie 中的 fail2ban 配置与之前的版本基本一致
RUN cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local \
    && sed -i "s/^\[sshd\]$/&\nenabled = false/" /etc/fail2ban/jail.local \
    && sed -i "s/#allowipv6 = auto/allowipv6 = auto/g" /etc/fail2ban/fail2ban.conf

RUN chmod +x \
    /app/DockerEntrypoint.sh \
    /app/x-ui \
    /usr/bin/x-ui

ENV XUI_ENABLE_FAIL2BAN="true"
EXPOSE 2053
VOLUME [ "/etc/x-ui" ]

ENTRYPOINT [ "/app/DockerEntrypoint.sh" ]
CMD [ "./x-ui" ]
