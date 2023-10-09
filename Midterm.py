# -*- coding: utf-8 -*-
"""
Created on Sat Oct  7 20:29:59 2023

@author: amjin2
"""

import pyvisa as visa # You should pip install pyvisa and restart the kernel.
import numpy as np
import matplotlib as mpl
import matplotlib.pyplot as plt
import time
import sys, os
import statistics
from struct import pack, unpack
mpl.style.use('ggplot')


ok_sdk_loc = "C:\\Program Files\\Opal Kelly\\FrontPanelUSB\\API\\Python\\x64"
ok_dll_loc = "C:\\Program Files\\Opal Kelly\\FrontPanelUSB\\API\\lib\\x64"
sys.path.append(ok_sdk_loc) # add the path of the OK library
os.add_dll_directory(ok_dll_loc)
import ok # OpalKelly library
#%% 
# Define FrontPanel device variable, open USB communication and
# load the bit file in the FPGA
dev = ok.okCFrontPanel() # define a device for FrontPanel communication
SerialStatus=dev.OpenBySerial("1839000NHR") # open USB communication with the OK board
ConfigStatus=dev.ConfigureFPGA("..\Lab2.runs\impl_1\lab2.bit"); # Configure the FPGA with this bit file
# Check if FrontPanel is initialized correctly and if the bit file is loaded.
# Otherwise terminate the program
print("----------------------------------------------------")
if SerialStatus == 0:
    print ("FrontPanel host interface was successfully initialized.")
else: 
    print ("FrontPanel host interface not detected. The error code number is:" + str(int(SerialStatus)))
    print("Exiting the program.")
    sys.exit ()
     
if ConfigStatus == 0:
    print ("Your bit file is successfully loaded in the FPGA.")
else:
    print ("Your bit file did not load. The error code number is:" + str(int(ConfigStatus)))
    print ("Exiting the progam.")
    sys.exit ()
print("----------------------------------------------------")
print("----------------------------------------------------")
#%% 
# Define the two variables that will send data to the FPGA
# We will use WireIn instructions to send data to the FPGA
while(True):
    slave_addr = input("Enter the slave address (binary upper 7 bits): ")
    sub_addr = input("Enter the sub address (binary lower 7 bits): ")
    read = input("Enter 1 if you wish to perform a read, 0 if to perform a write: ")
    if(int(read) != 1):
        write = input("Enter the write data (binary 8 bits): ")
    else:
        num_bytes = input("Enter the number of bytes to read (decimal up to 4): ")
    # if(int(str(test)) == 1):
    #     for control in range(4):
    #         print("Control is initialized to " + str(int(control)))
    #         time.sleep(2)
             
    #         clkdivcustom = 0
             
    #         dev.SetWireInValue(0x00, control) #Input data for Variable 1 using 
    #         dev.SetWireInValue(0x01, clkdivcustom)
    #         dev.UpdateWireIns() # Update the WireIns
             
    #         i = 0
     
    #         while(i < 50):
    #             time.sleep(0.1) 
    #             dev.UpdateWireOuts()
    #             result_counter = dev.GetWireOutValue(0x20)
    #             print("The counter is " + str(int(result_counter))) 
    #             i = i + 1
     
    # elif(int(test) == 2):
    #     print("***Entered function 1")
    #     clkdivcustom = int(input("Enter clock divisor: 1 to 200,000,000: "))
    #     if (clkdivcustom < 1 or clkdivcustom > 200000000):
    #         print("Clock divisor value invalid!")
            # sys.exit ()
     
        control = 0
        input_str = int((slave_addr + sub_addr + read)[::-1] )
        dev.SetWireInValue(0x00, control)
        dev.SetWireInValue(0x01, clkdivcustom)
        dev.UpdateWireIns() # Update the WireIns
     
        control = 2
        print("Control is initialized to " + str(int(control)))
        time.sleep(2)
     
        dev.SetWireInValue(0x00, control) #Input data for Variable 1 using memory space 0x00
        dev.UpdateWireIns() # Update the WireIns
     
        i = 0 
     
        while(i < 500):
     
            telemrate = (1/((2*pow(10,8))/clkdivcustom))
            time.sleep(telemrate / 2) 
            dev.UpdateWireOuts()
            result_counter = dev.GetWireOutValue(0x20) # Transfer the received data in result_counter variable
     
            print("The counter is " + str(int(result_counter))) 
            if(int(result_counter) == 100):
                dev.SetWireInValue(0x00, 0) #Input data for Variable 1 using memory space 0x00
                dev.UpdateWireIns() # Update the WireIns
     
                time.sleep((telemrate * 2) + (telemrate/5)) 
     
                print("The counter is " + str(int(result_counter))) 
     
                control = 2
                dev.SetWireInValue(0x00, control)
                dev.UpdateWireIns()
            i = i + 1
    test = input("Enter which option you want (1 for A, 2 for B, other for exit: ")
dev.Close