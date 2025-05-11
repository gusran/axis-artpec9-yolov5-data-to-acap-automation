ARG ARCH=aarch64
ARG VERSION=12.4.0
ARG UBUNTU_VERSION=24.04
ARG REPO=axisecp
ARG SDK=acap-native-sdk
ARG CHIP=artpec9

FROM ${REPO}/${SDK}:${VERSION}-${ARCH}-ubuntu${UBUNTU_VERSION}

#-------------------------------------------------------------------------------
# Install TensorFlow (only used to inspect the model)
#-------------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-venv \
  && rm -rf /var/lib/apt/lists/*

# Create a virtual environment for installations using pip
RUN python3 -m venv /opt/venv

# hadolint ignore=SC1091,DL3013
RUN . /opt/venv/bin/activate && pip install --no-cache-dir tensorflow

#-------------------------------------------------------------------------------
# Get YOLOv5 model and labels (from local files, not remote)
#-------------------------------------------------------------------------------

# copy your local model into the image
WORKDIR /opt/app/model
COPY ./best-int8.tflite ./model.tflite

# copy your local labels file into the image
WORKDIR /opt/app/label
COPY ./labels.txt ./labels.txt

#-------------------------------------------------------------------------------
# Build ACAP application
#-------------------------------------------------------------------------------

WORKDIR /opt/app
COPY ./app .

ARG CHIP

COPY app/manifest.json.${CHIP} /opt/app/manifest.json
# Extract model parameters using the virtual environment
# hadolint ignore=SC1091
# RUN . /opt/venv/bin/activate && python parameter_finder.py 'model/model.tflite'

COPY model_params.h      .

RUN . /opt/axis/acapsdk/environment-setup* && acap-build . \
      -a 'label/labels.txt' \
      -a 'model/model.tflite'
