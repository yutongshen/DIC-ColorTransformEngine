`timescale 1ns/10ps
module CTE ( clk, reset, op_mode, in_en, yuv_in, rgb_in, busy, out_valid, rgb_out, yuv_out);
input   clk ;
input   reset ;
input   op_mode;
input   in_en;
output  busy;
output  out_valid;
input   [7:0]   yuv_in;
output  [23:0]  rgb_out;
input   [23:0]  rgb_in;
output  [7:0]   yuv_out;

//Write your code here 
reg         cur_state;
wire        next_state;
reg         busy;
reg         out_valid;
reg [2:0]   cnt;
reg [7:0]   r_data [0:2];
wire        add1_mux, add3_mux;
wire [9:0]  w_a1, w_b1, w_add1;
wire [8:0]  w_a2, w_b2, w_add2;
wire [11:0] w_a3, w_b3, w_add3;
wire [10:0] w_a4, w_b4, w_sub1;
wire [11:0] w_a5, w_b5, w_sub2;
reg  [8:0]  r_tmp1;
reg  [9:0]  r_tmp2;
reg  [10:0] r_tmp3;
reg  [8:0]  r_tmp4;
reg  [9:0]  r_tmp5;
reg  [11:0] r_tmp6;
reg  [11:0] r_tmp7;

wire [11:0] w_yuv_tmp;
reg  [7:0]  yuv_out;
reg  [17:0] w_a6;
reg  [17:0] w_a7;
reg  [17:0] w_a8;
wire [17:0] multi1;
wire [17:0] multi2;
wire [17:0] multi3;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        {r_data[0], r_data[1], r_data[2]} <= 24'b0;
    end
    else begin
        if(~op_mode) begin
            if (~^cnt & cnt[0])    r_data[0] <= yuv_in;
            if (cnt[1:0] == 2'b10) r_data[1] <= yuv_in;
            if (cnt[2] & ~cnt[0])  r_data[2] <= yuv_in;
        end
        else begin
            if (~busy) {r_data[0], r_data[1], r_data[2]} <= rgb_in;
        end
    end
end

always @(posedge clk or posedge reset) begin
    if (reset) cur_state <= 1'b0;
    else cur_state <= next_state;
end

always @(posedge clk) begin
    if (reset | cnt[2] & cnt[0]) cnt <= 3'b0;
    else cnt <= cnt + 3'b1;
end

assign next_state = cur_state | cnt[1];
assign add1_mux = ~^cnt & ~cnt[1];
assign add3_mux = ~|cnt[2:1];

always @(*) begin
    if (~cur_state) busy = 1'b0;
    else begin
        if (~op_mode & ~|cnt[2:1])            busy = 1'b1;
        else if (op_mode & (cnt[2] | cnt[0])) busy = 1'b1; //optimal
        else                                  busy = 1'b0;
    end
end

always @(*) begin
    if (~cur_state) out_valid = 1'b0;
    else begin
        if (~op_mode & ~cnt[2] & ^cnt[1:0]) out_valid = 1'b1; //optimal
        else if (op_mode & (cnt[2] | (~cnt[2] & ~cnt[0]))) out_valid = 1'b1;
        else out_valid = 1'b0;
    end
end
//----------------------------------------------------------------
assign w_a1 = {2'b0, r_data[0]};
assign w_b1 = ~add1_mux ? {r_data[1][7], r_data[1], 1'b0} :
                          {{2{r_data[2][7]}}, r_data[2]};

assign w_a2 = {r_data[1][7], r_data[1]};
assign w_b2 = {r_data[2][7], r_data[2]};

assign w_a3 = ~add3_mux ? {{5{r_data[2][7]}}, r_data[2][7:1]} :
                          {r_tmp2, 2'b0};
assign w_b3 = ~add3_mux ? {{3{r_data[2][7]}}, r_data[2], 1'b0} :
                          {{3{r_tmp4[8]}}, r_tmp4};

assign w_a4 = {2'b0, r_data[0], 1'b0};
assign w_b4 = {{3{r_data[2][7]}}, r_data[2]};

assign w_a5 = {r_tmp3, 1'b0};
assign w_b5 = {{3{r_tmp1[8]}}, r_tmp1};

/*
assign w_a4 = ~op_mode ? {3'b0, r_data[0], 1'b0} :
                         multi1[17:6];
assign w_b4 = ~op_mode ? {{4{r_data[2][7]}}, r_data[2]} :
                         multi2[17:6];

assign w_a5 = ~op_mode ? {r_tmp3, 1'b0} :
              w_sub1;
assign w_b5 = ~op_mode ? {{3{r_tmp1[8]}}, r_tmp1} :
              multi3[17:6];
*/
assign w_add1 = w_a1 + w_b1; 
assign w_add2 = w_a2 + w_b2; 
assign w_add3 = w_a3 + w_b3; 
assign w_sub1 = w_a4 - w_b4; 
assign w_sub2 = w_a5 - w_b5; 

always @(posedge clk) begin
    if (reset) begin
        r_tmp1 <= 9'b0;
        r_tmp2 <= 10'b0;
        r_tmp3 <= 11'b0;
        r_tmp4 <= 9'b0;
        r_tmp5 <= 10'b0;
        r_tmp6 <= 12'b0;
        r_tmp7 <= 12'b0;
    end
    else begin
                       r_tmp1 <= w_add2;
        if (add1_mux)  r_tmp2 <= w_add1;
                       r_tmp3 <= w_sub1[10:0];
        if (~add3_mux) r_tmp4 <= w_add3[8:0];
        if (~add1_mux) r_tmp5 <= w_add1;
        if (add3_mux)  r_tmp6 <= w_add3;
                       r_tmp7 <= w_sub2;
    end
end

assign rgb_out[23:16] = r_tmp6[11] ? 8'h00 :
                        r_tmp6[10] ? 8'hff : r_tmp6[9:2] + r_tmp6[1];

assign rgb_out[15:8] = r_tmp7[11] ? 8'h00 :
                       (r_tmp7[10] | &r_tmp7[9:1]) ? 8'hff : r_tmp7[9:2] + r_tmp7[1];

assign rgb_out[7:0] = r_tmp5[9] ? 8'h00 :
                      r_tmp5[8] ? 8'hff : r_tmp5[7:0];

//----------------------------------------------------------------
parameter [7:0] mat11 = 'h4A,
                mat12 = 'hA1,//9'h15F, //-A1
                mat13 = 'h14,//9'h1EC, //-14

                mat21 = 'h25,//9'h1DB, //-25
                mat22 = 'h51,
                mat23 = 'h76,//9'h18A, //-76

                mat31 = 'h70,
                mat32 = 'h63,
                mat33 = 'hC;

reg  [10:0]  r_tmp8;
reg  [10:0]  r_tmp9;
reg  [10:0]  r_tmp10;

assign multi1 = {1'b0, r_data[0]} * w_a6;
assign multi2 = {1'b0, r_data[1]} * w_a7;
assign multi3 = {1'b0, r_data[2]} * w_a8;

always @(posedge clk) begin
    if (reset) begin
        r_tmp8  <= 11'b0;
        r_tmp9  <= 11'b0;
        r_tmp10 <= 11'b0;
    end
    else begin
        r_tmp8  <= (&cnt[1:0]) ? ~multi1[16:6]:
                                  multi1[16:6];
        r_tmp9  <= (cnt[2] ^ cnt[0] & ~cnt[1]) ? ~multi2[16:6]:
                                                  multi2[16:6];
        r_tmp10 <= (cnt[2] ^ cnt[0])  ? ~multi3[16:6]:
                                         multi3[16:6];
    end
end

assign w_yuv_tmp = {r_tmp8[10], r_tmp8} - {r_tmp8[10], r_tmp9} - {r_tmp8[10], r_tmp10};
//assign w_yuv_tmp = multi1[17:6] - multi2[17:6] - multi3[17:6];
//assign w_yuv_tmp = w_sub2;

always @(*) begin
    w_a6 = 8'bx;
    w_a7 = 8'bx;
    w_a8 = 8'bx;
    case (cnt)
        3'b011: begin
            w_a6 = mat21;
            w_a7 = mat22;
            w_a8 = mat23;
        end
        3'b100: begin
            w_a6 = mat11;
            w_a7 = mat12;
            w_a8 = mat13;
        end
        3'b101: begin
            w_a6 = mat31;
            w_a7 = mat32;
            w_a8 = mat33;
        end
        3'b001: begin
            w_a6 = mat11;
            w_a7 = mat12;
            w_a8 = mat13;
        end
    endcase
end

always @(*) begin
    yuv_out = 8'bx;
    case (cnt)
        3'b100: begin
            if (w_yuv_tmp[10] & w_yuv_tmp[9:2] <= 8'd139 )      yuv_out = 8'b10001011; // -117
            else if (~w_yuv_tmp[10] & w_yuv_tmp[9:2] >= 8'd117) yuv_out = 8'b01110101; // 117
            else                                                yuv_out = w_yuv_tmp[9:2] + w_yuv_tmp[1];
        end
        3'b101: begin
            if (w_yuv_tmp[11])      yuv_out = 8'b0;   // <= 0
            else if (w_yuv_tmp[10]) yuv_out = 8'hff;  // > 0xff
            else                    yuv_out = w_yuv_tmp[9:2] + w_yuv_tmp[1];
        end
        3'b000: begin
            if (w_yuv_tmp[10] & w_yuv_tmp[9:2] <= 8'd145)       yuv_out = 8'b10010001;  // -111
            else if (~w_yuv_tmp[10] & w_yuv_tmp[9:2] >= 8'd111) yuv_out = 8'b01101111;  // 111
            else                                                yuv_out = w_yuv_tmp [9:2] + w_yuv_tmp[1];
        end
        3'b010: begin
            if (w_yuv_tmp[11])      yuv_out = 8'b0;   // <= 0
            else if (w_yuv_tmp[10]) yuv_out = 8'hff;  // > 0xff
            else                    yuv_out = w_yuv_tmp[9:2] + w_yuv_tmp[1];
        end
    endcase
end
endmodule