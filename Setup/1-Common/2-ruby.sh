#!/bin/bash
#
# Exit on errors # or unintialized variables
#
set -x -e # -o nounset
#
# Note: RVM installer often fails GPG signature verification, omit `set -e` if necessary
# Note: RVM triggers `set -o nounset`, so it has been omitted


# Prepare directory, import key and install Ruby Version Manager (RVM)
#
cd $HOME
rm -rf ~/.rvm
gpg --keyserver hkp://keys.gnupg.net --recv-keys D39DC0E3
curl -L https://get.rvm.io | bash -s stable


# Install Ruby 1.9.3, Ruby Gems, Bundler and Rails with around 26 gems
#
source $HOME/.rvm/scripts/rvm
rvm get stable
rvm requirements
rvm install 1.9.3
rvm use 1.9.3 --default     # alternative: rvm alias create default ruby-1.9.3-p550
rvm rubygems current
gem install bundler
gem install rails
#
# `/bin/bash --login` ... `exit` may be required for running manually, see http://rvm.io/