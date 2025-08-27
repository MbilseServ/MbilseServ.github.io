#!/usr/bin/env bash

echo "Hello!"

echo ""
echo "Install App"
echo ""
printf "Do you want to continue? (y/n) "
  read -r ans
  if [ "$ans" != "y" ]; then
    echo "Error Installation aborted."
    exit 0
  fi