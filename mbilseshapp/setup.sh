#!/usr/bin/env bash
                                                      echo "Hello!"
sleep 0.2
echo ""
echo "Install App"
sleep 0.3
echo ""

printf "Do you want to continue? (y/n) "
# 从终端读输入，而不是从管道 stdin
read cont < /dev/tty

case "$cont" in
  y|Y|yes|YES)
    echo "OK"
  ;;
  n|N|no|NO|"")
    echo "No"
  ;;
  *)
    echo "请输入 y 或 n"
  ;;
esac