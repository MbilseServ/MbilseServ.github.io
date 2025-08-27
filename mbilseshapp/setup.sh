#!/usr/bin/env bash

echo "Hello!"
sleep 0.2
echo ""
echo "Install App"
sleep 0.3
echo ""
printf "Do you want to continue? (y/n) "
  read -r ans
  if [ "$ans" != "y" ]; then
    echo "Error Installation aborted."
    exit 0
  fi
 echo "OK"