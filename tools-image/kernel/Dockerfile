FROM ubuntu:24.04 AS builder
ARG APT_MIRROR_BASE
ARG BUILD_JOBS=8
RUN if [ -n "$APT_MIRROR_BASE" ]; then \
        sed -i -E "s|https?://(archive|security).ubuntu.com/ubuntu/?|${APT_MIRROR_BASE%/}/ubuntu/|g" \
            /etc/apt/sources.list.d/ubuntu.sources; \
    fi \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        bc bison build-essential ca-certificates curl flex libelf-dev libssl-dev \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir /out \
    && chown nobody:nogroup /out
COPY build.sh verify-config.sh sources.env nested-qemu.config /recipe/
USER nobody
RUN BUILD_JOBS="$BUILD_JOBS" bash /recipe/build.sh /out \
    && rm -rf /out/source-cache

FROM scratch AS artifact
COPY --from=builder /out/ /
