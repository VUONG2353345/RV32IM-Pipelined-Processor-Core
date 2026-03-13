OUTPUT_ARCH( "riscv" )
ENTRY( _start )

SECTIONS
{
  /* Đặt vùng nhớ cho dữ liệu (.data) tại 0x2000 */
  . = 0x2000;
  .data : { *(.data) }

  /* Đặt vùng nhớ cho mã lệnh (.text) tại 0x10000 */
  . = 0x10000;
  .text : { *(.text) }
}
