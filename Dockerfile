FROM golang:1.27-alpine AS compilador

WORKDIR /app

COPY go.mod ./
COPY main.go ./

RUN CGO_ENABLED=0 GOOS=linux go build -o servidor .

FROM alpine:3.22

WORKDIR /app

COPY --from=compilador /app/servidor .
COPY static ./static
COPY templates ./templates

EXPOSE 8080

CMD ["./servidor"]
