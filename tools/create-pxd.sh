#!/bin/bash

echo Requires autopxd, install with: \"python3 -m pip install autopxd2\"
autopxd externals/fcio/src/fcio.h src/fcio/cy_fcio/cfcio.pxd
echo Existing src/fcio/cy_fcio/cfcio.pxd has been overwritten. Careful before committing any changes.
