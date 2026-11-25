ARG BUILD_FROM

# ---------------------------------------------------------------------------
# Build ankerctl from source with one patch: unicast PPPP handshake to a known
# printer IP (see pppp-unicast.sh). Same tag as the upstream image in
# build.yaml, so the rest of the binary is identical.
# ---------------------------------------------------------------------------
FROM golang:1.25-alpine AS builder
ARG ANKERCTL_REF=v1.0.3
RUN apk add --no-cache git bash curl
RUN git clone --depth 1 --branch "${ANKERCTL_REF}" https://github.com/Django1982/ankerctl_go_remake /src
WORKDIR /src
COPY pppp-unicast.sh /tmp/pppp-unicast.sh
RUN sh /tmp/pppp-unicast.sh \
    && bash scripts/prepare-web-vendor.sh \
    && CGO_ENABLED=0 GOOS=linux go build -ldflags "-s -w -X main.Version=${ANKERCTL_REF#v}-unicast" \
        -o /out/ankerctl ./cmd/ankerctl/

# ---------------------------------------------------------------------------
# Runtime: the upstream image (entrypoint, ffmpeg, user), with our binary.
# ---------------------------------------------------------------------------
FROM $BUILD_FROM

COPY --from=builder /out/ankerctl /usr/local/bin/ankerctl

# jq reads the Supervisor options, curl asks the Supervisor for the MQTT broker.
RUN apk add --no-cache jq curl \
    && ankerctl --help >/dev/null

COPY run.sh /run.sh
RUN chmod a+x /run.sh

# The upstream image runs /app/entrypoint.sh (drops to the ankerctl user);
# run.sh prepares /data and the environment, then hands over to it.
ENTRYPOINT []
CMD [ "/run.sh" ]
