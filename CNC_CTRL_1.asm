;7.5 deg / step = 48 steps / turn
;1/4-20 = 20 turns / inch
;960 steps / inch
;
;****************************************************************************************************
;
;PortB 0-3 X steps
;PortB 4-7 Y steps
;
;PortA in 0 Data Ready on USB
;PortA out 1 Read USB
;PortA out 2 X ready
;PortA out 3 Y ready
;PortA in 4-5 X offset
;PortA in 6-7 Y offset 
;direction ?
;limit switches ?
;offset : 00 = 1 step
;offset : 01 = 10 steps
;offset : 10 = 48 steps (1 turn)
;offset : 11 = 240 steps (5 turns)

;****************************************************************************************************

PIC:
PortA 0 (in) Data Ready on USB
PortA 1 (out) Read USB
PortA 2 (in) USB Ready for Data
PortA 3 (out) Write USB
PortA 4 (out) Enable Step Controllers
PortA 5 (out) Latch Data to Step Controlers
PortA 6 (out) Activate Drill Cycle
PortA 7 (out) Move Completed

PortB 0 (out) X axis phase 1 
PortB 1 (out) X axis phase 2
PortB 2 (out) X axis phase 3
PortB 3 (out) X axis phase 4
PortB 4 (out) Y axis phase 1
PortB 5 (out) Y axis phase 2
PortB 6 (out) Y axis phase 3
PortB 7 (out) Y axis phase 4

USB input:
0 X min limit switch
1 X max limit switch
2 Y min limit switch
3 Y max limit switch
4 Drill top switch (0 active | bottom, 1 Top position reached)
5 Drill bottom switch (0 active | top, 1 Bottom position reached)
6 Move completed (from PIC portA 7)
7 N/C

USB output:
0 X axis Direction (0 increase, 1 decrease)
1 X Offset b0
2 X Offset b1
3 X Offset b2
4 Y axis Direction (0 increase, 1 decrease)
5 Y Offset b0
6 Y Offset b1
7 Y Offset b2

Offsets :
000 : 1 step
001 : 3 steps
010 : 7 steps
011 : 15 steps
100 : 24 steps / 0.5 turn (0.025)
101 : 96 steps / 2 turn (0.100)
110 : 240 steps / 5 turns (0.250)
111 : X: activate drill, Y reset / disable step controllers


PIC software layout:
Init: 
	disable interrupts
	set ports
	set constants
	clear buffers
	set move completed bit
	
Run:
	if buffers are empty
		check if data ready
			read data
			fill buffers
			
	move un-empty buffer according to direction
	decrease buffers

	check if buffers are empty
		set move completed bit accordingly
	
	send data to usb
	
	sleep(256)

