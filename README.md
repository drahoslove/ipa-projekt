# ipa-projekt
Cellular automaton

## build
**require**
* http://www.nasm.us/
* http://alink.sourceforge.net/
```
nasm -fobj ca.asm 
alink -oPE ca.obj
```

## run
```
ca.exe [-h] [-s] [-p] [-d WH]
  -h show help
  -s show stats
  -p auto play
  -d dimension (Height Width 0-9)
```
