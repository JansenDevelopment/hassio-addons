ARG BUILD_FROM
FROM $BUILD_FROM

# jq reads the Supervisor options, curl asks the Supervisor for the MQTT broker.
RUN apk add --no-cache jq curl \
    && ankerctl --help >/dev/null

COPY run.sh /run.sh
RUN chmod a+x /run.sh

# The upstream image runs /app/entrypoint.sh (drops to the ankerctl user);
# run.sh prepares /data and the environment, then hands over to it.
ENTRYPOINT []
CMD [ "/run.sh" ]
