# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

TreeLearn 是一个基于深度学习的森林点云单树实例分割方法。核心组件包括：
- 稀疏卷积 U-Net 骨干网络（基于 spconv）
- 双预测头：语义分割（树/非树）+ 偏移向量预测
- 聚类算法（DBSCAN/HDBSCAN）在偏移后的坐标上检测单树
- 自动分块生成用于处理大型森林

## 常用开发命令

### 环境安装
```bash
# 创建 conda 环境（会先删除已存在的同名环境）
source setup/setup.sh
```

### 推理（分割管线）
```bash
# 树分割的主入口
python tools/pipeline/pipeline.py --config configs/pipeline/pipeline.yaml
```

### 训练
```bash
# 从已分割的点云生成训练数据
python tools/data_gen/gen_train_data.py --config configs/data_gen/gen_train_data.yaml

# 生成验证数据
python tools/data_gen/gen_val_data.py --config configs/data_gen/gen_val_data.yaml

# 训练模型
python tools/training/train.py --config configs/training/train.yaml
```

### 评估
```bash
# 评估分割结果与真值对比
python tools/evaluation/evaluate.py --config configs/evaluation/evaluate.yaml
```

### 下载数据集和权重
```bash
# 下载预训练模型权重
python tree_learn/util/download.py --dataset_name model_weights_20241213 --root_folder data/model_weights

# 下载基准数据集
python tree_learn/util/download.py --dataset_name benchmark_dataset --root_folder data/pipeline/L1W/forest
```

## 架构概览

### 管线流程 (`tools/pipeline/pipeline.py`)
1. **数据预处理**：加载森林点云、中心化坐标、体素化
2. **分块生成**：创建重叠分块以处理大型森林
3. **逐点预测**：运行模型获取语义和偏移预测
4. **集成融合**：合并重叠分块的预测结果
5. **聚类**：将偏移后的坐标聚合成树实例（DBSCAN/HDBSCAN）
6. **后处理**：分配剩余点，可选地移除边缘点
7. **传播映射**：将预测映射回原始点云

### 核心组件

**模型** (`tree_learn/model/tree_learn.py`)
- 基于 spconv 的稀疏卷积 U-Net 骨干网络
- 双预测头：语义（树 vs 非树）和偏移向量
- 可配置的体素化（默认 0.1m）

**管线工具** (`tree_learn/util/pipeline.py`)
- `generate_tiles()`: 创建可配置步长的重叠分块
- `get_pointwise_preds()`: 运行模型推理
- `ensemble()`: 合并重叠分块的预测
- `get_instances()`: 使用 DBSCAN/HDBSCAN 对偏移后的坐标聚类
- `propagate_preds()`: 将预测映射到原始/体素化点云

**数据准备** (`tree_learn/util/data_preparation.py`)
- `load_data()`: 从 las、laz、npy、npz、txt 格式加载点云
- `voxelize()`: 基于网格的体素化，使用哈希映射追踪原始点
- `compute_features()`: 计算垂直度等特征

## 配置系统

项目使用模块化 YAML 配置。主要配置文件：
- `configs/pipeline/pipeline.yaml`: 主推理管线配置
- `configs/_modular_/grouping.yaml`: 聚类参数（tau_min、tau_group、use_hdbscan）
- `configs/_modular_/model.yaml`: 模型架构参数
- `configs/_modular_/sample_generation.yaml`: 体素化和分块生成

### 关键配置参数

**推理配置 (pipeline.yaml)：**
- `forest_path`: 输入点云路径
- `pretrain`: 模型权重路径
- `save_cfg.return_type`: 'original'（默认）、'voxelized' 或 'voxelized_and_filtered'
- `shape_cfg.outer_remove`: 边缘缓冲区移除距离（米）

**聚类配置 (grouping.yaml)：**
- `grouping.tau_min`: 有效树簇的最小点数
- `grouping.tau_group`: 聚类半径（仅 DBSCAN）
- `grouping.use_hdbscan`: 使用 HDBSCAN（单参数）vs DBSCAN（双参数）
- `grouping.tree_conf_thresh`: 树点的语义置信度阈值
- `grouping.tau_vert`: 聚类的最小垂直度
- `grouping.tau_off`: 聚类的最大偏移量

**分块生成配置 (sample_generation.yaml)：**
- `sample_generation.voxel_size`: 体素大小（默认 0.1m）
- `inner_edge`/`outer_edge`: 分块填充大小
- `stride`: 分块之间的步长

## 数据格式要求

### 输入森林点云
- 支持格式：.las、.laz、.npy、.npz、.txt
- 坐标：米制，最小分辨率每 (0.1m)³ 一个点
- 必须包含树干点（对树检测至关重要）
- 包含地形和低植被点
- 推荐：在感兴趣区域周围保留 13.5m 缓冲区

### 输出格式
- 森林：laz、las、npz、npy、txt（可配置）
- 单树：las 格式（按树 ID 着色）
- 标签：0 = 非树，1+ = 树 ID

## 硬件要求

- **VRAM**：推理约 10 GB
- **RAM**：处理大型点云时峰值约 100 GB（分块生成阶段）
- **GPU**：CUDA 兼容（spconv 需要特定 CUDA 版本）

## 关键实现细节

- **坐标中心化**：管线自动中心化高幅度坐标并在结果中反中心化
- **基于哈希的传播**：使用哈希值高效地将体素化预测映射回原始点
- **凹包计算**：使用 alphashape 计算森林轮廓（alpha=0 为凸包，alpha=0.6 为凹包）
- **边缘树处理**：将树分类为完全内部、树干基部内部或树干基部外部
- **缓冲区移除**：可选的自动边缘点移除，此处预测可靠性较低

## 已知限制

- 需要高分辨率树干（可能不适用于 ALS 数据）
- 未针对运行时优化（CPU 操作通常未并行化）
- 大型森林的分块生成 RAM 密集
- 训练 25000 个分块需要约 700GB 存储空间

## 代码约定

- 配置使用 `munch` 库进行属性访问：`config.forest_path`
- `tree_learn/util/pipeline.py` 中的 `N_JOBS=10` 控制多处理线程数
- TreeLearn 模型使用 `spconv` 稀疏卷积（非标准 PyTorch 卷积）
- 数据集中的语义类别：0 = 树，1 = 非树（在聚类时反转）
