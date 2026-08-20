

module top#(
    parameter width = 32 
)(
    input wire clk, rst
);

wire [width-1:0] pc_top, instruction_top, rd1_top, rd2_top, immExt_top, mux1_top, sum_out_top,
                next_pc_top, pc_in_top, address_top, memdata_top, writeBack_top;
wire regwrite_top, alusrc_top, zero_top, branch_top, sel2_top, memtoreg_top;
wire memread_top, memwrite_top;
wire [1:0] aluop_top;
wire [3:0] control_top;

// Program Counter
program_counter #(
    .width(width)
) pc (
    .clk(clk), .rst(rst),
    .pc_in(pc_in_top),
    .pc_out(pc_top)
);

// PC + 4
pc_plus_4 #(
    .width(width)
) pc_adder(
    .from_pc(pc_top),
    .next_pc(next_pc_top)
);

// Instruction Memory
memory #(
    .width(width),
    .depth(64)
) inst_mem (
    .clk(clk), .rst(rst), 
    .read_address(pc_top),
    .instruction_out(instruction_top)
);

// Register File
register #(
    .width(width), 
    .data(5)
) reg_file (
    .clk(clk), .rst(rst), .reg_write(regwrite_top),
    .rs1(instruction_top[19:15]), .rs2(instruction_top[24:20]), .rd(instruction_top[11:7]),
    .write_data(writeBack_top),
    .read_data1(rd1_top), .read_data2(rd2_top)
);

// Immediate Generator
imm_gen #(
    .width(width),
    .opcode_width(7)
) immGen (
    .opcode(instruction_top[6:0]),
    .instruction(instruction_top),
    .immExt(immExt_top)
);

// Control Unit
control_unit #(
    .opcode_width(7),
    .aluop_width(2)
) controlUnit(
    .instruction(instruction_top[6:0]),
    .branch(branch_top), .memread(memread_top), .memtoreg(memtoreg_top), 
    .memwrite(memwrite_top), .alusrc(alusrc_top), .regwrite(regwrite_top), 
    .aluop(aluop_top)
);

// ALU Control
alu_control #(
    .control(4),
    .aluop_width(2)
) aluControl (
    .fun7(instruction_top[30]), 
    .fun3(instruction_top[14:12]),
    .aluop(aluop_top),
    .control_out(control_top)
);

// ALU
alu_unit #(
    .width(width),
    .control(4)
) alu (
    .a(rd1_top), .b(mux1_top),
    .control_in(control_top),
    .zero(zero_top), 
    .alu_result(address_top)
);

// ALU Mux (immediate or register)
mux1 #(
    .width(width)
) alu_mux(
    .sel1(alusrc_top), 
    .a1(rd2_top), .b1(immExt_top),
    .mux1_out(mux1_top)
);

// AND logic for branch
and_logic and_gate(
    .branch(branch_top), .zero(zero_top),
    .and_out(sel2_top)
);

// Branch Address Adder
adder #(
    .width(width)
) add(
    .in_1(pc_top), .in_2(immExt_top),
    .sum_out(sum_out_top)
);

// PC Mux 
mux2 #(
    .width(width)
) mux_pc (
    .sel2(sel2_top), 
    .a2(next_pc_top), .b2(sum_out_top),
    .mux2_out(pc_in_top)
);

// Data Memory
Data_Memory data_mem(
    .clk(clk), .rst(rst), 
    .memwrite(memwrite_top), .memread(memread_top),
    .read_address(address_top), 
    .Write_data(rd2_top),
    .MemData_out(memdata_top)
);

// Writeback Mux 
mux3 #(
    .width(width)
) mux_wb(
    .sel3(memtoreg_top),
    .a3(address_top), .b3(memdata_top),
    .mux3_out(writeBack_top)
);

endmodule


module program_counter #(
    parameter width = 32
) (
    input wire clk, rst,
    input wire [width-1:0] pc_in,
    output reg [width-1:0] pc_out
);
    always @(posedge clk or posedge rst) begin
        if(rst) pc_out <= 0;
        else pc_out <= pc_in;
    end
endmodule

module pc_plus_4 #(
    parameter width = 32
) (
    input wire [width-1:0] from_pc,
    output wire [width-1:0] next_pc
);
    assign next_pc = from_pc + 4;
endmodule

module memory #(
    parameter width = 32,
    parameter depth = 64
) (
    input wire clk, rst,
    input wire [width-1:0] read_address,
    output reg [width-1:0] instruction_out
);
    integer i;
    reg [width-1:0] mem [depth-1:0];
    
    // Initialize instruction memory with test program
    initial begin
        mem[0]  = 32'h00500093;  // addi x1, x0, 5
        mem[1]  = 32'h00300113;  // addi x2, x0, 3
        mem[2]  = 32'h002081b3;  // add x3, x1, x2
        mem[3]  = 32'h40208233;  // sub x4, x1, x2
        mem[4]  = 32'h0020f2b3;  // and x5, x1, x2
        mem[5]  = 32'h0020e333;  // or x6, x1, x2
        mem[6]  = 32'h00102023;  // sw x1, 0(x0)
        mem[7]  = 32'h00002383;  // lw x7, 0(x0)
        mem[8]  = 32'h00208463;  // beq x1, x2, 8 (should not branch)
        mem[9]  = 32'h00108463;  // beq x1, x1, 8 (should branch to mem[11])
        mem[10] = 32'h06300093;  // addi x8, x0, 99 (skipped)
        mem[11] = 32'h06400493;  // addi x9, x0, 100
        
        for(i = 12; i < depth; i = i + 1) begin
            mem[i] = 0;
        end
    end
    
    always @(*) begin
        instruction_out = mem[read_address >> 2];
    end
endmodule

