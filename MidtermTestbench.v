`timescale 1ns / 1ps
///////////////////////////////////////////////////////////////////////////////////////////////////////
// Description:
//      437 Top level
// Dependencies:
//      ClockGenerator.v
//      I2CInterface.v
// Revision:
//      r0.0.0.2
///////////////////////////////////////////////////////////////////////////////////////////////////////

module MidtermTestBench();
    ///////////////////////////////////////////////////////////////////////////////////////////////////////
    //Declare wires and registers that will interface with the module under test
    //Registers are initilized to known states. Wires cannot be initilized.
    wire [7:0] led;
    reg        sys_clkn = 1;
    wire       sys_clkp;

    reg         PCControl;
    reg  [6:0]  SlaveAddress, SubAddress;
    reg         ReadWrite;
    reg  [7:0]  WriteData, BytesToRead;
    wire [31:0] ReadData;

    wire        ACK_bit, SCL, SDA;
    wire [7:0]  UpperState, LowerState;
    wire [31:0] Telemetry;

    ///////////////////////////////////////////////////////////////////////////////////////////////////////
    //Invoke the module that we like to test
    I2CInterface UUT (  .led(led),
                        .sys_clkn(sys_clkn),
                        .sys_clkp(sys_clkp),
                        // .I2C_SCL_0(I2C_SCL_0),
                        // .I2C_SDA_0(I2C_SDA_0),
                        .FSM_Clk_reg(FSM_Clk_reg),
                        .ILA_Clk_reg(ILA_Clk_reg),
                        .PCControl(PCControl),
                        .SlaveAddress(SlaveAddress),
                        .SubAddress(SubAddress),
                        .ReadWrite(ReadWrite),
                        .WriteData(WriteData),
                        .BytesToRead(BytesToRead),
                        .ReadData(ReadData),
                        .ACK_bit(ACK_bit),
                        .SCL(SCL),
                        .SDA(SDA),
                        .UpperState(UpperState),
                        .LowerState(LowerState),
                        .Telemetry(Telemetry));

    ///////////////////////////////////////////////////////////////////////////////////////////////////////
    // Generate a clock signal. The clock will change its state every 5ns.
    assign sys_clkp = ~sys_clkn;
    always begin
        #5 sys_clkn = ~sys_clkn;
    end

    ///////////////////////////////////////////////////////////////////////////////////////////////////////
    // Testbench flow
    initial begin
            #0       SlaveAddress <= 7'b0011001; SubAddress <= 7'b0100000; ReadWrite <= 1'b0; WriteData <= 8'b10101010;
            #100000    PCControl <= 1'b1;
            #100000    PCControl <= 1'b0;
            #20000000  SlaveAddress <= 7'b0011110; SubAddress <= 7'b0000011; ReadWrite <= 1'b1; BytesToRead <= 8'd2;
            #100000    PCControl <= 1'b1;
            #100000    PCControl <= 1'b0;
    end

endmodule