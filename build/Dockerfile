FROM gliderlabs/alpine
MAINTAINER Ben Ford <ben.ford@puppet.com>
WORKDIR /var/cache/showoff
RUN apk add --no-cache ruby ruby-dev zlib-dev build-base git cmake busybox \
        && gem install etc commonmarker showoff --no-ri --no-rdoc          \
        && apk del --purge  binutils isl libgomp libatomic mpfr3 mpc1 gcc make musl-dev libc-dev fortify-headers g++ build-base libattr libacl libbz2 xz-libs libarchive cmake \
        && rm -rf `gem environment gemdir`/gems/commonmarker-*/test \
        && rm -rf `gem environment gemdir`/cache

CMD ["showoff", "serve"]
