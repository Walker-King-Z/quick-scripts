#!/bin/bash

# ==========================================
# Mushroom Classification Ascend Project
# Directory Initialization Script
# ==========================================

set -e

PROJECT_NAME="mushroom_cls_ascend"

echo "Creating project directory structure..."

# root
mkdir -p $PROJECT_NAME

# models
mkdir -p $PROJECT_NAME/models

# metadata
mkdir -p $PROJECT_NAME/metadata

# samples
mkdir -p $PROJECT_NAME/samples/single
mkdir -p $PROJECT_NAME/samples/batch

# outputs
mkdir -p $PROJECT_NAME/outputs/single
mkdir -p $PROJECT_NAME/outputs/batch
mkdir -p $PROJECT_NAME/outputs/vis

# app
mkdir -p $PROJECT_NAME/app/infer
mkdir -p $PROJECT_NAME/app/core
mkdir -p $PROJECT_NAME/app/common

# scripts
mkdir -p $PROJECT_NAME/scripts

# README placeholder
touch $PROJECT_NAME/README.md

echo "Directory structure created successfully!"

echo ""
echo "Project structure:"
tree $PROJECT_NAME || ls -R $PROJECT_NAME