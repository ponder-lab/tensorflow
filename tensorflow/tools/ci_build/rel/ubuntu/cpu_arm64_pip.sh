#!/bin/bash
# Copyright 2022 The TensorFlow Authors. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ==============================================================================

set -e
set -x

source tensorflow/tools/ci_build/release/common.sh

# Update bazel
install_bazelisk

# Env vars used to avoid interactive elements of the build.
export HOST_C_COMPILER=(which gcc)
export HOST_CXX_COMPILER=(which g++)
export TF_ENABLE_XLA=1
export TF_DOWNLOAD_CLANG=0
export TF_SET_ANDROID_WORKSPACE=0
export TF_NEED_MPI=0
export TF_NEED_ROCM=0
export TF_NEED_GCP=0
export TF_NEED_S3=0
export TF_NEED_OPENCL_SYCL=0
export TF_NEED_CUDA=0
export TF_NEED_HDFS=0
export TF_NEED_OPENCL=0
export TF_NEED_JEMALLOC=1
export TF_NEED_VERBS=0
export TF_NEED_AWS=0
export TF_NEED_GDR=0
export TF_NEED_OPENCL_SYCL=0
export TF_NEED_COMPUTECPP=0
export TF_NEED_KAFKA=0
export TF_NEED_TENSORRT=0

# Export required variables for running pip_new.sh
export OS_TYPE="UBUNTU"
export CONTAINER_TYPE="CPU"

# Get the default test targets for bazel.
source tensorflow/tools/ci_build/build_scripts/DEFAULT_TEST_TARGETS.sh

# Set python version string
py_ver=$(python -c 'import sys; print(str(sys.version_info.major)+str(sys.version_info.minor))')

# Export optional variables for running pip_new.sh
export TF_BUILD_FLAGS="--config=mkl_aarch64_threadpool --copt=-mtune=generic --copt=-march=armv8-a \
    --copt=-O3 --copt=-flax-vector-conversions"
export TF_TEST_FLAGS="${TF_BUILD_FLAGS} \
    --test_env=TF_ENABLE_ONEDNN_OPTS=1 --test_env=TF2_BEHAVIOR=1 --define=no_tensorflow_py_deps=true \
    --test_lang_filters=py --flaky_test_attempts=3 --test_size_filters=small,medium --verbose_failures=true --test_keep_going"
export TF_TEST_TARGETS="${DEFAULT_BAZEL_TARGETS} \
    -//tensorflow/lite/... \
    -//tensorflow/python:nn_grad_test \
    -//tensorflow/python/client:session_list_devices_test \
    -//tensorflow/python/data/kernel_tests:iterator_test_cpu \
    -//tensorflow/python/data/kernel_tests:iterator_test_gpu \
    -//tensorflow/python/eager:forwardprop_test \
    -//tensorflow/python/kernel_tests/array_ops:array_ops_test_cpu \
    -//tensorflow/python/kernel_tests/array_ops:array_ops_test_gpu \
    -//tensorflow/python/kernel_tests/array_ops:concat_op_test_cpu \
    -//tensorflow/python/kernel_tests/array_ops:concat_op_test_gpu \
    -//tensorflow/python/kernel_tests/array_ops:pad_op_test_cpu \
    -//tensorflow/python/kernel_tests/array_ops:pad_op_test_gpu \
    -//tensorflow/python/kernel_tests/array_ops:slice_op_test_cpu \
    -//tensorflow/python/kernel_tests/array_ops:slice_op_test_gpu \
    -//tensorflow/python/kernel_tests/array_ops:split_op_test_cpu \
    -//tensorflow/python/kernel_tests/array_ops:split_op_test_gpu \
    -//tensorflow/python/kernel_tests/control_flow:scan_ops_test_cpu \
    -//tensorflow/python/kernel_tests/control_flow:scan_ops_test_gpu \
    -//tensorflow/python/kernel_tests/linalg:linear_operator_householder_test \
    -//tensorflow/python/kernel_tests/linalg:linear_operator_inversion_test \
    -//tensorflow/python/kernel_tests/linalg:linear_operator_block_diag_test \
    -//tensorflow/python/kernel_tests/linalg:linear_operator_block_lower_triangular_test \
    -//tensorflow/python/kernel_tests/linalg:linear_operator_kronecker_test \
    -//tensorflow/python/kernel_tests/math_ops:batch_matmul_op_test \
    -//tensorflow/python/kernel_tests/nn_ops:conv_ops_test \
    -//tensorflow/python/kernel_tests/nn_ops:conv2d_backprop_filter_grad_test \
    -//tensorflow/python/kernel_tests/nn_ops:atrous_conv2d_test \
    -//tensorflow/python/ops/parallel_for:math_test \
    -//tensorflow/python/training:server_lib_test"
export TF_PIP_TESTS="test_pip_virtualenv_clean"
export TF_TEST_FILTER_TAGS="-nopip,-no_pip,-no_oss,-oss_serial,-v1only,-benchmark-test,-no_aarch64"
export TF_PIP_TEST_ROOT="pip_test"
export TF_AUDITWHEEL_TARGET_PLAT="manylinux2014"

if [ ${IS_NIGHTLY} == 1 ]; then
  ./tensorflow/tools/ci_build/update_version.py --nightly
fi

source tensorflow/tools/ci_build/builds/pip_new.sh

# remove duplicate wheel and copy wheel to mounted volume for local access
rm -rf /tensorflow/pip_test/whl/*linux_aarch64.whl && cp -r /tensorflow/pip_test/whl .
