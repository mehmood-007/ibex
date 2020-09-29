
module comparator(
        input [4:0] A,B, 
        output  equal_signal);  
 wire tmp1,tmp2,tmp3,tmp4,tmp5;  

wire [1:0] sel_a_b_0, sel_a_b_1, sel_a_b_2, sel_a_b_3, sel_a_b_4;

assign sel_a_b_0 = {A[0],B[0]};
assign sel_a_b_1 = {A[1],B[1]};
assign sel_a_b_2 = {A[2],B[2]};
assign sel_a_b_3 = {A[3],B[3]};
assign sel_a_b_4 = {A[4],B[4]};
 // A = B output
//    xnor u1(tmp1,A[0],B[0]);  
//    xnor u2(tmp2,A[1],B[1]);
//    xnor u3(tmp3,A[2],B[2]);  
//    xnor u4(tmp4,A[3],B[3]);
//    xnor u5(tmp5,A[4],B[4]);
//    and a1(equal_signal, tmp1, tmp2, tmp3, tmp4, tmp5 ); 
//assign equal_signal = A == B;

mux4X1 u1(4'b1001 ,sel_a_b_0, tmp1);
mux4X1 u2(4'b1001, sel_a_b_1, tmp2);
mux4X1 u3(4'b1001, sel_a_b_2, tmp3);
mux4X1 u4(4'b1001, sel_a_b_3, tmp4);
mux4X1 u5(4'b1001, sel_a_b_4, tmp5);

and a1(equal_signal, tmp1, tmp2, tmp3, tmp4, tmp5 ); 

 endmodule   