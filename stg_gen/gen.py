import os
import sys

pos_digit = 4

base_name = os.path.splitext(sys.argv[1])[0]
stg_output = ''
with open(sys.argv[1]) as f:
    for line in f.readlines():
        s = line.split(' ')
        for ele in s[:3]:
            ele = int(ele)
            ele_in_hex = "{:0{width}X}".format(ele, width=pos_digit)   # change digit number for bigger stage
            # print(f"{ele} => "+ele_in_hex)
            stg_output += ele_in_hex

        stat = '000'+s[3]

        stg_output += f"{int(stat,2):01X}\n"

with open(base_name+'.mem', 'w') as f:
    f.write(f"// L({pos_digit})+R({pos_digit})+H({pos_digit})+status(1)\n")
    f.write(stg_output)