# define the function directory where Lambda looks for our within the container
ARG FUNCTION_DIR="/function"

# this can be any Linux image we want
FROM node:14-buster as build-image

# include global arg in this stage of the build
ARG FUNCTION_DIR

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

# create the actual function directory to be used in the final image
RUN mkdir -p ${FUNCTION_DIR}

# copy package-lock.json and package.json to be used in the final image
COPY app/package*.json ${FUNCTION_DIR}

# move into the FUNCTION_DIR to install dependencies
WORKDIR ${FUNCTION_DIR}

# don't install Lambda runtime interface client (RIC) because it's in our
# package.json (that way we can manage the version in the same place as all
# other packages)
# RUN npm install aws-lambda-ric

# install our app's dependencies
RUN npm ci

# copy Lambda code to be used in the final image
COPY app/* ${FUNCTION_DIR}

# get a fresh copy of the base image for the final image
FROM node:14-buster-slim

# carry over FUNCTION_DIR into the final image
ARG FUNCTION_DIR

# move into the FUNCTION_DIR
WORKDIR ${FUNCTION_DIR}

# copy code from build-image to the final image
COPY --from=build-image ${FUNCTION_DIR} ${FUNCTION_DIR}

ENTRYPOINT [ "/usr/local/bin/npx", "aws-lambda-ric" ]
CMD [ "app.handler" ]
