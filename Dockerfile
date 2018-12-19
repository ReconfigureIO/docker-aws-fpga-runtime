FROM ubuntu:18.04 AS buildtime

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install --yes --no-install-recommends \
        # Note: this list essentially taken from \
        # https://github.com/Xilinx/XRT/blob/master/src/runtime_src/tools/scripts/xrtdeps.sh, \
        # with a few of our own thrown in. \
        ca-certificates \
        cmake \
        cppcheck \
        curl \
        dkms \
        g++ \
        gcc \
        gdb \
        git \
        gnuplot \
        libboost-dev \
        libboost-filesystem-dev \
        libboost-program-options-dev \
        libc6-dev \
        libdrm-dev \
        libgtest-dev \
        libjpeg-dev \
        libncurses5-dev \
        libopencv-core-dev \
        libpng-dev \
        libprotoc-dev \
        libtiff5-dev \
        libxml2-dev \
        libyaml-dev \
        linux-libc-dev \
        lm-sensors \
        lsb \
        make \
        ocl-icd-dev \
        ocl-icd-libopencl1 \
        ocl-icd-opencl-dev \
        opencl-headers \
        pciutils \
        perl \
        pkg-config \
        protobuf-compiler \
        python \
        python3-sphinx \
        python3-sphinx-rtd-theme \
        sphinx-common \
        strace \
        sudo \
        unzip \
        uuid-dev \
        wget \
 && rm -rf /var/lib/apt/lists/*

ENV AWS_FPGA_VERSION=1.4.5 AWS_FPGA_VERSION_SHA256=e1c20c81f148e573e7c5c01a2ff3f8854d6138051c659ccdb6f7cde1e10abe72

# Installs FGPA management tooling to /usr/local/bin, etc.
RUN cd /tmp \
 && wget --quiet https://github.com/aws/aws-fpga/archive/v${AWS_FPGA_VERSION}.tar.gz \
 && echo "${AWS_FPGA_VERSION_SHA256}  v${AWS_FPGA_VERSION}.tar.gz" | sha256sum --check --strict \
 && tar xf v${AWS_FPGA_VERSION}.tar.gz \
 && SDK_DIR=/tmp/aws-fpga-${AWS_FPGA_VERSION}/sdk \
    bash -c 'source /tmp/aws-fpga-${AWS_FPGA_VERSION}/sdk_setup.sh' \
 && rm -rf /tmp/aws-fpga-${AWS_FPGA_VERSION}

ENV XRT_VERSION=2018.3.RC1 XRT_SHA256=e68c906ab3de106fec48d7dcfcc22c6b3e4b2b2559c4ae21e29d695097fb9aab

# Build and install the Xilinx runtime.
RUN cd /tmp \
 && wget --quiet https://github.com/Xilinx/XRT/archive/${XRT_VERSION}.tar.gz \
 && echo "${XRT_SHA256}  ${XRT_VERSION}.tar.gz" | sha256sum --check --strict \
 && tar xf ${XRT_VERSION}.tar.gz \
 && mkdir xrt-build && cd xrt-build

# Should be a formality, but let's check. This script simply checks that the
# correct pages are installed. If not, update the apt install list above.
RUN /tmp/XRT-${XRT_VERSION}/src/runtime_src/tools/scripts/xrtdeps.sh -docker -validate

RUN cd /tmp/xrt-build \
 && cmake \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DCMAKE_BUILD_TYPE=Release \
        ../XRT-${XRT_VERSION}/src \
 && make -j16 DESTDIR=/usr/local install


FROM ubuntu:18.04 AS run

ENV XILINX_XRT=/opt/xilinx/xrt \
    XILINX_OPENCL=/opt/xilinx/xrt \
    LD_LIBRARY_PATH=/opt/xilinx/xrt/lib:$LD_LIBRARY_PATH \
    PATH=/opt/xilinx/xrt/bin:$PATH

RUN apt-get update \
 && apt-get install libprotobuf10 libyaml-0-2

COPY --from=buildtime /usr/local/ /
