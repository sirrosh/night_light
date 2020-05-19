HEX=night_light.hex
export DEVICE=12F675

OBJS=main.o
INCS=
LIBS=
LIBDIRS=

AS=gpasm
ASFLAGS=-c -p p$(DEVICE) -w 2
AR=gplib
ARFLAGS=-c
LD=gplink
LDFLAGS=-c -m -o $(HEX)
PR=pk2cmd
PRFLAGS=-B/usr/share/pk2/ -P


$(HEX): $(OBJS)
	$(LD) $(LDFLAGS) $(OBJS) $(LIBS)

$(OBJS): $(INCS)

%.o : %.asm
	$(AS) $(ASFLAGS) $<

clean:
	$(RM) *.o *.lst *.lib *.hex *.cod *.cof *.map

erase:
	$(PR) $(PRFLAGS) -I

flash:
	$(PR) $(PRFLAGS) -F$(HEX) -M -Y
