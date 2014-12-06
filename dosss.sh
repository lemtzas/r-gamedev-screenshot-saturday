#! /bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
pwd
cd $DIR
pwd
git pull
$rvm_path/wrappers/ruby-2.1.5/ruby SSS_web.rb

