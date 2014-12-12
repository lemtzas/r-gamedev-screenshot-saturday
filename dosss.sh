#! /bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
pwd
cd $DIR
pwd
git pull
/home/lem/.rvm/wrappers/ruby-2.1.5/ruby SSS_web.rb
/home/lem/.rvm/wrappers/ruby-2.1.5/ruby SSS_param.rb "LD31 Competition is Over! Post Games to Rate" "ld31.html"
/home/lem/.rvm/wrappers/ruby-2.1.5/ruby SSS_param.rb "title:'End of 2014 Show us your game progress'" "eo2014.html"

