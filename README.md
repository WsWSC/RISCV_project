# risc_v_project
3-stage Pipeline RISC-V CPU Implementation

本專案為一個以 Verilog HDL 實作的 **3-stage Pipeline RISC-V 處理器核心**，  
重點在於實作並理解 Pipeline CPU 的 **資料路徑（Datapath）** 與  
**控制流程（Control Flow）**。

---

## Table of Contents

- [Architecture](#architecture)
- [Pipeline Stages](#pipeline-stages)
  - [IF — Instruction Fetch](#1-if--instruction-fetch)
  - [ID — Instruction Decode / Register Read](#2-id--instruction-decode--register-read)
  - [EX — Execute / Memory / Write Back](#3-ex--execute--memory--write-back)
- [Implementation Status](#implementation-status)
- [Repository Layout](#repository-layout)
- [Reference](#reference)

---

## Architecture

![RISC-V Pipeline](img/Architecture.drawio.png)

本處理器核心採用 **3-stage pipeline 架構**，  
將指令執行流程劃分為 IF、ID 與 EX 三個階段，  
以在維持架構清楚的前提下，實現基本的 pipeline 指令並行能力。

---

## Pipeline Stages

### 1. IF — Instruction Fetch
- 由 Program Counter（PC）提供指令位址
- 從 Instruction Memory 讀取指令
- 計算並更新下一個 PC 值（例如 PC + 4）

### 2. ID — Instruction Decode / Register Read
- 解碼指令的 opcode 與 funct 欄位
- 從 Register File 讀取來源暫存器（rs1 / rs2）
- 產生對應的控制訊號，並傳遞至後續 pipeline stage

### 3. EX — Execute / Memory / Write Back
- 由 ALU 執行算術、邏輯與比較運算
- 依指令類型進行 Load / Store 的資料記憶體存取
- 將運算結果或記憶體讀取結果寫回 Register File

> 本設計將 **Execute、Memory Access 與 Write Back**  
> 整合於同一個 pipeline stage，  
> 以維持整體 pipeline 為三階段結構，並降低控制邏輯複雜度。

---

## Implementation Status

目前已完成的功能：
- 3-stage pipeline 基本資料路徑（IF / ID / EX）
- 基本 RISC-V 指令執行流程
- Pipeline stage 間的暫存器切分

尚未完成，但已於架構上預留之功能：
- Pipeline hazard detection 與 stall 控制
- Data forwarding 機制
- Branch 指令相關的 pipeline flush 控制

---

## Repository Layout

- `rtl/` ：RISC-V CPU 核心 RTL（Verilog）實作  
- `tb/`  ：測試平台（Testbench）  
- `img/` ：架構圖與相關圖片  

---

## Reference

本專案在架構設計與實作過程中，參考以下相關研究與開源專案：

[1] SI-RISCV Project,  
    *e200 Open Source RISC-V Core*,  
    https://github.com/SI-RISCV/e200_opensource.git
