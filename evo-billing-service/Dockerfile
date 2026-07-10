FROM ruby:3.4.4-alpine

# Build dependencies
RUN apk add --no-cache \
    build-base \
    postgresql-dev \
    postgresql-client \
    curl \
    tzdata \
    git

WORKDIR /app

# Gems first for Docker layer caching
COPY Gemfile Gemfile.lock* ./
RUN bundle install --jobs 4 --retry 3

# Application code
COPY . .

# Ensure log and tmp directories exist
RUN mkdir -p log tmp

# Bootsnap cache
RUN bundle exec bootsnap precompile --gemfile

EXPOSE 3002

CMD ["bundle", "exec", "rails", "server", "-p", "3002", "-b", "0.0.0.0"]
