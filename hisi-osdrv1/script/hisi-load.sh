#!/bin/sh


#################### Variables Definition ##########################

mem_start=0x80000000

totmem_size=$(awk -F '=' '$1=="totalmem"{print $2}' RS=" " /proc/cmdline)
totmem_size=${totmem_size:=64M}

osmem_size=$(awk -F '=' '$1=="mem"{print $2}' RS=" " /proc/cmdline)
osmem_size=${osmem_size:=40M}

SNS_TYPE=$(awk -F '=' '$1=="sensor"{print $2}' RS=" " /proc/cmdline)
SNS_TYPE=${SNS_TYPE:=ov9712}

####################################################################

usage="\
Usage: $0 [OPTIONS]
OPTIONS:
    -i                      insert modules
    -r                      remove modules
    -a                      remove modules, then insert modules
    -h                      display this help message
    -sensor=SENSOR          config sensor type [default: $SNS_TYPE]
    -osmem=SIZE             config OS memory size [default: $osmem_size]
    -totalmem=SIZE          config total memory size [default: $total_size]
    -online                 VI/VPSS online mode
    -offline                VI/VPSS offline mode
    -restore                restore hardware

EXAMPLES:
    online mode:      $0 -a -osmem 40M -totalmem=64M -online
    offline mode:     $0 -a -osmem 40M -totalmem=64M -offline
"

####################################################################

insert_audio()
{
  insmod acodec.ko
  insmod hidmac.ko
  insmod hi3518_sio.ko
  insmod hi3518_ai.ko
  insmod hi3518_ao.ko
  insmod hi3518_aenc.ko
  insmod hi3518_adec.ko
  echo "insert audio"
}

####################################################################

remove_audio()
{
    rmmod hi3518_adec
    rmmod hi3518_aenc
    rmmod hi3518_ao
    rmmod hi3518_ai
    rmmod hi3518_sio
    rmmod acodec
    rmmod hidmac
    echo "remove audio..."
}

####################################################################

insert_sns()
{
    case $SNS_TYPE in

        ar0130|9m034)
            himm 0x20030030 0x5;              # Sensor clock 27 MHz
            insmod ssp_ad9020.ko;
            ;;

        icx692)
            himm 0x200f000c 0x1;              # pinmux SPI0
            himm 0x200f0010 0x1;              # pinmux SPI0
            himm 0x200f0014 0x1;              # pinmux SPI0
            insmod ssp_ad9020.ko;
            ;;

        mn34031|mn34041)
            himm 0x200f000c 0x1;              # pinmux SPI0
            himm 0x200f0010 0x1;              # pinmux SPI0
            himm 0x200f0014 0x1;              # pinmux SPI0
            himm 0x20030030 0x5;              # Sensor clock 27MHz
            insmod ssp_pana.ko;
            ;;

        imx104|imx122|imx138)
            himm 0x200f000c 0x1;              # pinmux SPI0
            himm 0x200f0010 0x1;              # pinmux SPI0
            himm 0x200f0014 0x1;              # pinmux SPI0
            himm 0x20030030 0x6;              # Sensor clock 37.125 MHz
            insmod ssp_sony.ko;
            ;;

        ov9712|soih22|ov2710)
            himm 0x20030030 0x1;              # Sensor clock 24 MHz
            insmod ssp_ad9020.ko;
            ;;

        mt9p006)
            himm 0x20030030 0x1;              # Sensor clock 24 MHz
            himm 0x2003002c 0x6a;             # VI input associated clock phase reversed
            insmod ssp_ad9020.ko;
            ;;

        hm1375)
            himm 0x20030030 0x1;              # Sensor clock 24 MHz
            ;;

        *)
            echo "Invalid sensor type $SNS_TYPE"
            exit 1;;
    esac
}

####################################################################

remove_sns()
{
    rmmod hi_i2c
    rmmod ssp
    rmmod ssp_sony
    rmmod ssp_pana
    rmmod ssp_ad9020
}

