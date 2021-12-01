FROM mcr.microsoft.com/dotnet/sdk:6.0

# install build-tools
RUN apt-get update -y && apt-get -y install cmake build-essential libssl-dev pkg-config libboost-all-dev libsodium-dev

# build
ADD . /code/
RUN cd /code/src/Miningcore && \
    chmod +x ./linux-build.sh && ./linux-build.sh && mkdir /dotnetapp && cp -r ../../build/* /dotnetapp

WORKDIR /dotnetapp

# cleanup build artifacts
RUN apt-get --purge remove -y cmake build-essential libssl-dev pkg-config libboost-all-dev
RUN apt-get autoremove -y && apt-get clean autoclean
# RUN apt-get install -y libboost-system1.62.0 libboost-date-time1.62.0 libssl1.0.2
RUN rm -rf /var/lib/{apt,dpkg,cache,log} /tmp/* /var/tmp/*

# API
EXPOSE 4000
# Stratum Ports
EXPOSE 3032-3199

ENTRYPOINT dotnet Miningcore.dll -c /config.json
