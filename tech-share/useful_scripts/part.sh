#!/bin/bash
####挂载大容量盘
mkdir /u0{1..9} /u10

parted /dev/sdj mklabel gpt mkpart e1 ext3 1 100%
mkfs.xfs -n ftype=1 /dev/sdj1
mount /dev/sdj1 /u01

parted /dev/sdi mklabel gpt mkpart d1 ext3 1 100%
mkfs.xfs -n ftype=1 /dev/sdi1
mount /dev/sdi1 /u02

parted /dev/sdh mklabel gpt mkpart c1 ext3 1 100%
mkfs.xfs -n ftype=1 /dev/sdh1
mount /dev/sdh1 /u03

parted /dev/sdg mklabel gpt mkpart b1 ext3 1 100%
mkfs.xfs -n ftype=1 /dev/sdg1
mount /dev/sdg1 /u04

parted /dev/sdf mklabel gpt mkpart a1 ext3 1 100%
mkfs.xfs -n ftype=1 /dev/sdf1
mount /dev/sdf1 /u05

parted /dev/sde mklabel gpt mkpart e1 ext3 1 100%
mkfs.xfs -n ftype=1 /dev/sde1
mount /dev/sde1 /u06

parted /dev/sdd mklabel gpt mkpart d1 ext3 1 100%
mkfs.xfs -n ftype=1 /dev/sdd1
mount /dev/sdd1 /u07

parted /dev/sdc mklabel gpt mkpart c1 ext3 1 100%
mkfs.xfs -n ftype=1 /dev/sdc1
mount /dev/sdc1 /u08

parted /dev/sdb mklabel gpt mkpart b1 ext3 1 100%
mkfs.xfs -n ftype=1 /dev/sdb1
mount /dev/sdb1 /u09

parted /dev/sda mklabel gpt mkpart a1 ext3 1 100%
mkfs.xfs -n ftype=1 /dev/sda1
mount /dev/sda1 /u10

####清除ceph安装
ceph-deploy purge cac-214 cac-225 cac-226 cac-227 cac-228
ceph-deploy purgedata cac-214 cac-225 cac-226 cac-227 cac-228
ceph-deploy forgetkeys
####创建ceph存储集群
ceph-deploy new cac-214 cac-225 cac-226 cac-227 cac-228
ceph-deploy --overwrite-conf mon create-initial
sudo chmod +r /etc/ceph/ceph.client.admin.keyring
chmod 777 /osd-{1..25}
ceph-deploy osd prepare cac-214:/osd-{1..5} cac-225:/osd-{6..10} cac-226:/osd-{11..15} cac-227:/osd-{16..20} cac-228:/osd-{21..25}
ceph-deploy osd activate cac-214:/osd-{1..5} cac-225:/osd-{6..10} cac-226:/osd-{11..15} cac-227:/osd-{16..20} cac-228:/osd-{21..25}