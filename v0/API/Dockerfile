FROM golang:1.25 AS build

WORKDIR /app

COPY . /app

ENV CGO_ENABLED=0

RUN go build -o api .


FROM alpine:latest
WORKDIR /app
COPY --from=build /app/api api

CMD ["./api"]
