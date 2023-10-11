# -*- coding: utf-8 -*-
"""
Created on Sat Oct  7 20:29:59 2023

@author: amjin2
"""

import matplotlib as mpl
import time
import sys, os
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
SerialStatus=dev.OpenBySerial("1739000J9R") # open USB communication with the OK board
ConfigStatus=dev.ConfigureFPGA(r"C:\Users\amjin2\437Midterm\437Midterm.runs\impl_1\MidtermTopLevel.bit"); # Configure the FPGA with this bit file
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
# ILA VERSION MANUALLY UPLOAD BITSTREAM
# Define FrontPanel device variable, open USB communication and
# load the bit file in the FPGA
dev = ok.okCFrontPanel() # define a device for FrontPanel communication
SerialStatus=dev.OpenBySerial("1911000P3F") # open USB communication with the OK board
# Check if FrontPanel is initialized correctly and if the bit file is loaded.
# Otherwise terminate the program
print("----------------------------------------------------")
if SerialStatus == 0:
    print ("FrontPanel host interface was successfully initialized.")
else:
    print ("FrontPanel host interface not detected. The error code number is:" + str(int(SerialStatus)))
    print("Exiting the program.")
    sys.exit ()
print("----------------------------------------------------")
print("----------------------------------------------------")


#%%
#Accel: 0011001 Mag: 0011110
#To set LSB/Gauss:            CRB_REG_M   (0000001) (01100000) (670 LSB/Gauss X, Y, Z)
#To set mag conversion rate:  CRA_REG_M   (0000000) (00011100) (220Hz, Temperature Disable)
#To turn on Accel + Set rate: CTRL_REG1_A (0100000) (01100111) (200Hz, Normal, all EN)
#To turn on Mag:              MR_REG_M    (0000010) (00000000) (Coyntiuous conversion mode)


def two_signed_A(val):
    val = bin(val)[2:]
    val = val[8:16] + val[0:8]
    sig_digit = int(val[0])
    mult = 1
    for i in range(len(val)-1):
        mult*=2
    val = val[1:]
    #print(val)
    new_int = int(val, 2)
    #print(new_int)
    sig_digit = sig_digit * -1 * mult
    return (sig_digit + new_int)

def two_signed_M(val):
    val = bin(val)[2:]
    sig_digit = int(val[0])
    mult = 1
    for i in range(len(val)-1):
        mult*=2
    val = val[1:]
    #print(val)
    new_int = int(val, 2)
    #print(new_int)
    sig_digit = sig_digit * -1 * mult
    return (sig_digit + new_int)

