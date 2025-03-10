/* Copyright 2022 The TensorFlow Authors. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
==============================================================================*/
include "mlir/IR/OpBase.td"
include "mlir/IR/PatternBase.td"
include "mlir/Dialect/Func/IR/FuncOps.td"
include "mlir/Dialect/Arithmetic/IR/ArithmeticOps.td"
include "tensorflow/compiler/mlir/tensorflow/ir/tf_ops.td"
include "tensorflow/compiler/mlir/quantization/tensorflow/passes/utils.td"

def CreateXLAConvOpFromTFConv2DOp : NativeCodeCall<
  "CreateXLAConvOpFromTFConv2DOp($_builder, $_loc, $0...)">;

def CreateXLAConvOpFromTFDepthwiseConv2DOp : NativeCodeCall<
  "CreateXLAConvOpFromTFDepthwiseConv2DOp($_builder, $_loc, $0...)">;

// Converts inlined Conv2D pattern to TF XlaConvV2 op. This pattern doesn't
// support non-constant weights or large weights (where the constant folding
// fails).
def ConvertTFConv2DToXLAConvOp : Pat<
  (TF_Conv2DOp:$conv
    (TF_SubOp (TF_CastOp $input, $truncate), $input_zp),
    (TF_ConstOp:$filter $filter_value),
    $strides, $use_cudnn, $padding, $explicit_padding,
    IsDataFormatNHWC:$data_format, $dilations),
  (CreateXLAConvOpFromTFConv2DOp
    $input, $filter, $input_zp, $conv, $strides,
    $dilations, $padding, $explicit_padding),
  [(IsInt8ElementType $input),
   (IsInt32ElementType $filter),
   (IsInt32ElementType $conv),
   (HasStaticShapeConstraint $filter),
   (HasStaticShapeAtDimsConstraint<"3"> $input)],
  (addBenefit 10)>;

// Same as ConvertTFConv2DToXLAConvOp but handles the case where input zero
// point is 0 and the Sub op has been folded.
def ConvertTFConv2DWithNoZeroPointToXLAConvOp : Pat<
  (TF_Conv2DOp:$conv
    (TF_CastOp $input, $truncate),
    (TF_ConstOp:$filter $filter_value),
    $strides, $use_cudnn, $padding, $explicit_padding,
    IsDataFormatNHWC:$data_format, $dilations),
  (CreateXLAConvOpFromTFConv2DOp
    $input, $filter, /*input_zp=*/(CreateScalarIntegerConst<"int32_t", "0">),
    $conv, $strides, $dilations, $padding, $explicit_padding),
  [(IsInt8ElementType $input),
   (IsInt32ElementType $filter),
   (IsInt32ElementType $conv),
   (HasStaticShapeConstraint $filter),
   (HasStaticShapeAtDimsConstraint<"3"> $input)],
  (addBenefit 10)>;

// Converts inlined DepthwiseConv2D pattern to TF XlaConvV2 op. This pattern
// doesn't support non-constant weights or large weights (where the constant
// folding fails).
def ConvertTFDepthwiseConv2DToXLAConvOp : Pat<
  (TF_CastOp:$conv
    (TF_DepthwiseConv2dNativeOp
      (TF_CastOp:$casted_input
        (TF_SubOp (TF_CastOp $input, $truncate1), $input_zp), $truncate2),
      (TF_CastOp
        (TF_IdentityOp (TF_ConstOp:$filter $filter_value)), $truncate3),
      $strides, $padding, $explicit_padding,
      IsDataFormatNHWC:$data_format, $dilations), $truncate4),
  (CreateXLAConvOpFromTFDepthwiseConv2DOp
    $input, $filter, $input_zp, $conv, $strides,
    $dilations, $padding, $explicit_padding),
  [(IsInt8ElementType $input),
   (IsF32ElementType $casted_input),
   (IsInt32ElementType $filter),
   (IsInt32ElementType $conv),
   (HasStaticShapeConstraint $filter),
   (HasStaticShapeAtDimsConstraint<"3"> $input)],
  (addBenefit 10)>;

// Same as ConvertTFDepthwiseConv2DToXLAConvOp but handles the case where input
// zero point is 0 and the Sub op has been folded.
def ConvertTFDepthwiseConv2DWithNoZeroPointToXLAConvOp : Pat<
  (TF_CastOp:$conv
    (TF_DepthwiseConv2dNativeOp
      (TF_CastOp:$casted_input
        (TF_CastOp $input, $truncate1), $truncate2),
      (TF_CastOp
        (TF_IdentityOp (TF_ConstOp:$filter $filter_value)), $truncate3),
      $strides, $padding, $explicit_padding,
      IsDataFormatNHWC:$data_format, $dilations), $truncate4),
  (CreateXLAConvOpFromTFDepthwiseConv2DOp
    $input, $filter, /*input_zp=*/(CreateScalarIntegerConst<"int32_t", "0">),
    $conv, $strides, $dilations, $padding, $explicit_padding),
  [(IsInt8ElementType $input),
   (IsF32ElementType $casted_input),
   (IsInt32ElementType $filter),
   (IsInt32ElementType $conv),
   (HasStaticShapeConstraint $filter),
   (HasStaticShapeAtDimsConstraint<"3"> $input)],
  (addBenefit 10)>;
