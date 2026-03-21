# Stage 1: Build frontend
FROM node:20-alpine AS frontend-builder
WORKDIR /app/frontend
ENV CYPRESS_INSTALL_BINARY=0
RUN npm install -g pnpm
COPY frontend/package.json frontend/pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile
COPY frontend/ ./
RUN pnpm build

# Stage 2: Build backend
FROM golang:1.25-alpine AS backend-builder
WORKDIR /app
RUN apk add --no-cache git
RUN go install github.com/knadh/stuffbin/...@v1.3.0
COPY go.mod go.sum ./
RUN go mod download
COPY cmd/ ./cmd/
COPY internal/ ./internal/
COPY i18n/ ./i18n/
COPY static/ ./static/
COPY schema.sql ./
COPY --from=frontend-builder /app/frontend/dist ./frontend/dist
RUN CGO_ENABLED=0 go build -a \
    -ldflags="-s -w" \
    -o libredesk cmd/*.go
RUN /go/bin/stuffbin -a stuff -in libredesk -out libredesk \
    frontend/dist i18n schema.sql static

# Stage 3: Final image
FROM alpine:3.18
RUN apk --no-cache add ca-certificates tzdata
WORKDIR /libredesk
COPY --from=backend-builder /app/libredesk .
COPY config.sample.toml config.toml
EXPOSE 9000
CMD ["./libredesk"]
