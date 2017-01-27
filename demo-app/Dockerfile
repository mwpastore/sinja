FROM ruby:2.4-alpine
ARG container_port=4567
ENV container_port=$container_port

RUN apk --no-cache upgrade
RUN apk --no-cache add \
        sqlite-libs

COPY Gemfile /app/
RUN apk --no-cache add --virtual build-dependencies \
        build-base \
        git \
        ruby-dev \
        sqlite-dev \
    && cd /app \
    && bundle install --jobs=4 \
    && apk del build-dependencies

COPY . /app
RUN chown -R nobody:nogroup /app

USER nobody
WORKDIR /app
CMD bundle exec ruby app.rb -o 0.0.0.0 -p $container_port

EXPOSE $container_port
