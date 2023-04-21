FROM ruby:3.2.2-alpine

WORKDIR /var/cache/showoff

RUN apk add make gcc musl-dev g++ gcompat && gem install nokogiri showoff

ENTRYPOINT showoff serve
