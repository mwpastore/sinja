FROM ruby:2.3-alpine
RUN apk --no-cache add \
        sqlite-libs

COPY Gemfile /app/
RUN apk --no-cache add --virtual build-dependencies \
        build-base \
        git \
        ruby-dev \
        sqlite-dev \
    && cd /app \
    && bundle install \
    && apk del build-dependencies

COPY . /app
RUN chown -R nobody:nogroup /app

USER nobody
WORKDIR /app
ENTRYPOINT ["bundle", "exec"]
CMD ["ruby", "app.rb", "-o", "0.0.0.0", "-p", "4567"]

EXPOSE 4567
