#! /bin/bash

if [[  $(sqlite3 cache.sqlite 'pragma integrity_check') == ok  ]]
then
  cp cache.sqlite cache.backup.sqlite
  echo "DB SAFE, BACKING UP"
else
  echo "DB CORRUPTED, RESTORING FROM BACKUP"
  cp cache.backup.sqlite cache.sqlite
fi
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
pwd
cd $DIR
pwd
git pull
/home/lem/.rvm/wrappers/ruby-2.1.5/ruby SSS_param.rb
#/home/lem/.rvm/wrappers/ruby-2.1.5/ruby SSS_param.rb -q "title:'End of 2014 Show us your game progress'" -o "eo2014.html"

