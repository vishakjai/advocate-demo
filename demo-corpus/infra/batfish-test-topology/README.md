# batfish-test-topology

## Blog

### L2 topology test
* [BatfishでL2 Topologyを出せるかどうか調べてみる (1) - Qiita](https://qiita.com/corestate55/items/50ba0ae3e204d84fb03e)
* [BatfishでL2 Topologyを出せるかどうか調べてみる (2) - Qiita](https://qiita.com/corestate55/items/bfac369b3f4532e5acef)
* [NW機器のコンフィグから力業でL2トポロジを作る - Qiita](https://qiita.com/corestate55/items/8fa006d1e30f49da36f6)

### L3 topology test
- [Batfish を使ってネットワーク構成を可視化してみよう・改 - Qiita](https://qiita.com/corestate55/items/fb18066d1105010758d9)
- [マルチレイヤなNWトポロジ情報から検証環境を作ってみる(1) - 概要 - Qiita](https://qiita.com/corestate55/items/ba966cc1c73e877f5bee)
- [マルチレイヤなNWトポロジ情報から検証環境を作ってみる(2) - L3/OSPF/BGP - Qiita](https://qiita.com/corestate55/items/02f6ce5c6b0af47220dc)
- [マルチレイヤなNWトポロジ情報から検証環境を作ってみる(3) - 検討 - Qiita](https://qiita.com/corestate55/items/567a4693abd67e1a5531)

## L2 topology

### sample1

* different L2 segments

```
    host11    12    13    14       host21    22    23    24
     .101| .102| .103| .104|        .101| .102| .103| .104|
         |     |     |     |            |     |     |     |
   gi1/0/1     2     3     4            5     6     7     8
         |     |     |     |            |     |     |     |
       --+-----+-----+-----+-- VL100  --+-----+-----+-----+-- VL200
         |            192.168.1.0/24                 192.168.2.0/24
         |.1
       Vlan100
       GRT
```

### sample2

* same ip subnet but different L2 segment.

```
    host11    12    13    14       host21    22    23    24
     .101| .102| .103| .104|        .101| .102| .103| .104|
         |     |     |     |            |     |     |     |
   gi1/0/1     2     3     4            5     6     7     8
         |     |     |     |            |     |     |     |
       --+-----+-----+-----+-- VL100  --+-----+-----+-----+-- VL200
         |            192.168.1.0/24    |            192.168.1.0/24
         |.1                            |.1
       Vlan100                         Vlan200
       GRT                             VRF(user2)
```

### sample3

* 2-switch version of sample1.

```
    host11    12           host21    22               host13    14           host23    24
     .101| .102|            .101| .102|                .103| .104|            .103| .104|
         |     |                |     |                    |     |                |     |
   gi1/0/1     2          gi1/0/5     6              gi1/0/3     4          gi1/0/7     8
         |     |                |     |                    |     |                |     |
       --+-----+--            --+-----+--                --+-----+--            --+-----+--
         |.1   192.168.1.0/24         192.168.2.0/24       |.1   192.168.1.0/24         192.168.2.0/24
       Vlan100                Vlan200                    Vlan100                Vlan200
       GRT                                               GRT
       switch1                                           switch2

  switch1              switch3
  Po1 gi1/0/23 -- gi1/0/23 Po1 (trunk vlan100,200)
      gi1/0/24 -- gi1/0/24
```

### sample4

* 2-switch version of sample2.

```
    host11    12           host21    22               host13    14           host23    24
     .101| .102|            .101| .102|                .103| .104|            .103| .104|
         |     |                |     |                    |     |                |     |
   gi1/0/1     2          gi1/0/5     6              gi1/0/3     4          gi1/0/7     8
         |     |                |     |                    |     |                |     |
       --+-----+--            --+-----+--                --+-----+--            --+-----+--
         |.1   192.168.1.0/24         192.168.1.0/24       |.1   192.168.1.0/24   |.1   192.168.1.0/24
       Vlan100                Vlan200                    Vlan100                Vlan200
       GRT                    VRF(user2)                 GRT                    VRF(user2)
       switch1                                           switch2

  switch1              switch3
  Po1 gi1/0/23 -- gi1/0/23 Po1 (trunk vlan100,200)
      gi1/0/24 -- gi1/0/24
```

### sample5

* A variant of sample4. (different vlan-id but same L2 segment)

```
    host11    12           host21    22               host13    14           host23    24
     .101| .102|            .101| .102|                .103| .104|            .103| .104|
         |     |                |     |                    |     |                |     |
   gi1/0/1     2          gi1/0/5     6              gi1/0/3     4          gi1/0/7     8
         |     |                |     |                    |     |                |     |
       --+-----+--            --+-----+--                --+-----+--            --+-----+--
         |.1   192.168.1.0/24         192.168.1.0/24       |.1   192.168.1.0/24   |.1   192.168.1.0/24
       Vlan100                Vlan200                    Vlan200                Vlan300
       GRT                    VRF(user2)                 GRT                    VRF(user2)
       switch1                                           switch2

  switch1                          switch3
  vlan100 - gi1/0/23 -- gi1/0/23 - vlan200
  vlan200 - gi1/0/24 -- gi1/0/24 - vlan300
```

## L2-L3 topology

### L2 sample3-modified

```text
    host11    12           host21    22               host13    14           host23    24
     .101| .102|            .101| .102|                .103| .104|            .103| .104|
         |     |                |     |                    |     |                |     |
   gi1/0/1     2          gi1/0/5     6              gi1/0/3     4          gi1/0/7     8
         |     |                |     |                    |     |                |     |
       --+-----+--            --+-----+--                --+-----+--            --+-----+--
         |.1   192.168.1.0/24         192.168.2.0/24       |.1   192.168.1.0/24         192.168.2.0/24
       Vlan100                Vlan200                    Vlan100                Vlan200
       GRT         switch1                               GRT         switch2
         |.2                                               |.2
         |     10.0.1.0/24                                 |     10.0.2.0/24
         |.1                                               |.1
     Fa1/0                                             Fa1/1
     GRT           router1

                      switch1              switch2
  (trunk vlan 100,200) Po1 gi1/0/23 -- gi1/0/23 Po1 (trunk vlan100,200)
                           gi1/0/24 -- gi1/0/24
```

### L2 sample3-modified (Abnormal case)

```text

                                       host31                                           host33
                                            | .101                                           | .103
                                  ----------+--                                    ----------+--
                           192.168.201.0/24 |                               192.168.201.0/24 |
                                      Vlan201                                          Vlan201
                                            |.2                                              |.3
    host11    12           host21    22   testvrf     host13    14           host23    24  testvrf
     .101| .102|            .101| .102|   .2|          .103| .104|            .103| .104|  .3|
         |     |                |     |     |              |     |                |     |    |
   gi1/0/1     2          gi1/0/5     6   Vlan200    gi1/0/3     4          gi1/0/7     8  Vlan200
         |     |                |     |     |              |     |                |     |    |
       --+-----+--            --+-----+-----+--          --+-----+--            --+-----+-----+--
         |.1   192.168.1.0/24         192.168.2.0/24       |.1   192.168.1.0/24         192.168.2.0/24
       Vlan100                Vlan200                    Vlan100                Vlan200
       GRT         switch1                               GRT         switch2
         |.2                                               |.2
         |     10.0.1.0/24                                 |     10.0.2.0/24
         |.1                                               |.1
     Fa1/0                                             Fa1/1
     GRT           router1

                           switch1              switch2
  (trunk vlan 100,200-201) Po1 gi1/0/23 -- gi1/0/23 Po1 (trunk vlan100,200)
                               gi1/0/24 -- gi1/0/24
```


## Resources

path

```
$HOME
 +- batfish/
     +- bf-venv/               : venv for pybatfish
     +- batfish-test-topology/ : this repository
```

### Setup pybatfish env

Create venv and activate it.

```shell
cd $HOME
mkdir batfish
cd batfish
sudo apt install python3-venv
python3 -m venv bf-venv
. bf-venv/bin/activate
# prompt will change `(bf-venv)`
```

kInstall pybatfish in the venv.

```shell
pip install wheel
python3 -m pip install --upgrade git+https://github.com/batfish/pybatfish.git
```

### Run batfish container

Download (update) and run batfish container.

```shell
cd ~/batfish/batfish-test-topology/
docker-compose pull
docker-compose up -d
```

### Run python with interactive mode

```shell
cd ~/batfish/batfish-test-topology/
. ~/batfish/bf-venv/bin/activate
python -i setup_bfq.py ./sample1/
# enter interactive mode python
```

### Query examples

Edges

```python
# layer3
ans = bfq.edges(edgeType='layer3')
ans.answer().frame()

# layer1
ans = bfq.edges(edgeType='layer1')
ans.answer().frame()

# select edges by host name
df = ans.answer().frame()
df.loc[list(map(lambda d: d.hostname=='host11', df.Interface.values))]
```

Reachability

```python
# from host11
# to host14
ans = bfq.traceroute(startLocation='@enter(host11[eth0])', headers=HeaderConstraints(dstIps='192.168.1.104',srcIps='192.168.1.101'))
# to router1
ans = bfq.traceroute(startLocation='@enter(host11[eth0])', headers=HeaderConstraints(dstIps='10.0.1.1',srcIps='192.168.1.101'))
# via router1 to switch2
ans = bfq.traceroute(startLocation='@enter(host11[eth0])', headers=HeaderConstraints(dstIps='10.0.2.2',srcIps='192.168.1.101'))

# output check
print(ans..answer().frame().to_csv())
```
