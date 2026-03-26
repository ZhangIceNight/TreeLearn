#!/bin/bash
SRC15="/home/zwj/tmp/alldatas/dataverse_files_15"
SRC30="/home/zwj/tmp/alldatas/dataverse_files_30"
DST="/home/zwj/code/TreeLearn/data"

# ===== dataverse_files_15: LAUTx 完整数据集 =====
mkdir -p "$DST/LAUTx/original"
mkdir -p "$DST/LAUTx/voxelized"
cp "$SRC15/LAUTx/original/"*.laz "$DST/LAUTx/original/"
cp "$SRC15/LAUTx/voxelized/"*.laz "$DST/LAUTx/voxelized/"

# pipeline 工作目录（原始 p14）
mkdir -p "$DST/pipeline/LAUTx_p14/forest"
cp "$DST/LAUTx/original/p14.laz" "$DST/pipeline/LAUTx_p14/forest/"

# ground truth（voxelized p14）
cp "$DST/LAUTx/voxelized/p14_vox0.1.laz" "$DST/benchmark/"

# ===== dataverse_files_30: 主数据包 =====

# 补充模型权重
cp "$SRC30/model_weights/model_weights_dirty.pth" "$DST/model_weights/"
cp "$SRC30/model_weights/model_weights_finetuned.pth" "$DST/model_weights/"
cp "$SRC30/model_weights/model_weights_diverse_training_data.pth" "$DST/model_weights/"

# benchmark L1W 完整版（L1W_voxelized01_for_eval.laz 已有，补其他两个）
cp "$SRC30/benchmark_dataset/L1W.laz" "$DST/benchmark/"
cp "$SRC30/benchmark_dataset/L1W_voxelized01.laz" "$DST/benchmark/"

# 自动分割训练数据
mkdir -p "$DST/automatically_segmented_data"
cp "$SRC30/automatically_segmented_data/"*.laz "$DST/automatically_segmented_data/"

# extras
mkdir -p "$DST/extras"
cp "$SRC30/extras/plot7_cut.laz" "$DST/extras/"
cp "$SRC30/extras/evaluated_trees.txt" "$DST/extras/"

echo "done"
