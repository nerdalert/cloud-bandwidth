# Application container for the project https://github.com/nerdalert/cloud-bandwidth
# Build the binary
FROM golang:1.17-alpine AS build

MAINTAINER Brent Salisbury <brent.salisbury@gmail.com>

WORKDIR /app

COPY go.mod ./
COPY go.sum ./

RUN go mod download

COPY *.go ./

RUN CGO_ENABLED=0 GOOS=linux go build -a -o build -o cloud-banwidth .

# Deploy the app
FROM fedora:latest

WORKDIR /

RUN dnf -y install iperf3 netperf

COPY --from=build /app/cloud-banwidth /cloud-banwidth

RUN chmod +x /cloud-banwidth

ENTRYPOINT ["/cloud-banwidth"]