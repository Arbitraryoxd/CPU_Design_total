# CPU_Design_total

基于 Verilog 的 32 位 MIPS 双发射流水线 CPU 与 SoC FPGA 工程。处理器采用按序发射、按序提交的两路超标量结构，目标器件为 Xilinx Artix-7 `xc7a35tfgg484-2`，Vivado 工程版本为 2018.3。

## CPU 架构

- 五级流水线：取指（IF）、译码（ID）、执行（EX）、访存（MEM）、写回（WB）
- 两套 `ID/EX/EX/MEM/MEM_WB` 数据通路，每个周期最多发射两条指令
- 两入口取指队列，缓存 Wishbone 指令总线返回的连续指令并完成指令配对
- 双写端口、四读端口通用寄存器堆，支持两条发射通道同时读取和写回
- 第一通道支持完整指令集，包括算术逻辑、移位、分支与跳转、延时槽、load/store、乘除法、HI/LO、LL/SC、CP0、异常和中断
- 第二通道仅发射相互独立的安全 ALU 指令，不执行访存、分支、乘除法、HI/LO、CP0、异常或延时槽指令
- 存在数据相关、目标寄存器冲突或非安全指令时自动退化为单发射
- 保留数据前递、load-use 停顿、流水线暂停和冲刷机制
- Wishbone 指令总线每周期最多取一条 32 位指令，由取指队列完成双发射配对

## SoC 外设

- Wishbone 与 ConMax 多主多从互连
- SDRAM 控制器
- UART 16550
- GPIO 与中断
- NOR Flash 接口
- HC595 数码管显示输出

CPU 顶层模块为 `openmips`，SoC 顶层模块为 `openmips_min_sopc`：

```text
CPU_Design_total.srcs/sources_1/new/openmips.v
CPU_Design_total.srcs/sources_1/new/openmips_min_sopc.v
```

## 目录说明

```text
CPU_Design_total.xpr                 Vivado 工程文件
CPU_Design_total.srcs/sources_1/new  CPU、Wishbone 与外设 RTL
CPU_Design_total.srcs/sources_1/ip   工程使用的 Vivado IP 配置
CPU_Design_total.srcs/sim_1/new      仿真顶层
ddr3_pin.ucf                         工程保留的 DDR3 引脚约束
```

双发射相关模块：

```text
CPU_Design_total.srcs/sources_1/new/instruction_queue.v
CPU_Design_total.srcs/sources_1/new/dual_issue_ctrl.v
```

显示输出所需的 `HC595_driver.v`、`hex8.v` 和 `hex8_test.v` 位于 `sources_1/new/display/`。

## 使用方式

1. 使用 Vivado 2018.3 打开 `CPU_Design_total.xpr`。
2. 检查 IP 状态；若本机缺少对应 IP 输出，在 Vivado 中重新生成 `blk_mem_gen_0`、`clk_wiz_0` 和 `mig_7series_0`。
3. 将 `openmips_min_sopc` 设为综合顶层。
4. 根据实际开发板补充或调整引脚约束，再运行综合、实现并生成比特流。

当前 SoC 顶层直接连接 SDRAM 与 NOR Flash。工程保留了 MIG 7 Series IP 和 `ddr3_pin.ucf`，但当前顶层没有直接使用 DDR3。

## 验证状态

本次双发射改造已完成静态代码整理，但尚未在 Vivado 中进行综合、实现、时序分析或上板验证，也未建立完整的自动化回归测试。首次使用时建议先运行仿真，确认取指队列、分支延时槽、双通道前递和写回顺序符合预期。

## 许可说明

仓库中的 UART、GPIO、SDRAM 控制器和 Wishbone 互连等文件带有各自的原版权与许可声明，使用和再分发时请遵循文件头部说明。本仓库未对全部代码统一附加新的开源许可证。

## 作者

GitHub: [Arbitraryoxd](https://github.com/Arbitraryoxd)
