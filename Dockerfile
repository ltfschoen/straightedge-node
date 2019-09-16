FROM debian:buster AS builder
LABEL maintainer="jake@commonwealth.im"
LABEL description="This is the build stage. Here we create the binary."
ARG PROFILE=release
WORKDIR /straightedge
COPY . /straightedge
RUN apt-get update && \
	apt-get install -y build-essential cmake pkg-config libssl-dev openssl git clang libclang-dev && \
	apt-get install -y curl vim unzip screen sudo && \
	curl https://sh.rustup.rs -sSf | sh -s -- -y && \
	echo 'PATH="$/root/.cargo/bin:$PATH";' >> ~/.bash_profile && \
  	. ~/.bash_profile && . /root/.cargo/env && \
	rustup update stable && \
	rustup update nightly && \
	rustup target add wasm32-unknown-unknown --toolchain nightly && \
	cargo --version && \
	cargo install --git https://github.com/alexcrichton/wasm-gc && \
	cargo build --release

# ===== SECOND STAGE ======

FROM debian:buster
LABEL maintainer="hello@commonwealth.im"
LABEL description="This is the 2nd stage: a very small image where we copy the Straightedge binary."
ENV DEBIAN_FRONTEND noninteractive
ARG PROFILE=release
RUN mkdir -p /usr/local/bin/straightedge
COPY --from=builder /straightedge/target/$PROFILE/straightedge /usr/local/bin/straightedge/straightedge
COPY --from=builder /straightedge/mainnet /usr/local/bin/straightedge/mainnet
# latest Node.js 12.x https://github.com/nodesource/distributions#installation-instructions
RUN rm -rf /usr/lib/python* && \
	mkdir -p /root/.local/share && \
	ln -s /root/.local/share /data \
	cd /usr/local/bin && \
	apt-get update && \
	apt-get install -y git cmake && \
	apt-get install -y --no-install-recommends apt-utils && \
	apt-get install -y curl screen && \
	curl -sL https://deb.nodesource.com/setup_12.x | bash - && \
	apt-get install -y nodejs
RUN cd /root && \
	apt remove yarn && \
	# don't use ssh otherwise you need github host keys
	git clone https://github.com/hicommonwealth/edgeware-cli && \
	cd edgeware-cli && \
	curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
	echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
	apt update && \
	apt install -y yarn && \
	yarn && \
	yarn run build

EXPOSE 30333 30334 9933 9944
VOLUME ["/data"]

WORKDIR /usr/local/bin

RUN echo $PWD
ENV DEBIAN_FRONTEND teletype
