[English](#english) | [繁體中文](#繁體中文)

---

<span id="繁體中文"></span>

# Illumio VEN Agent 自動化部署指南

本專案提供跨平台 (Windows / Linux / AIX) 的 Illumio VEN Agent 自動化部署腳本及手冊。所有腳本都已包含**自簽憑證自動匯入**與**防重複檢查**機制，確保 VEN 能夠順利與 PCE 建立安全連線。

每個作業系統下分為兩種部署方式，請根據您的環境需求選擇適合的方式：

---

## 目錄結構

```
linux/
├── pairing_prereq/    # 方式一：官方配對前置腳本 (憑證匯入 + 套件檢查)
│   ├── README.md
│   └── prepare-and-pair.sh
└── manual_deploy/     # 方式二：完整手動部署腳本 (安裝 + 憑證匯入 + 啟用)
    ├── README.md
    └── deploy-illumio.sh

windows/
├── pairing_prereq/    # 方式一：官方配對前置腳本 (憑證匯入)
│   ├── README.md
│   └── Import-RootCA.ps1
└── manual_deploy/     # 方式二：完整手動部署腳本 (安裝 + 憑證匯入 + 啟用)
    ├── README.md
    ├── Deploy-Illumio.ps1
    └── deploy-illumio.bat

aix/
├── pairing_prereq/    # 方式一：官方配對前置作業說明
│   └── README.md
└── manual_deploy/     # 方式二：完整手動部署說明 (含 IPFilter)
    └── README.md
```

---

## 部署方式說明

### 🌟 方式一：官方配對前置 (`pairing_prereq/`)

> 適用情境：目標主機能直接連線至 PCE，且您希望使用 Illumio 官方內建的配對腳本 (`pair.ps1` / `pair.sh` / `pair.aix.sh`)。
> 本方式的腳本負責處理**前置作業**（憑證匯入、相依套件檢查），完成後再執行官方配對腳本。

### 🔧 方式二：完整手動部署 (`manual_deploy/`)

> 適用情境：封閉環境、需要自訂安裝目錄，或需使用實體安裝包 (`.exe` / `.rpm` / `.deb` / `installp`) 部署。
> 本方式的腳本一鍵完成「憑證匯入 → 安裝 VEN → 啟用回報」全流程。

---

## 各平台操作手冊

| 平台 | 方式一：官方配對前置 | 方式二：完整手動部署 |
|------|---------------------|---------------------|
| **Windows** | [📄 操作手冊](windows/pairing_prereq/README.md) | [📄 操作手冊](windows/manual_deploy/README.md) |
| **Linux** | [📄 操作手冊](linux/pairing_prereq/README.md) | [📄 操作手冊](linux/manual_deploy/README.md) |
| **AIX** | [📄 操作手冊](aix/pairing_prereq/README.md) | [📄 操作手冊](aix/manual_deploy/README.md) |

---

## 🚀 快速開始

1. 取得 PCE 簽發的 **CA 憑證** (`illumio-ca.crt`)。
2. 取得一組有效的 **Activation Code** 與您的 **PCE FQDN:PORT** (例如 `pce.example.com:8443`)。
3. 依平台進入對應目錄，參閱 `README.md` 操作手冊。
4. **重要**：使用前，請打開您要使用的腳本 (`.ps1`, `.sh`, `.bat`)，將其中的憑證內容 (`-----BEGIN CERTIFICATE-----...`) 替換為您的環境憑證，並將 `<YOUR_ACTIVATION_CODE>` 取代為實際值。所有腳本都搭載了**動態指紋檢查技術**，替換憑證內容後會自動比對新指紋，無需手動設定 Thumbprint。

---

<br><br><br>

<span id="english"></span>

# Illumio VEN Agent Automated Deployment Guide

[English](#english) | [繁體中文](#繁體中文)

---

This project provides cross-platform (Windows / Linux / AIX) automated deployment scripts and manuals for the Illumio VEN Agent. All scripts include mechanisms for **automatic self-signed certificate import** and **duplicate prevention**, ensuring the VEN can establish a secure connection with the PCE.

Each platform contains two deployment approaches. Choose the one that best suits your environment:

---

## Directory Structure

```
linux/
├── pairing_prereq/    # Method 1: Pre-pairing prerequisites (cert import + dependency check)
│   ├── README.md
│   └── prepare-and-pair.sh
└── manual_deploy/     # Method 2: Full standalone deployment (install + cert + activate)
    ├── README.md
    └── deploy-illumio.sh

windows/
├── pairing_prereq/    # Method 1: Pre-pairing prerequisites (cert import)
│   ├── README.md
│   └── Import-RootCA.ps1
└── manual_deploy/     # Method 2: Full standalone deployment (install + cert + activate)
    ├── README.md
    ├── Deploy-Illumio.ps1
    └── deploy-illumio.bat

aix/
├── pairing_prereq/    # Method 1: Pre-pairing prerequisites guide
│   └── README.md
└── manual_deploy/     # Method 2: Full standalone deployment guide (incl. IPFilter)
    └── README.md
```

---

## Deployment Methods

### 🌟 Method 1: Pre-Pairing Prerequisites (`pairing_prereq/`)

> **Use Case**: Target hosts can connect directly to the PCE and you want to use Illumio's official pairing scripts (`pair.ps1` / `pair.sh` / `pair.aix.sh`).
> These scripts handle the **prerequisites** (certificate import, dependency checks) before you run the official pairing command.

### 🔧 Method 2: Full Manual Deployment (`manual_deploy/`)

> **Use Case**: Offline environments, custom installation directories, or deployment using physical packages (`.exe` / `.rpm` / `.deb` / `installp`).
> These scripts complete the full flow in one shot: certificate import → VEN installation → activation.

---

## Manuals by Platform

| Platform | Method 1: Pre-Pairing Prereqs | Method 2: Full Manual Deploy |
|----------|-------------------------------|------------------------------|
| **Windows** | [📄 User Manual](windows/pairing_prereq/README.md) | [📄 User Manual](windows/manual_deploy/README.md) |
| **Linux** | [📄 User Manual](linux/pairing_prereq/README.md) | [📄 User Manual](linux/manual_deploy/README.md) |
| **AIX** | [📄 User Manual](aix/pairing_prereq/README.md) | [📄 User Manual](aix/manual_deploy/README.md) |

---

## 🚀 Quick Start

1. Obtain the **CA Certificate** (`illumio-ca.crt`) issued by your PCE.
2. Obtain a valid **Activation Code** and your **PCE FQDN:PORT** (e.g., `pce.example.com:8443`).
3. Navigate to the directory for your platform and consult the `README.md` manual.
4. **IMPORTANT**: Before using any script (`.ps1`, `.sh`, `.bat`), open it in a text editor and replace the embedded certificate content (`-----BEGIN CERTIFICATE-----...`) with your environment's certificate. Also replace `<YOUR_ACTIVATION_CODE>` and management server placeholders with actual values. All scripts are equipped with **Dynamic Fingerprint Validation** — no manual Thumbprint configuration required.
