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
    echo "Working..."
    sleep 0.5
    curl -fsSL https://mbilseserv.github.io/mbilseshapp/mbilse > $PREFIX/bin/mbilse
    chmod +x $PREFIX/bin/mbilse
    ln -s $PREFIX/bin/mbilse $PREFIX/bin/m
    ln -s $PREFIX/bin/mbilse $PREFIX/bin/mle
    
    curl -fsSL https://mbilseserv.github.io/mbilseshapp/mle > $PREFIX/bin/mle
  ;;
  n|N|no|NO|"")
    echo "No"
  ;;
  *)
    echo "No"
  ;;
esac