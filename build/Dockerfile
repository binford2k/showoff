FROM gliderlabs/alpine
MAINTAINER Ben Ford <ben.ford@puppet.com>
WORKDIR /var/cache/showoff
RUN apk add --no-cache ruby ruby-dev zlib-dev build-base git cmake \
        && gem install showoff --no-ri --no-rdoc             \
        && gem install commonmarker --no-ri --no-rdoc \
        && apk del --purge binutils-libs binutils isl libgomp libatomic mpfr3 mpc1 gcc make musl-dev libc-dev fortify-headers g++ build-base cmake

CMD ["showoff", "serve"]
