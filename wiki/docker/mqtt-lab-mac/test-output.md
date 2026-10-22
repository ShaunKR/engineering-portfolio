# 실행 로그

## 컨테이너 상태

```text
NAME                      IMAGE                   COMMAND                  SERVICE    CREATED         STATUS                        PORTS
mqtt-lab-mac-broker-a-1   emqx/emqx:5.0.26        "/usr/bin/docker-ent…"   broker-a   4 minutes ago   Up About a minute (healthy)   127.0.0.1:18083->18083/tcp, 127.0.0.1:18831->1883/tcp
mqtt-lab-mac-broker-b-1   emqx/emqx:5.0.26        "/usr/bin/docker-ent…"   broker-b   4 minutes ago   Up 4 minutes (healthy)        127.0.0.1:18832->1883/tcp, 127.0.0.1:18084->18083/tcp
mqtt-lab-mac-haproxy-1    haproxy:3.0.11-alpine   "docker-entrypoint.s…"   haproxy    4 minutes ago   Up 55 seconds                 127.0.0.1:1883->1883/tcp
```

## broker-a cluster status

```text
Cluster status: #{running_nodes => ['emqx@broker-a.local'],
                  stopped_nodes => []}
```

## broker-b cluster status

```text
Cluster status: #{running_nodes => ['emqx@broker-b.local'],
                  stopped_nodes => []}
```

## mqtt-lab-check-a1

```text
Client a1 sending CONNECT
Client a1 received CONNACK (0)
Client a1 sending SUBSCRIBE (Mid: 1, Topic: $share/workers/lab/jobs, QoS: 1, Options: 0x00)
Client a1 received SUBACK
Subscribed (mid: 1): 1
Client a1 received PUBLISH (d0, q1, r0, m1, 'lab/jobs', ... (6 bytes))
Client a1 sending PUBACK (m1, rc0)
lab/jobs job-01
Client a1 received PUBLISH (d0, q1, r0, m2, 'lab/jobs', ... (6 bytes))
Client a1 sending PUBACK (m2, rc0)
lab/jobs job-02
Client a1 received PUBLISH (d0, q1, r0, m3, 'lab/jobs', ... (6 bytes))
Client a1 sending PUBACK (m3, rc0)
lab/jobs job-04
Client a1 received PUBLISH (d0, q1, r0, m4, 'lab/jobs', ... (6 bytes))
Client a1 sending PUBACK (m4, rc0)
lab/jobs job-06
```

## mqtt-lab-check-a2

```text
Client a2 sending CONNECT
Client a2 received CONNACK (0)
Client a2 sending SUBSCRIBE (Mid: 1, Topic: $share/workers/lab/jobs, QoS: 1, Options: 0x00)
Client a2 received SUBACK
Subscribed (mid: 1): 1
Client a2 received PUBLISH (d0, q1, r0, m1, 'lab/jobs', ... (6 bytes))
Client a2 sending PUBACK (m1, rc0)
lab/jobs job-03
Client a2 received PUBLISH (d0, q1, r0, m2, 'lab/jobs', ... (6 bytes))
Client a2 sending PUBACK (m2, rc0)
lab/jobs job-05
```

## mqtt-lab-check-b1

```text
Client b1 sending CONNECT
Client b1 received CONNACK (0)
Client b1 sending SUBSCRIBE (Mid: 1, Topic: $share/workers/lab/jobs, QoS: 1, Options: 0x00)
Client b1 received SUBACK
Subscribed (mid: 1): 1
Client b1 sending PINGREQ
Client b1 received PINGRESP
```

## B direct delivery

```text
Client b1 sending CONNECT
Client b1 received CONNACK (0)
Client b1 sending SUBSCRIBE (Mid: 1, Topic: $share/workers/lab/jobs, QoS: 1, Options: 0x00)
Client b1 received SUBACK
Subscribed (mid: 1): 1
Client b1 sending PINGREQ
Client b1 received PINGRESP
Client b1 received PUBLISH (d0, q1, r0, m1, 'lab/jobs', ... (6 bytes))
Client b1 sending PUBACK (m1, rc0)
lab/jobs b-only
```

## Shared subscription message counts

```text
{'A1': 4, 'A2': 2, 'B1 (A publish)': 0}
```

## Before stop A clients

