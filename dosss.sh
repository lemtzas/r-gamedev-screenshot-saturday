#! /bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
pwd
cd $DIR
pwd
git pull
/home/lem/.rvm/wrappers/ruby-2.1.5/ruby SSS_web.rb
/home/lem/.rvm/wrappers/ruby-2.1.5/ruby SSS_param.rb "LD31 Competition is Over! Post Games to Rate" "ld31.html"

