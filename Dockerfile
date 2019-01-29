FROM ruby:2.6
WORKDIR /app

COPY Gemfile Gemfile.lock /app/
RUN bundle install
COPY . /app/
CMD bundler exec ruby /app/h12-monitor.rb run 
