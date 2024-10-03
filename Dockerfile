ARG VERSION=v0.107.52

FROM debian:bookworm-slim AS source

RUN apt-get update && \
    apt-get install -y git && \
    rm -rf /var/lib/apt/lists/*

ARG VERSION

WORKDIR /source
RUN git clone https://github.com/AdguardTeam/AdGuardHome.git . && \
    git checkout ${VERSION}

FROM debian:bookworm-slim AS go

ENV VERSION=1.22.5 \
    CHECKSUM=904b924d435eaea086515bc63235b192ea441bd8c9b198c507e85009e6e4c7f0

WORKDIR /go
ADD --checksum="sha256:${CHECKSUM}" "https://go.dev/dl/go${VERSION}.linux-amd64.tar.gz" .

RUN tar -xf "go${VERSION}.linux-amd64.tar.gz" -C . && \
    rm "go${VERSION}.linux-amd64.tar.gz"

FROM node:22 AS build

COPY --from=go /go /usr/local
ENV PATH="${PATH}:/usr/local/go/bin"

WORKDIR /build
COPY --from=source /source .

ARG VERSION
ENV NODE_OPTIONS=--openssl-legacy-provider

RUN make init && make VERSION=${VERSION}

RUN apt-get update && \
    apt-get install -y libcap2-bin && \
    rm -rf /var/lib/apt/lists/* && \
    setcap 'cap_net_bind_service=+ep' /build/AdGuardHome

FROM debian:bookworm-slim

COPY --from=build /build/AdGuardHome /opt/adguardhome/

RUN apt-get update && \
    apt-get install -y \
      ca-certificates  && \
    rm -rf /var/lib/apt/lists/* && \
    ln -sf /opt/adguardhome/AdGuardHome /usr/bin/AdGuardHome && \
    useradd --system -s /usr/sbin/nologin adguardhome

USER adguardhome

WORKDIR /etc/adguardhome/
ENTRYPOINT [ "AdGuardHome" ]
CMD [ "--no-check-update", "-c", "/etc/adguardhome/AdGuardHome.yaml", "-w", "/etc/adguardhome/" ]
