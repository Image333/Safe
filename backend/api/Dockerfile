FROM golang:1.26 AS build

WORKDIR /app

COPY . /app

ENV CGO_ENABLED=0

RUN go build -o gpe .


FROM alpine:latest
WORKDIR /app
COPY --from=build /app/gpe .

CMD ["./gpe"]
