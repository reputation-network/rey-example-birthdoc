FROM reputationnetwork/gatekeeper as gatekeeper
FROM starefossen/ruby-node

WORKDIR /gatekeeper
COPY --from=gatekeeper /app .
RUN yarn install

WORKDIR /usr/src/app
RUN apt update && apt install -y libmagickwand-dev libtesseract-dev libleptonica-dev tesseract-ocr libssl-dev
RUN bundle config --global frozen 1
ADD Gemfile Gemfile.lock ./
RUN bundle install
ADD . .
RUN ln -nfs /usr/lib/x86_64-linux-gnu/libssl.so.1.0.2 /usr/lib/x86_64-linux-gnu/libssl.so

WORKDIR /
RUN gem install foreman
RUN echo "gatekeeper: cd /gatekeeper && node src/server.js\nweb: cd /usr/src/app && bundle exec ruby app.rb -p 8081" > Procfile
ENV TARGET_APP_URL=http://localhost:8081

CMD ["foreman", "start"]
