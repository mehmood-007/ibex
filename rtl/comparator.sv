
module comparator(
        input [4:0] A,B, 
        output  equal_signal);  
 wire tmp1,tmp2,tmp3,tmp4,tmp5;  
 // A = B output
    xnor u1(tmp1,A[0],B[0]);  
    xnor u2(tmp2,A[1],B[1]);
    xnor u3(tmp3,A[2],B[2]);  
    xnor u4(tmp4,A[3],B[3]);
    xnor u5(tmp5,A[4],B[4]);
    and a1(equal_signal, tmp1, tmp2, tmp3, tmp4, tmp5 ); 

 endmodule   