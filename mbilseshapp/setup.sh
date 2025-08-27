#!/usr/bin/env bash

echo "Hello!"
sleep 0.2
echo ""
echo "Install App"
sleep 0.3
echo ""

  printf "Do you want to continue? (y/n) "
  read cont
  cont=${cont,,}   # 转小写
  case $cont in
    y|yes)
      echo "OK"
      break
    ;;
    n|no)
      echo "No"
      break
    ;;
    *)
      echo "请输入 y 或 n."
    ;;
  esac