ARG BUILD_FROM
FROM $BUILD_FROM

ARG BUILD_ARCH

# SDRconnect is closed-source software of SDRplay Limited and may not be
# redistributed, so it is not in this repository: the image downloads it from
# sdrplay.com, exactly like SDRplay's own install.sh, and checks the published
# SHA-256. A new SDRconnect release = new build id + checksums here.
ARG SDRCONNECT_BUILD=93b44446f
ARG SDRCONNECT_SHA256_AMD64=343914da15ba18399552bb9100a7ea113caa46fed70679a0e690ea93636dc80f
ARG SDRCONNECT_SHA256_AARCH64=fb97167f30982dbb5ee538e95ea57467c44bc625b4930cb28d98976dbfadd1e9

# Dependencies from SDRplay's install.sh (check_dependencies), plus jq for the
# Supervisor options and libicu for the .NET runtime parts.
RUN set -eux; \
    export DEBIAN_FRONTEND=noninteractive; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates curl tar gzip jq \
        libusb-1.0-0 libasound2t64 libuuid1 libudev1 libmp3lame0 libhamlib4 \
        libicu74 libfontconfig1; \
    rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    case "${BUILD_ARCH}" in \
        amd64)   pkg="sdrconnect_linux-x64_${SDRCONNECT_BUILD}.tar.gz";   sum="${SDRCONNECT_SHA256_AMD64}" ;; \
        aarch64) pkg="sdrconnect_linux-arm64_${SDRCONNECT_BUILD}.tar.gz"; sum="${SDRCONNECT_SHA256_AARCH64}" ;; \
        *) echo "unsupported arch ${BUILD_ARCH}"; exit 1 ;; \
    esac; \
    curl -fL --retry 3 -o "/tmp/${pkg}" "https://www.sdrplay.com/software/${pkg}"; \
    echo "${sum}  /tmp/${pkg}" | sha256sum -c -; \
    mkdir -p /opt/sdrconnect; \
    tar -xzf "/tmp/${pkg}" -C /opt/sdrconnect --strip-components=1; \
    rm -f "/tmp/${pkg}"; \
    chmod a+x /opt/sdrconnect/SDRconnect /opt/sdrconnect/SDRconnect_headless; \
    test -f /opt/sdrconnect/LICENCE

COPY run.sh /run.sh
RUN chmod a+x /run.sh

CMD [ "/run.sh" ]
