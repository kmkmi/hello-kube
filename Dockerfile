# Build stage
FROM golang:1.21-alpine AS builder
WORKDIR /src
COPY go.mod go.sum ./
RUN apk add --no-cache ca-certificates
RUN update-ca-certificates
RUN go mod download
COPY . .
ENV CGO_ENABLED=0
RUN go build -ldflags="-s -w" -o /hello-kube .

# Final stage
# Copy Build & CA bundle so TLS works (needed for https calls)
FROM scratch
COPY --from=builder /hello-kube /hello-kube
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
ENTRYPOINT ["/hello-kube"]