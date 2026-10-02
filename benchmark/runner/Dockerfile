FROM golang:1.25 AS build

WORKDIR /src

COPY go.mod .
COPY main.go .

RUN CGO_ENABLED=0 GOOS=linux go build -o /benchmark-runner .

FROM alpine:3.22

COPY --from=build /benchmark-runner /usr/local/bin/benchmark-runner

ENTRYPOINT ["benchmark-runner"]
