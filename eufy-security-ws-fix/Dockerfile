ARG BUILD_FROM
FROM $BUILD_FROM

WORKDIR /usr/src/app

# The pinned eufy-security-ws version and the patched eufy-security-client it
# must resolve to both live in package.json, because npm only honours
# "overrides" when it installs from a manifest — not from a command line.
COPY package.json ./

RUN \
    set -x \
    # The Alpine 3.23 base image (see build.yaml) ships Node.js 24 in its main
    # repository, so nodejs/npm install directly with no edge-repo workarounds.
    # git is ours: the eufy-security-client override is a GitHub dependency.
    && apk add --no-cache \
        git \
        jq \
        nodejs \
        npm \
    && node --version \
    # Fail the build if the base ever regresses below Node 24.
    && case "$(node --version)" in v24.*) ;; *) echo "Expected Node 24, got $(node --version)" >&2; exit 1 ;; esac \
    && npm install \
    # The fork's own "prepare" script compiles it, so assert the output exists
    # rather than discovering an empty package at runtime.
    && test -f node_modules/eufy-security-client/build/index.js \
    # Assert we got the PATCHED client, not the stock one from the registry.
    # Checking only that "a build exists" is not enough: npm will happily
    # resolve eufy-security-client to the unpatched 4.1.1 release and the
    # add-on then starts fine but drops every device on the next restart.
    # isSuccessfulResponseCode exists only in the fork.
    && grep -q "isSuccessfulResponseCode" node_modules/eufy-security-client/build/http/api.js \
    && grep -q "retrying register_push_token" node_modules/eufy-security-client/build/http/megaTransition.js \
    && node -e "require('eufy-security-client')" \
    && echo "OK: patched eufy-security-client verified" \
    && npm cache clean --force

COPY run.sh /
RUN chmod a+x /run.sh
WORKDIR /data

CMD [ "/run.sh" ]
