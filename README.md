[English](#english) | [繁體中文](#繁體中文)

---

<span id="繁體中文"></span>

# Illumio VEN Agent 自動化部署指南

本專案提供跨平台 (Windows / Linux / AIX) 的 Illumio VEN Agent 自動化部署腳本及手冊。所有腳本都已包含**自簽憑證自動匯入**與**防重複檢查**機制，確保 VEN 能夠順利與 PCE 建立安全連線。

我們提供兩種不同的部署方式，請根據您的環境需求選擇適合的方式：

## 目錄結構與部署方式選擇

### 🌟 方式一：官方配對腳本 (建議)
> 適用情境：目標主機能直接連線至 PCE，且您希望使用 Illumio 官方內建的配對腳本 (`pair.ps1` / `pair.sh` / `pair.aix.sh`)。本專案提供腳本為您處理「憑證匯入」與「相依套件檢查」的前置作業。

*   **Windows** (`method1_pairing/windows/`)
    *   📄 [操作手冊](method1_pairing/windows/README.md)
    *   🛠️ `Import-RootCA.ps1`: 前置作業 — 自動匯入 CA 憑證 (以 Thumbprint 防重複)
*   **Linux** (`method1_pairing/linux/`)
    *   📄 [操作手冊](method1_pairing/linux/README.md)
    *   🛠️ `prepare-and-pair.sh`: 前置作業 — OS偵測 / 套件檢查 / 憑證匯入 (內容比對防重複)
*   **AIX** (`method1_pairing/aix/`)
    *   📄 [操作手冊](method1_pairing/aix/README.md)

---

### 🔧 方式二：手動安裝與回報腳本
> 適用情境：封閉環境、需要自訂安裝目錄，或需使用實體安裝包 (`.exe` / `.rpm` / `.deb` / `installp`) 部署。本專案提供「安裝 + 憑證匯入 + 啟用回報」一鍵到底的自製化腳本。

*   **Windows** (`method2_manual/windows/`)
    *   📄 [操作手冊](method2_manual/windows/README.md)
    *   🛠️ `Deploy-Illumio.ps1`: 完整部署腳本 (PowerShell 版，支援傳入自訂安裝目錄參數)
    *   🛠️ `deploy-illumio.bat`: 完整部署腳本 (Batch 版，動態 Hash 憑證防重複檢查)
*   **Linux** (`method2_manual/linux/`)
    *   📄 [操作手冊](method2_manual/linux/README.md)
    *   🛠️ `deploy-illumio.sh`: 完整部署腳本 (OS偵測 / 缺件即停 / 憑證匯入 / rpm&dpkg安裝 / 啟用)
*   **AIX** (`method2_manual/aix/`)
    *   📄 [操作手冊 (含 IPFilter)](method2_manual/aix/README.md)

---

## 🚀 快速開始

1. 取得 PCE 簽發的 **CA 憑證** (`illumio-ca.crt`)。
2. 取得一組有效的 **Activation Code** 與您的 **PCE FQDN:PORT** (例如 `pce.example.com:8443`)。
3. **重要**：使用前，請打開您要使用的腳本 (`.ps1`, `.sh`, `.bat`)，將其中的憑證內容 (`-----BEGIN CERTIFICATE-----...`) 替換為您的環境憑證，並將 `<YOUR_ACTIVATION_CODE>` 取代為實際值。所有腳本都搭載了**動態指紋檢查技術**，替換憑證內容後會自動比對新指紋，無需手動設定 Thumbprint。

---

<br><br><br>

<span id="english"></span>

# Illumio VEN Agent Automated Deployment Guide

[English](#english) | [繁體中文](#繁體中文)

---

This project provides cross-platform (Windows / Linux / AIX) automated deployment scripts and manuals for the Illumio VEN Agent. All scripts include mechanisms for **automatic self-signed certificate import** and **duplicate prevention**, ensuring the VEN can establish a secure connection with the PCE.

We provide two different deployment methods. Please choose the method that best suits your environment's requirements:

## Directory Structure & Deployment Methods

### 🌟 Method 1: Official Pairing Scripts (Recommended)
> **Use Case**: Target hosts can connect directly to the PCE, and you want to use Illumio's official pairing scripts (`pair.ps1` / `pair.sh` / `pair.aix.sh`). This project provides scripts to handle the prerequisites ("Certificate Import" and "Dependency Checks") before running the pairing sequence.

*   **Windows** (`method1_pairing/windows/`)
    *   📄 [User Manual](method1_pairing/windows/README.md)
    *   🛠️ `Import-RootCA.ps1`: Prerequisite — Auto-imports CA cert (Duplicate prevention via Thumbprint)
*   **Linux** (`method1_pairing/linux/`)
    *   📄 [User Manual](method1_pairing/linux/README.md)
    *   🛠️ `prepare-and-pair.sh`: Prerequisite — OS Detection / Dependency Check / Cert Import (Content matching)
*   **AIX** (`method1_pairing/aix/`)
    *   📄 [User Manual](method1_pairing/aix/README.md)

---

### 🔧 Method 2: Manual Installation & Activation Scripts
> **Use Case**: Offline environments, requirement for custom installation directories, or deployment using physical installation packages (`.exe` / `.rpm` / `.deb` / `installp`). This project provides all-in-one custom scripts covering "Installation + Cert Import + Activation".

*   **Windows** (`method2_manual/windows/`)
    *   📄 [User Manual](method2_manual/windows/README.md)
    *   🛠️ `Deploy-Illumio.ps1`: Full deployment script (PowerShell, supports custom directory parameters)
    *   🛠️ `deploy-illumio.bat`: Full deployment script (Batch, dynamic Hash calculation for duplicate prevention)
*   **Linux** (`method2_manual/linux/`)
    *   📄 [User Manual](method2_manual/linux/README.md)
    *   🛠️ `deploy-illumio.sh`: Full deployment (OS Detect / Stop-on-missing dependencies / Cert Import / rpm&dpkg / Activate)
*   **AIX** (`method2_manual/aix/`)
    *   📄 [User Manual (inc. IPFilter)](method2_manual/aix/README.md)

---

## 🚀 Quick Start

1. Obtain the **CA Certificate** (`illumio-ca.crt`) issued by your PCE.
2. Obtain a valid **Activation Code** and your **PCE FQDN:PORT** (e.g., `pce.example.com:8443`).
3. **IMPORTANT**: Before using any script (`.ps1`, `.sh`, `.bat`), open it in a text editor and replace the embedded certificate content (`-----BEGIN CERTIFICATE-----...`) with your environment's certificate. Also, replace `<YOUR_ACTIVATION_CODE>` and management server placeholders with actual values. All scripts are equipped with **Dynamic Fingerprint Validation**, meaning they will automatically calculate the hash of the newly pasted certificate for duplicate prevention without requiring any manual Thumbprint configuration.