####################################################################

insert_ko()
{

  # Low power control
  # hisi-lowpower.sh

  # pinmux configuration
  hisi-pinmux.sh net i2c

  # clock configuration
  hisi-clkcfg.sh

  #
  # Driver load
  local totmem=$((${totmem_size/M/*0x100000}))
  local osmem=$((${osmem_size/M/*0x100000}))
  local mmz_start=$(printf "0x%08x" $((mem_start + osmem)))
  local mmz_size=$(((totmem - osmem)/0x100000))M
  #
  insmod mmz.ko mmz=anonymous,0,$mmz_start,$mmz_size anony=1 || exit 1

  insmod hi3518_base.ko
  insmod hi3518_sys.ko
  insmod hiuser.ko

  insmod hi3518_tde.ko
  insmod hi3518_dsu.ko

  insmod hi3518_viu.ko
  insmod hi3518_isp.ko
  insmod hi3518_vpss.ko
  insmod hi3518_vou.ko
  #insmod hi3518_vou.ko detectCycle=0 #close dac detect
  insmod hifb.ko video="hifb:vram0_size:1620"

  insmod hi3518_venc.ko
  insmod hi3518_group.ko
  insmod hi3518_chnl.ko
  insmod hi3518_h264e.ko
  insmod hi3518_jpege.ko
  insmod hi3518_rc.ko
  insmod hi3518_region.ko

  insmod hi3518_vda.ko
  insmod hi3518_ive.ko
  #insmod gpio.ko             # Temporarily disabled
  #insmod md127.ko
  #insmod ap1511.ko           # Temporarily disabled
  insmod hi_i2c.ko
  #insmod gpioi2c.ko
  #insmod gpioi2c_ex.ko
  insmod pwm.ko
  #insmod wdt.ko nowayout=1   # Temporarily disabled
  #insmod sil9024.ko norm=5   #720P@60fps

  insert_sns

  #insmod hi3518_isp.ko
  insert_audio
  echo "Sensor TYPE: $SNS_TYPE"
  echo

  # system configuration
  hisi-sysctl.sh
}

####################################################################

remove_ko()
{
    remove_audio
    remove_sns

    rmmod sil9024
    rmmod hi_i2c.ko
    rmmod pwm
    #rmmod gpioi2c

    rmmod hi3518_ive
    rmmod hi3518_vda

    rmmod hi3518_region
    rmmod hi3518_rc
    rmmod hi3518_jpege
    rmmod hi3518_h264e
    rmmod hi3518_chnl
    rmmod hi3518_group
    rmmod hi3518_venc
  
    rmmod hifb
    rmmod hi3518_vou
    rmmod hi3518_vpss
    rmmod hi3518_isp
    rmmod hi3518_viu

    rmmod hi3518_dsu
    rmmod hi3518_tde

    rmmod hiuser
    rmmod hi3518_sys
    rmmod hi3518_base
    rmmod mmz
}

####################################################################

local totmem=$((${totmem_size/M/*0x100000}))
local osmem=$((${osmem_size/M/*0x100000}))

echo
echo "====================="
echo
echo "Sensor table:"
echo " 9m034"
echo " ar0130"
echo " himax1375"
echo " icx692"
echo " imx104, imx122, imx138"
echo " mn34031"
echo " mt9p006"
echo " ov2710, ov9712"
echo " soih22"
echo
echo "====================="
echo
echo "Current options:"
echo " - processor: $(awk '/Hardware/ {print $3}' /proc/cpuinfo)"
echo " - total memory: ${totmem_size}"
echo " - linux memory: ${osmem_size}"
echo " - sensor: ${SNS_TYPE}"
echo " - mem_start: ${mem_start}"
echo " - mmz_start: $(printf "0x%08x" $((mem_start + osmem)))"
echo " - mmz_size: $(((totmem - osmem)/0x100000))M"
echo
echo "====================="
echo

remove_ko
insert_ko

####################################################################
