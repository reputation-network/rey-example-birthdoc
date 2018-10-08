FROM reputationnetwork/gatekeeper as gatekeeper
FROM ubuntu:18.04

ENV LC_ALL C.UTF-8
ENV LANG C.UTF-8

RUN apt-get update && apt-get install -y curl patch bzip2 gawk g++ gcc make libc6-dev patch zlib1g-dev libyaml-dev libsqlite3-dev sqlite3 autoconf libgmp-dev libgdbm-dev libncurses5-dev automake libtool bison pkg-config libffi-dev libgmp-dev libreadline6-dev libssl-dev git python libmagickwand-dev libtesseract-dev libleptonica-dev tesseract-ocr libssl-dev sudo

ENV USER ubuntu
ENV HOME /home/${USER}
RUN useradd --create-home -s /bin/bash ${USER} \
  && passwd -d ${USER} \
  && addgroup ${USER} sudo \
  && echo "${USER} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
USER ubuntu
RUN mkdir ${HOME}/app
WORKDIR ${HOME}/app

# gatekeeper

RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
RUN sudo apt-get update && sudo apt-get install yarn -y

WORKDIR ${HOME}/gatekeeper
COPY --from=gatekeeper /app .
RUN sudo yarn install

RUN git clone https://github.com/sstephenson/rbenv.git ${HOME}/.rbenv
RUN git clone https://github.com/sstephenson/ruby-build.git ${HOME}/.rbenv/plugins/ruby-build
ENV PATH ${HOME}/.rbenv/bin:$PATH
RUN echo 'eval "$(rbenv init -)"' >> ~/.bashrc
RUN rbenv install 2.4.4
ENV PATH $HOME/.rbenv/shims:$HOME/.rbenv/bin:$HOME/.rbenv/plugins/ruby-build/bin:$PATH
RUN echo 'gem: --no-rdoc --no-ri' >> ${HOME}/.gemrc
RUN rbenv global 2.4.4
RUN gem install bundler
RUN gem install foreman

WORKDIR ${HOME}/app
RUN bundle config --global frozen 1
ADD Gemfile Gemfile.lock ./
RUN bundle install
ADD . .
RUN sudo ln -nfs /usr/lib/x86_64-linux-gnu/libssl.so.1.0.2 /usr/lib/x86_64-linux-gnu/libssl.so
RUN sudo chmod 777 -R tmp

# service

WORKDIR ${HOME}
RUN echo "gatekeeper: cd ~/gatekeeper && node src/server.js\nweb: cd ~/app && bundle exec ruby app.rb -p 8081" > Procfile
ENV TARGET_APP_URL=http://localhost:8081

CMD ["foreman", "start"]
