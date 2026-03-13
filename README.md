# 🚀 RV32IM Pipelined Processor Core

## 📖 Overview
This repository contains the progressive implementation of a 32-bit RISC-V processor core (RV32IM ISA) developed from scratch in Verilog HDL. The project evolved through multiple architectural stages, culminating in a 5-stage pipelined processor with data and control hazard resolution. The design was synthesized, simulated, and verified using Xilinx Vivado, targeting the Arty-Z7 FPGA board.


## ✨ Key Features
* **5-Stage Pipeline Architecture:** Implements Instruction Fetch (IF), Instruction Decode (ID), Execute (EX), Memory (MEM), and Write Back (WB) stages.
* **Hazard Resolution:** Developed a robust Hazard Unit and Data Forwarding mechanisms to resolve data dependencies and control hazards (branching) efficiently.
* **Custom Arithmetic Units:** Integrates a hierarchical 32-bit Carry Look-ahead Adder (CLA) and an 8-stage pipelined divider for optimized arithmetic throughput.
* **Iterative Design Progression:**
  * `Lab 1`: Basic Logic & FSM (e.g., Traffic Light Controller).
  * `Lab 2`: Carry Look-ahead Adder (CLA) & RISC-V Assembly.
  * `Lab 3`: Single-Cycle Datapath.
  * `Lab 4`: Multi-Cycle Datapath & Pipelined Divider.
  * `Lab 5`: Full 5-Stage Pipelined RV32IM Core.

## 🛠 Tech Stack
* **Hardware Description Language:** Verilog HDL
* **EDA Tool & Simulation:** Xilinx Vivado (RTL Simulation, Synthesis, Waveform Analysis)
* **Target Hardware:** Arty-Z7 FPGA Board (Zynq-7000)

## ⚙️ How to Run / Simulate

1. **Clone this repository:**
```bash
git clone [https://github.com/VUONG2353345/RV32IM-Pipelined-Processor-Core.git](https://github.com/VUONG2353345/RV32IM-Pipelined-Processor-Core.git)
```

2. **Open in Vivado:**
* Launch Xilinx Vivado and create a new RTL project.
* Add the Verilog source files (`.v`) from the specific Lab folder (e.g., `Lab5/`) to your Design Sources.
* Add the constraint file `Arty-Z7-20-Master.xdc` if you intend to generate a bitstream for the FPGA.

3. **Run RTL Simulation:**
* Add the corresponding testbench file (e.g., `tb_traffic_light.v` for Lab 1, or the processor testbench for Lab 5) to your Simulation Sources.
* Click **Run Simulation** -> **Run Behavioral Simulation**.
* Review the timing waveform and check the Tcl Console for `$display` output logs.
