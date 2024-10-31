#!/bin/bash

cwd=$PWD
cd subprojects/fcio/src
# autopxd fcio.h > ${cwd}/src/fcio/cy_fcio/fcio_def.pxd
# fcio_utils.h includes fcio.h
autopxd fcio_utils.h > ${cwd}/src/fcio/cy_fcio/fcio_def.pxd
