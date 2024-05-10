# Use a specific version of Alpine Linux as the build stage
FROM alpine:3.19 AS build

ENV PATH /usr/local/go/bin:$PATH

ENV GOLANG_VERSION 1.22.3

RUN set -eux; \
	apk add --no-cache --virtual .fetch-deps \
		ca-certificates \
		gnupg \
		tar \
	; \
	arch="$(apk --print-arch)"; \
	url=; \
	case "$arch" in \
		'x86_64') \
			url='https://dl.google.com/go/go1.22.3.linux-amd64.tar.gz'; \
			sha256='8920ea521bad8f6b7bc377b4824982e011c19af27df88a815e3586ea895f1b36'; \
			;; \
		'armhf') \
			url='https://dl.google.com/go/go1.22.3.linux-armv6l.tar.gz'; \
			sha256='f2bacad20cd2b96f23a86d4826525d42b229fd431cc6d0dec61ff3bc448ef46e'; \
			;; \
		'armv7') \
			url='https://dl.google.com/go/go1.22.3.linux-armv6l.tar.gz'; \
			sha256='f2bacad20cd2b96f23a86d4826525d42b229fd431cc6d0dec61ff3bc448ef46e'; \
			;; \
		'aarch64') \
			url='https://dl.google.com/go/go1.22.3.linux-arm64.tar.gz'; \
			sha256='6c33e52a5b26e7aa021b94475587fce80043a727a54ceb0eee2f9fc160646434'; \
			;; \
		'x86') \
			url='https://dl.google.com/go/go1.22.3.linux-386.tar.gz'; \
			sha256='fefba30bb0d3dd1909823ee38c9f1930c3dc5337a2ac4701c2277a329a386b57'; \
			;; \
		'ppc64le') \
			url='https://dl.google.com/go/go1.22.3.linux-ppc64le.tar.gz'; \
			sha256='04b7b05283de30dd2da20bf3114b2e22cc727938aed3148babaf35cc951051ac'; \
			;; \
		'riscv64') \
			url='https://dl.google.com/go/go1.22.3.linux-riscv64.tar.gz'; \
			sha256='d4992d4a85696e3f1de06cefbfc2fd840c9c6695d77a0f35cfdc4e28b2121c20'; \
			;; \
		's390x') \
			url='https://dl.google.com/go/go1.22.3.linux-s390x.tar.gz'; \
			sha256='2aba796417a69be5f3ed489076bac79c1c02b36e29422712f9f3bf51da9cf2d4'; \
			;; \
		*) echo >&2 "error: unsupported architecture '$arch' (likely packaging update needed)"; exit 1 ;; \
	esac; \
	\
	wget -O go.tgz.asc "$url.asc"; \
	wget -O go.tgz "$url"; \
	echo "$sha256 *go.tgz" | sha256sum -c -; \
	\
	GNUPGHOME="$(mktemp -d)"; export GNUPGHOME; \
	gpg --batch --keyserver keyserver.ubuntu.com --recv-keys 'EB4C 1BFD 4F04 2F6D DDCC  EC91 7721 F63B D38B 4796'; \
	gpg --batch --keyserver keyserver.ubuntu.com --recv-keys '2F52 8D36 D67B 69ED F998  D857 78BD 6547 3CB3 BD13'; \
	gpg --batch --verify go.tgz.asc go.tgz; \
	gpgconf --kill all; \
	rm -rf "$GNUPGHOME" go.tgz.asc; \
	\
	tar -C /usr/local -xzf go.tgz; \
	rm go.tgz; \
	\
	SOURCE_DATE_EPOCH="$(stat -c '%Y' /usr/local/go)"; \
	export SOURCE_DATE_EPOCH; \
	date --date "@$SOURCE_DATE_EPOCH" --rfc-2822; \
	\
	if [ "$arch" = 'armv7' ]; then \
		[ -s /usr/local/go/go.env ]; \
		before="$(go env GOARM)"; [ "$before" != '7' ]; \
		{ \
			echo; \
			echo '# https://github.com/docker-library/golang/issues/494'; \
			echo 'GOARM=7'; \
		} >> /usr/local/go/go.env; \
		after="$(go env GOARM)"; [ "$after" = '7' ]; \
		date="$(date -d "@$SOURCE_DATE_EPOCH" '+%Y%m%d%H%M.%S')"; \
		touch -t "$date" /usr/local/go/go.env /usr/local/go; \
	fi; \
	\
	apk del --no-network .fetch-deps; \
	\
	go version; \
	epoch="$(stat -c '%Y' /usr/local/go)"; \
	[ "$SOURCE_DATE_EPOCH" = "$epoch" ]

# Second stage for the final image
FROM alpine:3.19

RUN apk add --no-cache ca-certificates

ENV GOLANG_VERSION 1.22.3

# Don't auto-upgrade the Go toolchain
ENV GOTOOLCHAIN=local

# Set Go environment variables
ENV GOPATH /go
ENV PATH $GOPATH/bin:/usr/local/go/bin:$PATH

# Copy Go installation from the build stage
COPY --from=build /usr/local/go /usr/local/go

# Create necessary directories
RUN mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 1777 "$GOPATH"

# Set working directory
WORKDIR $GOPATH
