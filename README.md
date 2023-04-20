# easyScripts
some script to faster config your servers

## vbs.sh

### Manual 
```shell
bash <(curl -Ls https://raw.githubusercontent.com/foroughi1380/easyScripts/master/vbs.sh)
```

### Automatic
donlowd script on your system

#### server
```shell
vbs.sh -s [new ssh port] -b -x
```

#### bridge

```shell
vbs.sh -s [new ssh port] -b -p [bridge ip] [destination server ip] 
```