def i2c_function():
    timedelay1 = 0.03
    timedelay2 = 0.02
    try:
        readloop = input("Do you want to continuously read [Y/N]")
        if(readloop.upper() == 'N'):
            slave_addr = input("Enter the slave address (binary upper 7 bits): ")
            sub_addr = input("Enter the sub address (binary lower 7 bits): ")
            read = input("Enter 1 if you wish to perform a read, 0 if to perform a write: ")
            if(int(read) != 1):
                writedata = input("Enter the write data (binary 8 bits): ")
                num_bytes = "00000000"
            else:
                num_bytes = input("Enter the number of bytes to read (8 bit binary): ")
                writedata = "00000000"
            #print("Here is the slave address:", slave_addr, "Here is the sub address:", sub_addr, "Here is the read:", read, "Here is the writedata", writedata, "Here is the num bytes", num_bytes)
            inputvector = slave_addr + sub_addr + read + writedata + num_bytes
            print("Concatanation:", inputvector)
            inputvector = int(inputvector, 2)
            print("Converting to int:", inputvector)
            #inputvector = int((slave_addr + sub_addr + read + writedata + num_bytes), 2) # SlaveAddr + SubAddr + RW + WD + RB
            control = 1
            print("Input manual vector", bin(inputvector))
            dev.SetWireInValue(0x00, control)
            dev.SetWireInValue(0x01, inputvector)
            dev.UpdateWireIns()
            time.sleep(0.020)
            control = 0
            dev.SetWireInValue(0x00, control)
            dev.UpdateWireIns()
            dev.UpdateWireOuts()
            if (str(read) == '1'):
                readdata = dev.GetWireOutValue(0x20) # Transfer the received data in variable
                readdata = bin(readdata)[2:]
                print("ReadData:", readdata)

        else:
            enter_x = input("Press Any key to calibrate Accel X -1g")
            # Calibrate Accel X
            control = 1
            inputvector = int(('0011001' + '0101000' + '1' + '00000000' + '00000010'), 2) # Accel + OUT_X_L_A + Read + None + 2
            print("input vector Accel X", inputvector)
            dev.SetWireInValue(0x00, control)
            dev.SetWireInValue(0x01, inputvector)
            dev.UpdateWireIns() # Ask to read Accel X
            time.sleep(timedelay1)
            control = 0
            dev.SetWireInValue(0x00, control)
            dev.UpdateWireIns() # Turn off read control
            time.sleep(timedelay2)
            dev.UpdateWireOuts()
            AccelX = dev.GetWireOutValue(0x20) # Transfer the received data in variable


            AccelXNegG = two_signed_A(AccelX)
            print("AccelXNegG = ", AccelXNegG)
            time.sleep(0.010)


            enter_y = input("Press Any key to calibrate Accel Y -1g")
            # Calibrate Accel Y
            control = 1
            inputvector = int(('0011001' + '0101010' + '1' + '00000000' + '00000010'), 2) # Accel + OUT_Y_L_A + Read + None + 2
            print("input vector Accel Y", inputvector)
            dev.SetWireInValue(0x00, control)
            dev.SetWireInValue(0x01, inputvector)
            dev.UpdateWireIns() # Ask to read Accel Y
            time.sleep(timedelay1)
            control = 0
            dev.SetWireInValue(0x00, control)
            dev.UpdateWireIns() # Turn off read control
            time.sleep(timedelay2)
            dev.UpdateWireOuts()
            AccelY = dev.GetWireOutValue(0x20) # Transfer the received data in variable


            AccelYNegG = two_signed_A(AccelY)
            print("AccelYNegG = ", AccelYNegG)
            time.sleep(0.010)

            enter_z = input("Press Any key to calibrate Accel Z -1g")
            # Calibrate Accel Z
            control = 1
            inputvector = int(('0011001' + '0101100' + '1' + '00000000' + '00000010'), 2) # Accel + OUT_Z_L_A + Read + None + 2
            print("input vector Accel Z", inputvector)
            dev.SetWireInValue(0x00, control)
            dev.SetWireInValue(0x01, inputvector)
            dev.UpdateWireIns() # Ask to read Accel Z
            time.sleep(timedelay1)
            control = 0
            dev.SetWireInValue(0x00, control)
            dev.UpdateWireIns() # Turn off read control
            time.sleep(timedelay2)
            dev.UpdateWireOuts()
            AccelZ = dev.GetWireOutValue(0x20) # Transfer the received data in variable


            AccelZNegG = two_signed_A(AccelZ)
            print("AccelZNegG = ", AccelZNegG)


            print("Press Ctrl + C to exit out of read loop")
            time.sleep(1)
            while (True):
                # Read Accel X
                control = 1
                inputvector = int(('0011001' + '0101000' + '1' + '00000000' + '00000010'), 2) # Accel + OUT_X_L_A + Read + None + 2
                dev.SetWireInValue(0x00, control)
                dev.SetWireInValue(0x01, inputvector)
                dev.UpdateWireIns() # Ask to read Accel X
                time.sleep(timedelay1)
                control = 0
                dev.SetWireInValue(0x00, control)
                dev.UpdateWireIns() # Turn off read control
                timedelay2 = 0.010
                try:
                    time.sleep(timedelay2)
                    dev.UpdateWireOuts()
                    AccelX = two_signed_A(dev.GetWireOutValue(0x20)) # Transfer the received data in variable
                    AccelXNormal = -1*(AccelX/AccelXNegG)
                except:
                    while(True):
                        timedelay2 += 0.010
                        print("AccelX While Loop", timedelay2)
                        try:
                            time.sleep(timedelay2)
                            dev.UpdateWireOuts()
                            AccelX = two_signed_A(dev.GetWireOutValue(0x20)) # Transfer the received data in variable
                            AccelXNormal = -1*(AccelX/AccelXNegG)
                            break 
                        except:
                            continue
                time.sleep(0.010)

                # Read Accel Y
                control = 1
                inputvector = int(('0011001' + '0101010' + '1' + '00000000' + '00000010'), 2) # Accel + OUT_Y_L_A + Read + None + 2
                dev.SetWireInValue(0x00, control)
                dev.SetWireInValue(0x01, inputvector)
                dev.UpdateWireIns() # Ask to read Accel Y
                time.sleep(timedelay1)
                control = 0
                dev.SetWireInValue(0x00, control)
                dev.UpdateWireIns() # Turn off read control
                dev.UpdateWireOuts()
                timedelay2 = 0.010
                try:
                    time.sleep(timedelay2)
                    AccelY = two_signed_A(dev.GetWireOutValue(0x20)) # Transfer the received data in variable
                    AccelYNormal = -1*(AccelY/AccelYNegG)
                except:
                    while(True):
                        timedelay2 += 0.010
                        print("AccelY While Loop", timedelay2)
                        try:
                            time.sleep(timedelay2)
                            AccelY = two_signed_A(dev.GetWireOutValue(0x20)) # Transfer the received data in variable
                            AccelYNormal = -1*(AccelY/AccelYNegG)
                            break 
                        except:
                            continue
                # try:
                #     dev.UpdateWireOuts()
                #     AccelY = two_signed_A(dev.GetWireOutValue(0x20)) # Transfer the received data in variable
                #     AccelYNormal = -1*(AccelY/AccelYNegG)
                # except:
                #     test = input("Do you want to try again")
                #     while(test.upper() != "N"):
                #         try:
                #             dev.UpdateWireOuts()
                #             AccelY = two_signed_A(dev.GetWireOutValue(0x20)) # Transfer the received data in variable
                #             AccelYNormal = -1*(AccelY/AccelYNegG)
                #             break 
                #         except:
                #             test = input("Do you want to try again")
                time.sleep(0.010)

                # Read Accel Z
                control = 1
                inputvector = int(('0011001' + '0101100' + '1' + '00000000' + '00000010'), 2) # Accel + OUT_Z_L_A + Read + None + 2
                dev.SetWireInValue(0x00, control)
                dev.SetWireInValue(0x01, inputvector)
                dev.UpdateWireIns() # Ask to read Accel Z
                time.sleep(timedelay1)
                control = 0
                dev.SetWireInValue(0x00, control)
                dev.UpdateWireIns() # Turn off read control
                time.sleep(timedelay2)
                dev.UpdateWireOuts()
                time_sleep = 0.010
                try:
                    AccelZ = two_signed_A(dev.GetWireOutValue(0x20)) # Transfer the received data in variable
                    AccelZNormal = -1*(AccelZ/AccelZNegG)
                    time.sleep(time_sleep)
                except:
                    while(True):
                        time_sleep += 0.010
                        print("AccelZ While Loop", time_sleep)
                        try:
                            AccelZ = two_signed_A(dev.GetWireOutValue(0x20)) # Transfer the received data in variable
                            AccelZNormal = -1*(AccelZ/AccelZNegG)
                            time.sleep(time_sleep)
                            break 
                        except:
                            continue

                # Read Mag X
                control = 1
                inputvector = int(('0011110' + '0000011' + '1' + '00000000' + '00000010'), 2) # Mag + OUT_X_H_M + Read + None + 2
                dev.SetWireInValue(0x00, control)
                dev.SetWireInValue(0x01, inputvector)
                dev.UpdateWireIns() # Ask to read Mag X
                time.sleep(timedelay1)
                control = 0
                dev.SetWireInValue(0x00, control)
                dev.UpdateWireIns() # Turn off read control
                time.sleep(timedelay2)
                dev.UpdateWireOuts()
                time_sleep = 0.010
                try:
                    MagX = two_signed_M(dev.GetWireOutValue(0x20)) # Transfer the received data in variable
                    MagXNormal = MagX/670
                    time.sleep(0.010)
                except:
                    while(True):
                        print("MagX While Loop", time_sleep)
                        time_sleep += 0.010
                        try:
                            MagX = two_signed_M(dev.GetWireOutValue(0x20)) # Transfer the received data in variable
                            MagXNormal = MagX/670
                            time.sleep(0.010)
                            break 
                        except:
                            continue

                # Read Mag Y
                control = 1
                inputvector = int(('0011110' + '0000111' + '1' + '00000000' + '00000010'), 2) # Mag + OUT_Y_H_M + Read + None + 2
                dev.SetWireInValue(0x00, control)
                dev.SetWireInValue(0x01, inputvector)
                dev.UpdateWireIns() # Ask to read Mag Y
                time.sleep(timedelay1)
                control = 0
                dev.SetWireInValue(0x00, control)
                dev.UpdateWireIns() # Turn off read control
                time.sleep(timedelay2)
                dev.UpdateWireOuts()
                time_sleep = 0.010
                try:
                    MagY = two_signed_M(dev.GetWireOutValue(0x20)) # Transfer the received data in variable
                    MagYNormal = MagY/670
                    time.sleep(time_sleep)
                except:
                    while(True):
                        time_sleep += .010
                        print("MagY While Loop", time_sleep)
                        try:
                            MagY = two_signed_M(dev.GetWireOutValue(0x20)) # Transfer the received data in variable
                            MagYNormal = MagY/670
                            time.sleep(time_sleep)
                            break
                        except:
                            continue
                # Read Mag Z
                control = 1
                inputvector = int(('0011110' + '0000101' + '1' + '00000000' + '00000010'), 2) # Mag + OUT_Z_H_M + Read + None + 2
                dev.SetWireInValue(0x00, control)
                dev.SetWireInValue(0x01, inputvector)
                dev.UpdateWireIns() # Ask to read Mag Z
                time.sleep(timedelay1)
                control = 0
                dev.SetWireInValue(0x00, control)
                dev.UpdateWireIns() # Turn off read control
                time.sleep(timedelay2)
                dev.UpdateWireOuts()
                time_sleep = 0.010
                try:
                    MagZ = two_signed_M(dev.GetWireOutValue(0x20)) # Transfer the received data in variable
                    MagZNormal = MagZ/670
                    time.sleep(time_sleep)
                except:
                    while(True):
                        print("MagZ While Loop", time_sleep)
                        time_sleep += .010
                        try:
                            MagZ = two_signed_M(dev.GetWireOutValue(0x20)) # Transfer the received data in variable
                            MagZNormal = MagZ/670
                            time.sleep(time_sleep)
                            break
                        except:
                            continue

                print("=======================================================================")
                print("AccelX:", AccelXNormal, "g")
                print("AccelY:", AccelYNormal, "g")
                print("AccelZ:", AccelZNormal, "g")
                print("MagX:", MagXNormal, "Gauss")
                print("MagY:", MagYNormal, "Gauss")
                print("MagZ:", MagZNormal, "Gauss")
                print("=======================================================================")


    except KeyboardInterrupt:
        print("Exited")
        dev.SetWireInValue(0x00, control)
        dev.UpdateWireIns()
        return -1

#try:
out = i2c_function()
if out == -1:
    test = input("Do you want to close (Y/N)")
    while(test.upper() != "Y"):
       out = i2c_function() 
       test = input("Do you want to close (Y/N)")
    dev.Close