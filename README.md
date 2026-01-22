# risc_v_project
3-stage Pipeline RISC-V CPU Implementation

本專案為一個以 Verilog HDL 實作的 **3-stage Pipeline RISC-V 處理器核心**，  
重點在於實作並理解 Pipeline CPU 的 Datapath 與控制流 Control Flow 。

---

## Architecture

![RISC-V Pipeline](img/Architecture.drawio.png)

本處理器核心採用 **3-stage pipeline 架構**，  
將指令執行流程切分為 IF、ID 與 EX 三個階段，以提升指令吞吐量並清楚呈現 pipeline 行為。

---

## Pipeline Stages

### 1. IF — Instruction Fetch
- 由 Program Counter（PC）提供指令位址
- 從 Instruction Memory 讀取指令
- 計算並更新下一個 PC 值（如 PC + 4）

### 2. ID — Instruction Decode / Register Read
- 解碼指令 opcode 與 funct 欄位
- 從 Register File 讀取來源暫存器（rs1 / rs2）
- 產生對應的控制訊號，供後續 pipeline stage 使用

### 3. EX — Execute / Memory / Write Back
- 由 ALU 執行算術、邏輯與比較運算
- 進行 Load / Store 指令的資料記憶體存取
- 將運算結果或記憶體讀取結果寫回 Register File

> 本設計將 **Execute 與 Write Back** 整合於同一 pipeline stage，  
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

- `rtl/`    ：RISC-V CPU 核心 RTL（Verilog）實作
- `tb/`     ：測試平台（Testbench）
- `img/`    ：相關圖片
