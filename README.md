# CPU_Design_total

这是一个使用 Verilog 实现的 32 位 MIPS 五级流水线 CPU 与 SoC FPGA 工程，目标器件为 Xilinx Artix-7 `xc7a35tfgg484-2`，工程使用 Vivado 2018.3 创建。

## 项目概览

- 经典五级流水线：取指（IF）、译码（ID）、执行（EX）、访存（MEM）、写回（WB）
- 数据前递、load-use 停顿、流水线暂停与冲刷
- 算术、逻辑、移位、分支、跳转、延时槽及 load/store
- 乘除法、HI/LO 寄存器、LL/SC
- 系统调用、陷阱、CP0、异常与中断处理
- Wishbone 总线与 ConMax 多主多从互连
- SoC 外设：SDRAM 控制器、UART 16550、GPIO、NOR Flash 和 HC595 数码管输出

顶层模块为 `openmips_min_sopc`，源文件位于：

```text
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

显示输出所需的 `HC595_driver.v`、`hex8.v` 和 `hex8_test.v` 已收录在 `sources_1/new/display/`，工程不再依赖目录外的 `digital_display` 工程。

## 快速开始

1. 使用 Vivado 2018.3 打开 `CPU_Design_total.xpr`。
2. 检查 IP 状态；若本机缺少对应 IP 输出，在 Vivado 中重新生成 `blk_mem_gen_0`、`clk_wiz_0` 和 `mig_7series_0`。
3. 将 `openmips_min_sopc` 设为综合顶层，运行综合与实现。
4. 根据实际开发板补充或调整引脚约束，再生成比特流并上板。

当前顶层直接连接 SDRAM 与 NOR Flash 接口。工程中虽然保留了 MIG 7 Series IP 和 `ddr3_pin.ucf`，但当前 SoC 顶层并未直接使用 DDR3。

## 仿真说明

仿真顶层位于 `CPU_Design_total.srcs/sim_1/new/openmips_min_sopc_tb.v`，ROM 初始化数据位于 `CPU_Design_total.srcs/sources_1/new/inst_rom.data`。

当前测试平台是基础仿真骨架，并非完整的自动化回归测试。首次仿真前请检查顶层端口连接和 ROM 初始化路径。仓库未附带已验证的仿真结果。

## 许可说明

仓库中的 UART、GPIO、SDRAM 控制器和 Wishbone 互连等文件带有各自的原版权与许可声明，使用和再分发时请遵循文件头部说明。本仓库未对全部代码统一附加新的开源许可证。

## 作者

GitHub: [Arbitraryoxd](https://github.com/Arbitraryoxd)
