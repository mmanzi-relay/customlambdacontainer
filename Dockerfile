# define the function directory where Lambda looks for our within the container
ARG FUNCTION_DIR="/function"

# this can be any Linux image we want
FROM node:14-slim as build-image

# install resources needed to build the AWS Lambda client tool
RUN apt-get update && \
  apt-get install -y \
  g++ \
  make \
  cmake \
  unzip \
  libcurl4-openssl-dev

# carry over FUNCTION_DIR for the next build stage
ARG FUNCTION_DIR

# create the actual function directory to be used in the final container
RUN mkdir -p ${FUNCTION_DIR}

# copy Lambda code to be used in the final container
COPY app/* ${FUNCTION_DIR}

# install Lambda runtime interface client (RIC)
RUN pip install \
  --target ${FUNCTION_DIR} \
  awslambdaric

# get a fresh copy of the base image for the final container
FROM node:14-slim

# carry over FUNCTION_DIR into the final container
ARG FUNCTION_DIR

# move into the FUNCTION_DIR
WORKDIR ${FUNCTION_DIR}

# copy code from build-image to the final container
COPY --from=build-image ${FUNCTION_DIR} ${FUNCTION_DIR}

ENTRYPOINT [ "/usr/local/bin/python", "-m", "awslambdaric" ]
CMD [ "app.handler" ]
