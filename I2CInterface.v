module I2CInterface(
    output wire [7:0]  led,
    input  wire        sys_clkn,
    input  wire        sys_clkp,
    output wire        I2C_SCL_0,
    inout  wire        I2C_SDA_0,
    output reg         FSM_Clk_reg,
    output reg         ILA_Clk_reg,
    input  wire        PCControl,
    input  wire [6:0]  SlaveAddress,
    input  wire [6:0]  SubAddress,
    input  wire        ReadWrite,
    input  wire [7:0]  WriteData,
    input  wire [7:0]  BytesToRead,
    output reg  [31:0] ReadData,
    output reg         ACK_bit,
    output reg         SCL,
    output reg         SDA,
    output reg  [7:0]  UpperState,
    output reg  [7:0]  LowerState,
    output wire [31:0] Telemetry
    );

    // ****************************************************************************************************
    // Instantiate the ClockGenerator module, where three signals are generate:
    // High speed CLK signal, Low speed FSM_Clk signal
    wire [23:0] ClkDivThreshold = 100;
    wire FSM_Clk, ILA_Clk;
    ClockGenerator ClockGenerator1 (  .sys_clkn(sys_clkn),
                                      .sys_clkp(sys_clkp),
                                      .ClkDivThreshold(ClkDivThreshold),
                                      .FSM_Clk(FSM_Clk),
                                      .ILA_Clk(ILA_Clk) );

    // ****************************************************************************************************
    // Define Upper States
    localparam STATE_INIT  = 8'd0;
    localparam STATE_START = 8'd1;
    localparam STATE_STOP  = 8'd2;
    localparam STATE_ACK   = 8'd3;
    localparam STATE_SAD   = 8'd4;
    localparam STATE_SUB   = 8'd5;
    localparam STATE_READ  = 8'd6;
    localparam STATE_WRITE = 8'd7;

    // ****************************************************************************************************
    // Flag Declarations
    wire SubAddressDone;
    wire SlaveAddressDone;
    wire ReadAck;
    wire ReadDone;
    wire WriteDone;

    // Read State Declarations
    wire [7:0] ReadByteCounter;
    wire [7:0] ReadOutput [0:3];
    // Write State Declarations
    wire [7:0] WriteDataLocal;

    // Initialize some IO, States, Flags
    reg error_bit = 1'b1;
    initial  begin
        SCL              = 1'b1;
        SDA              = 1'b1;
        ACK_bit          = 1'b1;
        SubAddressDone   = 1'b0;
        SlaveAddressDone = 1'b0;
        ReadAck          = 1'b0;
        ReadDone         = 1'b0;
        WriteDone        = 1'b0;

        ReadByteCounter  = 8'd0;
        ReadOutput[0]    = 8'd0;
        ReadOutput[1]    = 8'd0;
        ReadOutput[2]    = 8'd0;
        ReadOutput[3]    = 8'd0;
        WriteDataLocal   = 8'd0;

        UpperState       = STATE_INIT;
        LowerState       = 8'b0;
    end

    // ****************************************************************************************************
    // I/O Assignments
    assign led[7]    = ACK_bit;
    assign led[6]    = error_bit;
    assign led[5:0]  = 1'b1;
    assign I2C_SCL_0 = SCL;
    assign I2C_SDA_0 = SDA;

    // Clk assignments
    always @(*) begin
        FSM_Clk_reg = FSM_Clk;
        ILA_Clk_reg = ILA_Clk;
    end

    // Assign ReadData and Telemetry (flags) outputs
    always @(posedge ILA_Clk) ReadData = {ReadOutput[3], ReadOutput[2], ReadOutput[1], ReadOutput[0]};
    assign Telemetry = {11'd0,
                        SubAddressDone,
                        SlaveAddressDone,
                        ReadAck,
                        ReadDone,
                        WriteDone,
                        ReadByteCounter,
                        WriteDataLocal};

    // ****************************************************************************************************
    // Interface FSM
    always @(posedge FSM_Clk) begin
        case (UpperState)
            STATE_INIT : begin
                // Clear flags, safety coverage
                SubAddressDone   <= 1'b0;
                SlaveAddressDone <= 1'b0;
                ReadDone         <= 1'b0;
                WriteDone        <= 1'b0;
                ReadAck          <= 1'b0;

                if (PCControl == 1'b1) begin
                    LowerState      <= 8'd0;
                    ReadByteCounter <= BytesToRead; // Assign new number of bytes to read
                    WriteDataLocal  <= WriteData;   // Assign WriteData to locally-used signal, safety precaution
                    ReadOutput[0]   <= 8'd0;        // Clear ReadOutputs
                    ReadOutput[1]   <= 8'd0;
                    ReadOutput[2]   <= 8'd0;
                    ReadOutput[3]   <= 8'd0;
                    UpperState      <= STATE_START;
                end
                else begin
                     SCL        <= 1'b1;
                     SDA        <= 1'b1;
                     UpperState <= STATE_INIT;
                end
            end

            // Master Tx START
            STATE_START : begin
                case (LowerState)
                    8'd0 : begin SCL <= 1'b1; SDA <= 1'b0; LowerState <= LowerState + 1'b1; end
                    8'd1 : begin SCL <= 1'b0; SDA <= 1'b0; LowerState <= LowerState + 1'b1; end
                    8'd2 : begin
                        LowerState <= 8'd0;
                        UpperState <= STATE_SAD;
                    end
                    default: error_bit = 1'b0;
                endcase
            end

            // Master Tx STOP
            STATE_STOP : begin
                case (LowerState)
                    8'd0 : begin SCL <= 1'b1; SDA <= 1'b1; LowerState <= LowerState + 1'b1; end
                    8'd1 : begin SCL <= 1'b0; SDA <= 1'b1; LowerState <= LowerState + 1'b1; end
                    8'd2 : begin
                        LowerState <= 8'd0;
                        UpperState <= STATE_INIT;
                    end
                    default: error_bit = 1'b0;
                endcase
            end

            // General Acknowledge, Master Rx and Tx possible
            STATE_ACK : STATE_ACK: begin
                case (LowerState)
                    8'd0 : begin SCL <= 1'b0;
                        // If predecessor of STATE_ACK was a STATE_READ
                        if (ReadAck == 1'b1) begin
                            // Was predecessor STATE_READ last read
                            if (ReadDone == 1'b1) begin
                                ReadDone   <= 1'b0;
                                ReadAck    <= 1'b0;
                                SDA        <= 1'b1;
                                LowerState <= 8'd1;
                            end
                            else begin
                                ReadAck    <= 1'b0;
                                SDA        <= 1'b0;
                                LowerState <= 8'd6;
                            end;
                        end

                        // If Predecessor of STATE_ACK was a STATE_WRITE
                        else if (WriteDone == 1'b1) begin
                            SDA        <= 1'bz;
                            WriteDone  <= 1'b0;
                            LowerState <= 8'd9;
                        end

                        // If Predecessor of STATE_ACK was a STATE_SAD
                        else if (SlaveAddressDone == 1'b1) begin
                            SDA              <= 1'bz;
                            SlaveAddressDone <= 1'b0;
                            // Have we already sent Subaddress (Previous STATE_SAD was reSTART before READ)
                            if (SubAddressDone == 1'b1) LowerState <= 8'd14;
                            else LowerState <= 8'd17;
                        end

                        // If Predecessor of STATE_ACK was a STATE_SUB
                        else if (SubAddressDone == 1'b1) begin
                            SDA <= 1'bz;
                            if (ReadWrite == 1'b1) LowerState <= 8'd20;
                            else error_bit = 1'b0;
                        end

                    end
                    // NOMACK -> STOP
                    8'd1 : begin SCL <= 1'b1; LowerState <= LowerState + 1; end
                    8'd2 : begin SCL <= 1'b1; LowerState <= LowerState + 1; end
                    8'd3 : begin SCL <= 1'b0; LowerState <= LowerState + 1; end
                    8'd4 : begin SCL <= 1'b0; SDA <= 1'b0; LowerState <= LowerState + 1; end
                    8'd5 : begin SCL <= 1'b1; LowerState <= 8'd0; UpperState <= STATE_STOP; end
                    // MACK -> READ
                    8'd6 : begin SCL <= 1'b1; LowerState <= LowerState + 1; end
                    8'd7 : begin SCL <= 1'b1; LowerState <= LowerState + 1; end
                    8'd8 : begin SCL <= 1'b0; LowerState <= 8'd0; UpperState <= STATE_READ; end
                    // SACK -> STOP
                    8'd9  : begin SCL <= 1'b1; LowerState <= LowerState + 1; end
                    8'd10 : begin SCL <= 1'b1; ACK_bit <= SDA; LowerState <= LowerState + 1; end
                    8'd11 : begin SCL <= 1'b0; LowerState <= LowerState + 1; end
                    8'd12 : begin SCL <= 1'b0; SDA <= 1'b0; LowerState <= LowerState + 1; end
                    8'd13 : begin SCL <= 1'b1; LowerState <= 8'd0; UpperState <= STATE_STOP; end
                    // SACK -> READ
                    8'd14 : begin SCL <= 1'b1; LowerState <= LowerState + 1; end
                    8'd15 : begin SCL <= 1'b1; ACK_bit <= SDA; LowerState <= LowerState + 1; end
                    8'd16 : begin SCL <= 1'b0; LowerState <= 8'd0; UpperState <= STATE_READ; end
                    // SACK -> SUB
                    8'd17 : begin SCL <= 1'b1; LowerState <= LowerState + 1; end
                    8'd18 : begin SCL <= 1'b1; ACK_bit <= SDA; LowerState <= LowerState + 1; end
                    8'd19 : begin SCL <= 1'b0; LowerState <= 8'd0; UpperState <= STATE_SUB; end
                    // SACK -> START
                    8'd20 : begin SCL <= 1'b1; LowerState <= LowerState + 1; end
                    8'd21 : begin SCL <= 1'b1; ACK_bit <= SDA; LowerState <= LowerState + 1; end
                    8'd22 : begin SCL <= 1'b0; LowerState <= LowerState + 1; end
                    8'd23 : begin SCL <= 1'b0; SDA <= 1'b1; LowerState <= LowerState + 1; end
                    8'd24 : begin SCL <= 1'b1; LowerState <= 8'd0; UpperState <= STATE_START; end
                    default: error_bit = 1'b0
                endcase
            end

            // Master Tx Slave Address
            STATE_SAD : begin
                case (LowerState)
                    8'd0  : begin SCL <= 1'b0; SDA <= SlaveAddress[6]; LowerState <= LowerState + 1'b1; end
                    8'd1  : begin SCL <= 1'b1; LowerState <= LowerState + 1'b1; end
                    8'd2  : begin SCL <= 1'b1; LowerState <= LowerState + 1'b1; end
                    8'd3  : begin SCL <= 1'b0; LowerState <= LowerState + 1'b1; end
                    8'd4  : begin SCL <= 1'b0; SDA <= SlaveAddress[5]; LowerState <= LowerState + 1'b1; end
                    8'd5  : begin SCL <= 1'b1; LowerState <= LowerState + 1'b1; end
                    8'd6  : begin SCL <= 1'b1; LowerState <= LowerState + 1'b1; end
                    8'd7  : begin SCL <= 1'b0; LowerState <= LowerState + 1'b1; end
                    8'd8  : begin SCL <= 1'b0; SDA <= SlaveAddress[4]; LowerState <= LowerState + 1'b1; end
                    8'd9  : begin SCL <= 1'b1; LowerState <= LowerState + 1'b1; end
                    8'd10 : begin SCL <= 1'b1; LowerState <= LowerState + 1'b1; end
                    8'd11 : begin SCL <= 1'b0; LowerState <= LowerState + 1'b1; end
                    8'd12 : begin SCL <= 1'b0; SDA <= SlaveAddress[3]; LowerState <= LowerState + 1'b1; end
                    8'd13 : begin SCL <= 1'b1; LowerState <= LowerState + 1'b1; end
                    8'd14 : begin SCL <= 1'b1; LowerState <= LowerState + 1'b1; end
                    8'd15 : begin SCL <= 1'b0; LowerState <= LowerState + 1'b1; end
                    8'd16 : begin SCL <= 1'b0; SDA <= SlaveAddress[2]; LowerState <= LowerState + 1'b1; end
                    8'd17 : begin SCL <= 1'b1; LowerState <= LowerState + 1'b1; end
                    8'd18 : begin SCL <= 1'b1; LowerState <= LowerState + 1'b1; end
                    8'd19 : begin SCL <= 1'b0; LowerState <= LowerState + 1'b1; end
                    8'd20 : begin SCL <= 1'b0; SDA <= SlaveAddress[1]; LowerState <= LowerState + 1'b1; end
                    8'd21 : begin SCL <= 1'b1; LowerState <= LowerState + 1'b1; end
                    8'd22 : begin SCL <= 1'b1; LowerState <= LowerState + 1'b1; end
                    8'd23 : begin SCL <= 1'b0; LowerState <= LowerState + 1'b1; end
                    8'd24 : begin SCL <= 1'b0; SDA <= SlaveAddress[0]; LowerState <= LowerState + 1'b1; end
                    8'd25 : begin SCL <= 1'b1; LowerState <= LowerState + 1'b1; end
                    8'd26 : begin SCL <= 1'b1; LowerState <= LowerState + 1'b1; end
                    8'd27 : begin SCL <= 1'b0; LowerState <= LowerState + 1'b1; end
                    8'd28 : begin SCL <= 1'b0; LowerState <= LowerState + 1'b1;
                        // Have we already sent Subaddress (We are at reSTART before READ)
                        if (SubAddressDone == 1'b1) SDA <= 1'b1;
                        else SDA <= 1'b0;
                    end
                    8'd29 : begin SCL <= 1'b1; LowerState <= LowerState + 1'b1; end
                    8'd30 : begin SCL <= 1'b1; LowerState <= LowerState + 1'b1; end
                    8'd31 : begin SCL <= 1'b0; LowerState <= 8'b0; UpperState <= STATE_ACK; SlaveAddressDone <= 1'b1; end
                    default: error_bit = 1'b0;
                endcase
            end

            // Master Tx Subaddress
            STATE_SUB : begin
                case (LowerState)
                    8'd0  : begin SCL <= 1'b0; LowerState <= LowerState + 1'b1;
                        // LSM303DLHC-specific behavior, 1 indicates multi-byte read
                        if (BytesToRead == 8'd1) SDA <= 1'b0;
                        else SDA <= 1'b1;
                    end
                    8'd1  : begin SCL <= 1'b1; LowerState <= LowerState + 1'b1; end
                    8'd2  : begin SCL <= 1'b1; LowerState <= LowerState + 1'b1; end
                    8'd3  : begin SCL <= 1'b0; LowerState <= LowerState + 1'b1; end
                    8'd4  : begin SCL <= 1'b0; SDA <= SubAddress[6]; LowerState <= LowerState + 1'b1; end
                    8'd5  : begin SCL <= 1'b1; LowerState <= LowerState + 1'b1; end
                    8'd6  : begin SCL <= 1'b1; LowerState <= LowerState + 1'b1; end
                    8'd7  : begin SCL <= 1'b0; LowerState <= LowerState + 1'b1; end
                    8'd8  : begin SCL <= 1'b0; SDA <= SubAddress[5]; LowerState <= LowerState + 1'b1; end
                    8'd9  : begin SCL <= 1'b1; LowerState <= LowerState + 1'b1; end
                    8'd10 : begin SCL <= 1'b1; LowerState <= LowerState + 1'b1; end
                    8'd11 : begin SCL <= 1'b0; LowerState <= LowerState + 1'b1; end
                    8'd12 : begin SCL <= 1'b0; SDA <= SubAddress[4]; LowerState <= LowerState + 1'b1; end
                    8'd13 : begin SCL <= 1'b1; LowerState <= LowerState + 1'b1; end
                    8'd14 : begin SCL <= 1'b1; LowerState <= LowerState + 1'b1; end
                    8'd15 : begin SCL <= 1'b0; LowerState <= LowerState + 1'b1; end
                    8'd16 : begin SCL <= 1'b0; SDA <= SubAddress[3]; LowerState <= LowerState + 1'b1; end
                    8'd17 : begin SCL <= 1'b1; LowerState <= LowerState + 1'b1; end
                    8'd18 : begin SCL <= 1'b1; LowerState <= LowerState + 1'b1; end
                    8'd19 : begin SCL <= 1'b0; LowerState <= LowerState + 1'b1; end
                    8'd20 : begin SCL <= 1'b0; SDA <= SubAddress[2]; LowerState <= LowerState + 1'b1; end
                    8'd21 : begin SCL <= 1'b1; LowerState <= LowerState + 1'b1; end
                    8'd22 : begin SCL <= 1'b1; LowerState <= LowerState + 1'b1; end
                    8'd23 : begin SCL <= 1'b0; LowerState <= LowerState + 1'b1; end
                    8'd24 : begin SCL <= 1'b0; SDA <= SubAddress[1]; LowerState <= LowerState + 1'b1; end
                    8'd25 : begin SCL <= 1'b1; LowerState <= LowerState + 1'b1; end
                    8'd26 : begin SCL <= 1'b1; LowerState <= LowerState + 1'b1; end
                    8'd27 : begin SCL <= 1'b0; LowerState <= LowerState + 1'b1; end
                    8'd28 : begin SCL <= 1'b0; SDA <= SubAddress[0]; LowerState <= LowerState + 1'b1; end
                    8'd29 : begin SCL <= 1'b1; LowerState <= LowerState + 1'b1; end
                    8'd30 : begin SCL <= 1'b1; LowerState <= LowerState + 1'b1; end
                    8'd31 : begin SCL <= 1'b0; LowerState <= 8'b0; UpperState <= STATE_ACK; SubAddressDone <= 1'b1; end
                    default: error_bit = 1'b0;
                endcase
            end

            // Master Rx ReadData
            STATE_READ : begin
                case (LowerState)
                    8'd0  : begin SCL <= 1'b0; SDA <= 1'bz; LowerState <= LowerState + 1'b1; end
                    8'd1  : begin SCL <= 1'b1; LowerState <= LowerState + 1'b1; end
                    8'd2  : begin SCL <= 1'b1; ReadOutput[ReadByteCounter - 1][7] <= SDA; LowerState <= LowerState + 1'b1; end
                    8'd3  : begin SCL <= 1'b0; LowerState <= LowerState + 1'b1; end
                    8'd4  : begin SCL <= 1'b0; LowerState <= LowerState + 1'b1; end
                    8'd5  : begin SCL <= 1'b1; LowerState <= LowerState + 1'b1; end
                    8'd6  : begin SCL <= 1'b1; ReadOutput[ReadByteCounter - 1][6] <= SDA; LowerState <= LowerState + 1'b1; end
                    8'd7  : begin SCL <= 1'b0; LowerState <= LowerState + 1'b1; end
                    8'd8  : begin SCL <= 1'b0; LowerState <= LowerState + 1'b1; end
                    8'd9  : begin SCL <= 1'b1; LowerState <= LowerState + 1'b1; end
                    8'd10 : begin SCL <= 1'b1; ReadOutput[ReadByteCounter - 1][5] <= SDA; LowerState <= LowerState + 1'b1; end
                    8'd11 : begin SCL <= 1'b0; LowerState <= LowerState + 1'b1; end
                    8'd12 : begin SCL <= 1'b0; LowerState <= LowerState + 1'b1; end
                    8'd13 : begin SCL <= 1'b1; LowerState <= LowerState + 1'b1; end
                    8'd14 : begin SCL <= 1'b1; ReadOutput[ReadByteCounter - 1][4] <= SDA; LowerState <= LowerState + 1'b1; end
                    8'd15 : begin SCL <= 1'b0; LowerState <= LowerState + 1'b1; end
                    8'd16 : begin SCL <= 1'b0; LowerState <= LowerState + 1'b1; end
                    8'd17 : begin SCL <= 1'b1; LowerState <= LowerState + 1'b1; end
                    8'd18 : begin SCL <= 1'b1; ReadOutput[ReadByteCounter - 1][3] <= SDA; LowerState <= LowerState + 1'b1; end
                    8'd19 : begin SCL <= 1'b0; LowerState <= LowerState + 1'b1; end
                    8'd20 : begin SCL <= 1'b0; LowerState <= LowerState + 1'b1; end
                    8'd21 : begin SCL <= 1'b1; LowerState <= LowerState + 1'b1; end
                    8'd22 : begin SCL <= 1'b1; ReadOutput[ReadByteCounter - 1][2] <= SDA; LowerState <= LowerState + 1'b1; end
                    8'd23 : begin SCL <= 1'b0; LowerState <= LowerState + 1'b1; end
                    8'd24 : begin SCL <= 1'b0; LowerState <= LowerState + 1'b1; end
                    8'd25 : begin SCL <= 1'b1; LowerState <= LowerState + 1'b1; end
                    8'd26 : begin SCL <= 1'b1; ReadOutput[ReadByteCounter - 1][1] <= SDA; LowerState <= LowerState + 1'b1; end
                    8'd27 : begin SCL <= 1'b0; LowerState <= LowerState + 1'b1; end
                    8'd28 : begin SCL <= 1'b0; LowerState <= LowerState + 1'b1; end
                    8'd29 : begin SCL <= 1'b1; LowerState <= State + 1'b1; end
                    8'd30 : begin SCL <= 1'b1; ReadOutput[ReadByteCounter - 1][0] <= SDA; LowerState <= LowerState + 1'b1; ReadByteCounter <= ReadByteCounter - 1; end
                    8'd31 : begin SCL <= 1'b0; LowerState <= 8'd0; ReadAck <= 1'b1; UpperState <= STATE_ACK;
                        // Was previously read byte last byte of transaction
                        if (ReadByteCounter == 8'd0) ReadDone <= 1'b1;
                    end
                    default: error_bit = 1'b0;
                endcase
            end;

            // Master Tx WriteData
            STATE_WRITE : begin
                case (LowerState)
                    8'd0  : begin SCL <= 1'b0; LowerState <= LowerState + 1'b1; end
                    8'd1  : begin SCL <= 1'b1; LowerState <= LowerState + 1'b1; end
                    8'd2  : begin SCL <= 1'b1; SDA <= WriteData[7]; LowerState <= LowerState + 1'b1; end
                    8'd3  : begin SCL <= 1'b0; LowerState <= LowerState + 1'b1; end
                    8'd4  : begin SCL <= 1'b0; LowerState <= LowerState + 1'b1; end
                    8'd5  : begin SCL <= 1'b1; LowerState <= LowerState + 1'b1; end
                    8'd6  : begin SCL <= 1'b1; SDA <= WriteData[6]; LowerState <= LowerState + 1'b1; end
                    8'd7  : begin SCL <= 1'b0; LowerState <= LowerState + 1'b1; end
                    8'd8  : begin SCL <= 1'b0; LowerState <= LowerState + 1'b1; end
                    8'd9  : begin SCL <= 1'b1; LowerState <= LowerState + 1'b1; end
                    8'd10 : begin SCL <= 1'b1; SDA <= WriteData[5]; LowerState <= LowerState + 1'b1; end
                    8'd11 : begin SCL <= 1'b0; LowerState <= LowerState + 1'b1; end
                    8'd12 : begin SCL <= 1'b0; LowerState <= LowerState + 1'b1; end
                    8'd13 : begin SCL <= 1'b1; LowerState <= LowerState + 1'b1; end
                    8'd14 : begin SCL <= 1'b1; SDA <= WriteData[4]; LowerState <= LowerState + 1'b1; end
                    8'd15 : begin SCL <= 1'b0; LowerState <= LowerState + 1'b1; end
                    8'd16 : begin SCL <= 1'b0; LowerState <= LowerState + 1'b1; end
                    8'd17 : begin SCL <= 1'b1; LowerState <= LowerState + 1'b1; end
                    8'd18 : begin SCL <= 1'b1; SDA <= WriteData[3]; LowerState <= LowerState + 1'b1; end
                    8'd19 : begin SCL <= 1'b0; LowerState <= LowerState + 1'b1; end
                    8'd20 : begin SCL <= 1'b0; LowerState <= LowerState + 1'b1; end
                    8'd21 : begin SCL <= 1'b1; LowerState <= LowerState + 1'b1; end
                    8'd22 : begin SCL <= 1'b1; SDA <= WriteData[2]; LowerState <= LowerState + 1'b1; end
                    8'd23 : begin SCL <= 1'b0; LowerState <= LowerState + 1'b1; end
                    8'd24 : begin SCL <= 1'b0; LowerState <= LowerState + 1'b1; end
                    8'd25 : begin SCL <= 1'b1; LowerState <= LowerState + 1'b1; end
                    8'd26 : begin SCL <= 1'b1; SDA <= WriteData[1]; LowerState <= LowerState + 1'b1; end
                    8'd27 : begin SCL <= 1'b0; LowerState <= LowerState + 1'b1; end
                    8'd28 : begin SCL <= 1'b0; LowerState <= LowerState + 1'b1; end
                    8'd29 : begin SCL <= 1'b1; LowerState <= State + 1'b1; end
                    8'd30 : begin SCL <= 1'b1; SDA <= WriteData[0]; LowerState <= LowerState + 1'b1; end
                    8'd31 : begin SCL <= 1'b0; LowerState <= 8'd0; WriteDone <= 1'b0; UpperState <= STATE_ACK; end
                    default: error_bit = 1'b0;
                endcase
            end
            default: error_bit = 1'b0;
        endcase
    end

endmodule