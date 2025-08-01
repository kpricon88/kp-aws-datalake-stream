#!/bin/bash
set -e

cd lambdas
for dir in */ ; do
  cd "$dir"
  zip -r "../../packages/${dir%/}.zip" .
  cd ..
done
cd ..
echo "Zipped all Lambda functions to /packages"
