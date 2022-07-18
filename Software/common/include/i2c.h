#ifndef __I2C_H
#define __I2C_H

extern void __fastcall__ i2c_init(void);
extern void __fastcall__ i2c_start(void);
extern void __fastcall__ i2c_stop(void);
extern void __fastcall__ i2c_send_ack(void);
extern void __fastcall__ i2c_send_nak(void);
extern void __fastcall__ i2c_read_ack(void);
extern void __fastcall__ i2c_clear(void);
extern void __fastcall__ i2c_send_byte(const unsigned char c);
extern void __fastcall__ i2c_read_byte(void);
extern void __fastcall__ i2c_send_addr(const unsigned char c);

#endif
