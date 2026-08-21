#!/usr/bin/env bash
  



echo "Hello!"
sleep 0.2
echo ""
echo "Install Mbilse CLI and all Mbilse commands."
sleep 0.3
echo ""

printf "Do you want to continue? (y/n) "
# 从终端读输入，而不是从管道 stdin
read cont < /dev/tty

case "$cont" in
  y|Y|yes|YES)
    echo "Working..."
    sleep 0.5
    echo "主命令要被安装..."
    curl -fsSL https://mbilseserv.github.io/mbilseshapp/mbilse > $PREFIX/bin/mbilse
    chmod +x $PREFIX/bin/mbilse
    echo "主命令的链接要被设置..."
    ln -s $PREFIX/bin/mbilse $PREFIX/bin/m
    ln -s $PREFIX/bin/mbilse $PREFIX/bin/mie
    ln -s $PREFIX/bin/mbilse $PREFIX/bin/Mbilse
    ln -s $PREFIX/bin/mbilse $PREFIX/bin/MBILSE
    echo "imgzip要被安装..."
    curl -fsSL https://mbilseserv.github.io/mbilseshapp/imgzip > $PREFIX/bin/imgzip
    chmod +x $PREFIX/bin/imgzip
    echo "setup.sh要被安装..."
    curl -fsSL https://mbilseserv.github.io/mbilseshapp/setup.sh > $PREFIX/bin/setup.sh
    chmod +x $PREFIX/bin/setup.sh
    echo "askai要被安装..."
    curl -fsSL https://mbilseserv.github.io/mbilseshapp/askai > $PREFIX/bin/askai
    chmod +x $PREFIX/bin/askai
    echo "WebDrop要被安装..."
    curl -fsSL https://mbilseserv.github.io/mbilseshapp/webdrop > $PREFIX/bin/webdrop
    chmod +x $PREFIX/bin/webdrop
    echo "WebDrop-GTK要被安装..."
    curl -fsSL https://mbilseserv.github.io/mbilseshapp/webdrop-gtk > $PREFIX/bin/webdrop-gtk
    chmod +x $PREFIX/bin/webdrop-gtk
    echo "Webdrop-gtk的链接要被设置..."
    ln -s $PREFIX/bin/webdrop-gtk $PREFIX/bin/webdropk
    echo "软件包管理MLE要被安装..."
    curl -fsSL https://mbilseserv.github.io/mbilseshapp/mle > $PREFIX/bin/mle
    chmod +x $PREFIX/bin/mle
    echo "MSH要被安装..."
    curl -fsSL https://mbilseserv.github.io/mbilseshapp/msh > $PREFIX/bin/msh
    chmod +x $PREFIX/bin/msh
    echo "dater要被安装..."
    curl -fsSL https://mbilseserv.github.io/mbilseshapp/dater > $PREFIX/bin/dater
    chmod +x $PREFIX/bin/dater
    echo "DotDrop要被安装..."
    curl -fsSL https://mbilseserv.github.io/mbilseshapp/dotdrop > $PREFIX/bin/dotdrop
    chmod +x $PREFIX/bin/dotdrop
    echo "SecTrans要被安装..."
    curl -fsSL https://mbilseserv.github.io/mbilseshapp/sectrans > $PREFIX/bin/sectrans
    chmod +x $PREFIX/bin/sectrans
    echo "MbilseApps要被安装..."
    curl -fsSL https://mbilseserv.github.io/mbilseshapp/mbilseapps > $PREFIX/bin/mbilseapps
    chmod +x $PREFIX/bin/mbilseapps
    
    echo "All OKay."
  ;;
  n|N|no|NO|"")
    echo "Install Failed UserCanceled."
  ;;
  *)
    echo "Error Failed."
  ;;
esac
