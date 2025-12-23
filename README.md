# ECE 551 — Segway Control System  
ALL THANKS TO THE INSTRUCTORS: PROFESSOR HOFFMAN AND HSIAO <br>

Fall 2025

This project implements the digital control logic for a self-balancing “Segway-like” platform using SystemVerilog. The FPGA controls motor drive, inertial sensing, rider detection, steering, BLE authentication, battery monitoring, and audible warnings.

---

## 1. System Summary

The FPGA synthesizable design includes:

- Inertial sensor SPI interface + integrator (pitch & acceleration)
- PID-based balance controller
- Steering enable and steering torque adjustment
- A2D interface for load cells, battery, and steering pot
- BLE-based authorization block (UART receiver + state machine)
- Piezo driver for alerts (too-fast, battery-low, steering-enabled)
- Motor driver (PWM + over-current protection)

## 2. Synthesizable Modules

- `Segway.sv` (top-level)
- `auth_blk`
- `UART_rcv`
- `piezo_drv`
- `SPI_mnrch` (SPI master)
- `A2D_intf`
- `inert_intf`
- `inertial_integrator`
- `balance_cntrl` (PID + steering math)
- `en_steer`
- `mtr_drv` (provided; must not be modified)

Simulation models (non-synthesizable) provided:

- Inertial sensor model  
- ADC model  
- Segway physics model  
- BLE model  

---

## 3. Major Functional Requirements

### **BLE Authorization**
- UART 19200 baud, 8N1
- `'G' (0x47)` → enable (`pwr_up`)
- `'S' (0x53)` → disable if rider has stepped off

### **Piezo Driver**
- `too_fast`: looping 3-note warning  
- `batt_low`: reversed fanfare every 3s  
- `en_steer`: fanfare every 3s  
- Otherwise: silent  
- Includes `fast_sim` parameter (frequency ×64, duration ÷64)

### **SPI_mnrch**
- 16-bit packets  
- SCLK = clk / 16  
- MOSI shifts on falling edge, MISO sampled on rising edge  
- Driven only by system `clk` (never by SCLK)

### **A2D Interface**
Round-robin reading of:  
- Left load cell (ch 0)  
- Right load cell (ch 4)  
- Steering pot (ch 5)  
- Battery (ch 6)  

Two SPI transfers per reading (command + data).

### **Inertial Sensor Interface**
Reads:
- Pitch rate low/high  
- AZ low/high  
Initializes device via 4 register writes.  
Triggers integrator on each valid update.

### **Inertial Integrator & Fusion**
- Integrates pitch rate  
- Computes accelerometer-based pitch  
- Fusion adjusts drift using ±1024 corrections

### **Balance Control (PID)**
- P, I, D combination on pitch error  
- Derivative approximated via small FIFO  
- Steering offset added/subtracted when enabled

### **Torque Dead-Zone Compensation**
- Small torque amplified  
- Larger torque offset by MIN_DUTY  
- Disabled unless `pwr_up` asserted

### **Steering Enable**
- Uses load-cell sum/diff + hysteresis  
- Includes 1.34s timer (accelerated in fast_sim)

### **Motor Driver**
- Provided module  
- Over-current protection must be validated  

---

## 4. Top-Level Interface (Segway.sv)
<pr> 
clk, RST_n
INERT_SS_n, INERT_SCLK, INERT_MOSI, INERT_MISO, INERT_INT
A2D_SS_n, A2D_SCLK, A2D_MOSI, A2D_MISO
RX
PWM1_lft, PWM2_lft, PWM1_rght, PWM2_rght
OVR_I_lft, OVR_I_rght
piezo, piezo_n
</pr>
