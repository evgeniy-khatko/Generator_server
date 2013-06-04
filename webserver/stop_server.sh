#! /bin/bash
for WORD in `cat server.pid`
do
   kill $WORD
done
