ARG BUILD_FROM
FROM $BUILD_FROM

RUN \
    set -x \
    && apk add --no-cache openvpn iproute2 \
    && openvpn --version | head -n 1

COPY run.sh /
RUN chmod a+x /run.sh

CMD [ "/run.sh" ]