module register #(
    parameter width = 32,
    parameter data = 5
) (
    input wire clk, rst, reg_write,
    input wire [data-1:0] rs1, rs2, rd,
    input wire [width-1:0] write_data,
    output reg [width-1:0] read_data1,
    output reg [width-1:0] read_data2
);
    integer i;
    reg [width-1:0] regfile [31:0];
    
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            for(i = 0; i < 32; i = i + 1) begin
                regfile[i] <= 0;
            end
        end
        else if(reg_write && rd != 0) begin
            regfile[rd] <= write_data;
        end
    end
    
    always @(*) begin
        read_data1 = (rs1 == 0) ? 0 : regfile[rs1];
        read_data2 = (rs2 == 0) ? 0 : regfile[rs2];
    end
    
    function [width-1:0] read_register;
        input [data-1:0] reg_num;
        begin
            read_register = (reg_num == 0) ? 0 : regfile[reg_num];
        end
    endfunction
    
endmodule

module imm_gen #(
    parameter width = 32,
    parameter opcode_width = 7
) (
    input wire [opcode_width-1:0] opcode,
    input wire [width-1:0] instruction,
    output reg [width-1:0] immExt
);
    always @(*) begin
        case (opcode)
            7'b0000011: immExt = {{20{instruction[31]}}, instruction[31:20]};
            7'b0010011: immExt = {{20{instruction[31]}}, instruction[31:20]};
            7'b0100011: immExt = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
            7'b1100011: immExt = {{19{instruction[31]}}, instruction[31], instruction[30:25], 
                                   instruction[11:8], 1'b0};
            default: immExt = 0;
        endcase
    end
endmodule

module control_unit #(
    parameter opcode_width = 7,
    parameter aluop_width = 2
) (
    input wire [opcode_width-1:0] instruction,
    output reg branch, memread, memtoreg, memwrite, alusrc, regwrite,
    output reg [aluop_width-1:0] aluop
);
    always @(*) begin
        branch = 0;
        memread = 0;
        memtoreg = 0;
        memwrite = 0;
        alusrc = 0;
        regwrite = 0;
        aluop = 2'b00;
        
        case (instruction)
            7'b0110011: begin // R-type
                regwrite = 1;
                aluop = 2'b10;
            end
            7'b0000011: begin // I-type (lw)
                alusrc = 1;
                memtoreg = 1;
                regwrite = 1;
                memread = 1;
                aluop = 2'b00;
            end
            7'b0010011: begin // I-type (addi)
                alusrc = 1;
                regwrite = 1;
                aluop = 2'b00;
            end
            7'b0100011: begin // S-type (sw)
                alusrc = 1;
                memwrite = 1;
                aluop = 2'b00;
            end
            7'b1100011: begin // B-type (beq)
                branch = 1;
                aluop = 2'b01;
            end
        endcase
    end
endmodule

module alu_control #(
    parameter control = 4,
    parameter aluop_width = 2
) (
    input wire fun7,
    input wire [2:0] fun3,
    input wire [1:0] aluop,
    output reg [control-1:0] control_out
);
    always @(*) begin
        case ({aluop, fun7, fun3})
            6'b00_0_000: control_out = 4'b0010;
            6'b01_0_000: control_out = 4'b0110;
            6'b10_0_000: control_out = 4'b0010;
            6'b10_1_000: control_out = 4'b0110;
            6'b10_0_111: control_out = 4'b0000;
            6'b10_0_110: control_out = 4'b0001;
            default: control_out = 4'b0000;
        endcase
    end
endmodule

module alu_unit #(
    parameter width = 32,
    parameter control = 4
) (
    input wire [width-1:0] a, b,
    input wire [control-1:0] control_in,
    output reg zero,
    output reg [width-1:0] alu_result
);
    always @(*) begin
        case (control_in)
            4'b0000: alu_result = a & b;
            4'b0001: alu_result = a | b;
            4'b0010: alu_result = a + b;
            4'b0110: alu_result = a - b;
            default: alu_result = 0;
        endcase
        zero = (alu_result == 0);
    end
endmodule

module Data_Memory(
    input wire clk, rst, memwrite, memread,
    input wire [31:0] read_address, Write_data,
    output reg [31:0] MemData_out
);
    integer k;
    reg [31:0] D_Memory [63:0];
    
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            for(k=0; k<64; k=k+1) begin
                D_Memory[k] <= 0;
            end
        end
        else if(memwrite) begin
            D_Memory[read_address >> 2] <= Write_data;
        end
    end
    
    always @(*) begin
        if(memread)
            MemData_out = D_Memory[read_address >> 2];
        else
            MemData_out = 0;
    end
endmodule

module mux1 #(
    parameter width = 32
) (
    input wire sel1,
    input wire [width-1:0] a1, b1,
    output reg [width-1:0] mux1_out
);
    always @(*) begin
        mux1_out = sel1 ? b1 : a1;
    end
endmodule

module mux2 #(
    parameter width = 32
) (
    input wire sel2,
    input wire [width-1:0] a2, b2,
    output reg [width-1:0] mux2_out
);
    always @(*) begin
        mux2_out = sel2 ? b2 : a2;
    end
endmodule

module mux3 #(
    parameter width = 32
) (
    input wire sel3,
    input wire [width-1:0] a3, b3,
    output reg [width-1:0] mux3_out
);
    always @(*) begin
        mux3_out = sel3 ? b3 : a3;
    end
endmodule

module and_logic (
    input wire branch, zero,
    output reg and_out
);
    always @(*) begin
        and_out = branch & zero;
    end
endmodule

module adder #(
    parameter width = 32
) (
    input wire [width-1:0] in_1, in_2,
    output reg [width-1:0] sum_out
);
    always @(*) begin
        sum_out = in_1 + in_2;
    end
endmodule