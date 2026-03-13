        .section .data
input_string:   .asciz "Hello world!"

        # tohost/fromhost are data locations used by Spike
        .align 8
tohost: .byte 0
        .align 8
fromhost: .byte 0

        
        .section .text
        .globl _start
_start:
        # Load the address of the input string into a0
        la a0, input_string

        # Your code here!
 
      

      
      mv t0, a0              

loop:
    lb t1, 0(t0)           # Load 1 byte (ký tự) từ địa chỉ t0 vào t1
    beq t1, zero, end_loop # Nếu ký tự là null (hết chuỗi), thoát vòng lặp

    # Kiểm tra xem ký tự có phải là chữ thường không ('a' <= t1 <= 'z')
    li t2, 97              # ASCII của 'a'
    blt t1, t2, next_char  # Nếu nhỏ hơn 'a', không phải chữ thường -> bỏ qua

    li t2, 122             # ASCII của 'z'
    bgt t1, t2, next_char  # Nếu lớn hơn 'z', không phải chữ thường -> bỏ qua

    # Chuyển đổi thành chữ hoa
    addi t1, t1, -32       
    sb t1, 0(t0)           

next_char:
    addi t0, t0, 1         
    j loop                 

end_loop:
    # Kết thúc xử lý     
end_program:
        # jump here when you're done
        j end_program