```text
Client(failover-worker, username=undefined, peername=<lab-address>, clean_start=true, keepalive=5, session_expiry_interval=0, subscriptions=1, inflight=0, awaiting_rel=0, delivered_msgs=0, enqueued_msgs=0, dropped_msgs=0, connected=true, created_at=1792631674859, connected_at=1792631674859)
```

## After stop B clients

```text
Client(failover-worker, username=undefined, peername=<lab-address>, clean_start=true, keepalive=5, session_expiry_interval=0, subscriptions=1, inflight=0, awaiting_rel=0, delivered_msgs=0, enqueued_msgs=0, dropped_msgs=0, connected=true, created_at=1792631685499, connected_at=1792631685499)
```

## Failover subscriber log

```text
Client failover-worker sending CONNECT
Client failover-worker received CONNACK (0)
Client failover-worker sending SUBSCRIBE (Mid: 1, Topic: $share/workers/lab/jobs, QoS: 1, Options: 0x00)
Client failover-worker received SUBACK
Subscribed (mid: 1): 1
Client failover-worker received PUBLISH (d0, q1, r0, m1, 'lab/jobs', ... (13 bytes))
Client failover-worker sending PUBACK (m1, rc0)
lab/jobs before-A-stop
Client failover-worker sending CONNECT
Client failover-worker sending CONNECT
Client failover-worker received CONNACK (0)
Client failover-worker sending SUBSCRIBE (Mid: 2, Topic: $share/workers/lab/jobs, QoS: 1, Options: 0x00)
Client failover-worker received SUBACK
Subscribed (mid: 2): 1
Client failover-worker received PUBLISH (d0, q1, r0, m1, 'lab/jobs', ... (12 bytes))
Client failover-worker sending PUBACK (m1, rc0)
lab/jobs after-A-stop
```

## Recovery A observer

```text
Client recovery-a sending CONNECT
Client recovery-a received CONNACK (0)
Client recovery-a sending SUBSCRIBE (Mid: 1, Topic: $share/workers/lab/jobs, QoS: 1, Options: 0x00)
Client recovery-a received SUBACK
Subscribed (mid: 1): 1
Client recovery-a received PUBLISH (d0, q1, r0, m1, 'lab/jobs', ... (16 bytes))
Client recovery-a sending PUBACK (m1, rc0)
lab/jobs after-A-recovery
```

## Recovery B subscriber (no recovery payload)

```text
Client failover-worker sending CONNECT
Client failover-worker received CONNACK (0)
Client failover-worker sending SUBSCRIBE (Mid: 1, Topic: $share/workers/lab/jobs, QoS: 1, Options: 0x00)
Client failover-worker received SUBACK
Subscribed (mid: 1): 1
Client failover-worker received PUBLISH (d0, q1, r0, m1, 'lab/jobs', ... (13 bytes))
Client failover-worker sending PUBACK (m1, rc0)
lab/jobs before-A-stop
Client failover-worker sending CONNECT
Client failover-worker sending CONNECT
Client failover-worker received CONNACK (0)
Client failover-worker sending SUBSCRIBE (Mid: 2, Topic: $share/workers/lab/jobs, QoS: 1, Options: 0x00)
Client failover-worker received SUBACK
Subscribed (mid: 2): 1
Client failover-worker received PUBLISH (d0, q1, r0, m1, 'lab/jobs', ... (12 bytes))
Client failover-worker sending PUBACK (m1, rc0)
lab/jobs after-A-stop
Client failover-worker sending PINGREQ
Client failover-worker received PINGRESP
Client failover-worker sending PINGREQ
Client failover-worker received PINGRESP
Client failover-worker sending PINGREQ
Client failover-worker received PINGRESP
Client failover-worker sending PINGREQ
Client failover-worker received PINGRESP
```

## Recovered A clients

```text
Client(recovery-a, username=undefined, peername=<lab-address>, clean_start=true, keepalive=5, session_expiry_interval=0, subscriptions=1, inflight=0, awaiting_rel=0, delivered_msgs=0, enqueued_msgs=0, dropped_msgs=0, connected=true, created_at=1792631705089, connected_at=1792631705090)
```

## Recovered B clients

```text
Client(failover-worker, username=undefined, peername=<lab-address>, clean_start=true, keepalive=5, session_expiry_interval=0, subscriptions=1, inflight=0, awaiting_rel=0, delivered_msgs=1, enqueued_msgs=0, dropped_msgs=0, connected=true, created_at=1792631685499, connected_at=1792631685499)
```
