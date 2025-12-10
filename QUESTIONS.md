# Questions About Your Setup

To provide better recommendations for your Arch Linux homeserver, please answer these questions:

## Storage Configuration

1. **What storage system are you using?**

   - [x] Longhorn (installed and configured)
   - [ ] Rancher local-path-provisioner
   - [ ] Kubernetes hostPath volumes
   - [ ] Other: Longhorn for this, for others local-path
         [onion@archlinux ~]$ kubectl get storageclass
         NAME PROVISIONER RECLAIMPOLICY VOLUMEBINDINGMODE ALLOWVOLUMEEXPANSION AGE
         local-path (default) rancher.io/local-path Delete WaitForFirstConsumer false 2d19h
         longhorn driver.longhorn.io Delete Immediate true 6d10h
         longhorn-encrypted driver.longhorn.io Delete Immediate true 43h
         longhorn-static driver.longhorn.io Delete Immediate true 34h

2. **Disk setup on your Arch Linux server:**
   - Single disk or multiple disks?
   - Disk size available for Prometheus/Grafana?
   - Any RAID configuration?
     [onion@archlinux ~]$ lsblk -o NAME,SIZE,TYPE,MOUNTPOINT
     NAME SIZE TYPE MOUNTPOINT
     sda 238.5G disk
     ├─sda1 1G part /boot
     └─sda2 237.5G part /home
     sr0 1024M rom

## Cluster Configuration

3. **Kubeadm cluster details:**

   - Single-node cluster or multi-node?
   - How many nodes total?
   - Are they all Arch Linux?

4. **Do you have these installed already?**
   - [ ] NGINX Ingress Controller
   - [ ] Longhorn
   - [ ] MetalLB or other LoadBalancer
   - [ ] Cert-manager
         -> see below

## Monitoring Requirements

5. **What do you want to monitor?**

   - [ ] Just Kubernetes cluster health
   - [ ] Specific applications (which ones?)
   - [ ] Storage (Longhorn) performance
   - [ ] Network metrics
   - [x] Other: all of the above

6. **Alerting preferences:**

   - [ ] Alerts in Prometheus UI only (current setup)
   - [ ] Email notifications
   - [ ] Slack/Discord notifications
   - [x] Other: both UI and Discord
   - Not important for now

7. **How long do you want to keep metrics history?**
   - [ ] 7 days
   - [x] 30 days (current)
   - [ ] 90 days
   - [ ] 1 year
   - [ ] Other: **\*\***\_\_\_**\*\***

## Network Configuration

8. **Your network setup:**
   - Is 192.168.2.207 the correct IP for your homeserver? yes
   - Do you have a domain name or using nip.io is fine? nip.io
   - Internal network only or need external access? internal network for now, in my home, so no vpn

## Security

9. **Security requirements:**
   - [ ] Basic security (change default passwords)
   - [ ] TLS/HTTPS required
   - [ ] Network policies to isolate monitoring
   - [ ] Just homelab, minimal security is fine
         as close to production, but without becoming too complex and annoying to setup

## Performance

10. **Resource constraints:** - Total RAM available on homeserver? - Total CPU cores? - Any performance concerns or limitations?
    [onion@archlinux ~]$ free -h
    total used free shared buff/cache available
    Mem: 7.6Gi 2.3Gi 1.4Gi 325Mi 4.5Gi 5.3Gi
    Swap: 0B 0B 0B
    [onion@archlinux ~]$ lscpu
    Architecture: x86*64
    CPU op-mode(s): 32-bit, 64-bit
    Address sizes: 39 bits physical, 48 bits virtual
    Byte Order: Little Endian
    CPU(s): 4
    On-line CPU(s) list: 0-3
    Vendor ID: GenuineIntel
    Model name: Intel(R) Core(TM) i7-7500U CPU @ 2.70GHz
    CPU family: 6
    Model: 142
    Thread(s) per core: 2
    Core(s) per socket: 2
    Socket(s): 1
    Stepping: 9
    CPU(s) scaling MHz: 100%
    CPU max MHz: 3500.0000
    CPU min MHz: 400.0000
    BogoMIPS: 5799.77
    Flags: fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mm
    x fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc art arch_perfmon peb
    s bts rep_good nopl xtopology nonstop_tsc cpuid aperfmperf pni pclmulqdq dtes64 monitor ds*
    cpl vmx est tm2 ssse3 sdbg fma cx16 xtpr pdcm pcid sse4_1 sse4_2 x2apic movbe popcnt tsc_de
    adline_timer aes xsave avx f16c rdrand lahf_lm abm 3dnowprefetch cpuid_fault epb pti ssbd i
    brs ibpb stibp tpr_shadow flexpriority ept vpid ept_ad fsgsbase tsc_adjust bmi1 avx2 smep b
    mi2 erms invpcid mpx rdseed adx smap clflushopt intel_pt xsaveopt xsavec xgetbv1 xsaves dth
    erm ida arat pln pts hwp hwp_notify hwp_act_window hwp_epp vnmi md_clear flush_l1d arch_cap
    abilities
    Virtualization features:
    Virtualization: VT-x
    Caches (sum of all):
    L1d: 64 KiB (2 instances)
    L1i: 64 KiB (2 instances)
    L2: 512 KiB (2 instances)
    L3: 4 MiB (1 instance)
    NUMA:
    NUMA node(s): 1
    NUMA node0 CPU(s): 0-3
    Vulnerabilities:
    Gather data sampling: Mitigation; Microcode
    Ghostwrite: Not affected
    Indirect target selection: Not affected
    Itlb multihit: KVM: Mitigation: VMX disabled
    L1tf: Mitigation; PTE Inversion; VMX conditional cache flushes, SMT vulnerable
    Mds: Mitigation; Clear CPU buffers; SMT vulnerable
    Meltdown: Mitigation; PTI
    Mmio stale data: Mitigation; Clear CPU buffers; SMT vulnerable
    Old microcode: Not affected
    Reg file data sampling: Not affected
    Retbleed: Mitigation; IBRS
    Spec rstack overflow: Not affected
    Spec store bypass: Mitigation; Speculative Store Bypass disabled via prctl
    Spectre v1: Mitigation; usercopy/swapgs barriers and \_\_user pointer sanitization
    Spectre v2: Mitigation; IBRS; IBPB conditional; STIBP conditional; RSB filling; PBRSB-eIBRS Not affecte
    d; BHI Not affected
    Srbds: Mitigation; Microcode
    Tsa: Not affected
    Tsx async abort: Not affected
    Vmscape: Mitigation; IBPB before exit to userspace
    [onion@archlinux ~]$ top
    top - 12:20:07 up 22 min, 2 users, load average: 1.10, 1.03, 0.90
    Tasks: 221 total, 1 running, 220 sleep, 0 d-sleep, 0 stopped, 0 zombie
    %Cpu(s): 2.5 us, 15.0 sy, 0.0 ni, 75.0 id, 0.0 wa, 7.5 hi, 0.0 si, 0.0 st
    MiB Mem : 7808.7 total, 1464.3 free, 2371.1 used, 4589.8 buff/cache
    MiB Swap: 0.0 total, 0.0 free, 0.0 used. 5437.7 avail Mem

        PID USER      PR  NI    VIRT    RES    SHR S  %CPU  %MEM     TIME+ COMMAND
         72 root     -51   0       0      0      0 S  56.8   0.0  10:59.54 irq/122-aerdrv
          1 root      20   0   23644  14620  10076 S   0.0   0.2   0:02.35 systemd
          2 root      20   0       0      0      0 S   0.0   0.0   0:00.00 kthreadd
          3 root      20   0       0      0      0 S   0.0   0.0   0:00.00 pool_workqueue_release
          4 root       0 -20       0      0      0 I   0.0   0.0   0:00.00 kworker/R-rcu_gp
          5 root       0 -20       0      0      0 I   0.0   0.0   0:00.00 kworker/R-sync_wq
          6 root       0 -20       0      0      0 I   0.0   0.0   0:00.00 kworker/R-kvfree_rcu_reclaim
          7 root       0 -20       0      0      0 I   0.0   0.0   0:00.00 kworker/R-slub_flushwq
          8 root       0 -20       0      0      0 I   0.0   0.0   0:00.00 kworker/R-netns
         10 root       0 -20       0      0      0 I   0.0   0.0   0:00.00 kworker/0:0H-events_highpri
         11 root      20   0       0      0      0 I   0.0   0.0   0:00.03 kworker/0:1-events
         13 root       0 -20       0      0      0 I   0.0   0.0   0:00.00 kworker/R-mm_percpu_wq
         15 root      20   0       0      0      0 S   0.0   0.0   0:00.00 ksoftirqd/0
         16 root      -2   0       0      0      0 I   0.0   0.0   0:00.53 rcu_preempt
         17 root      -2   0       0      0      0 S   0.0   0.0   0:00.00 rcub/0
         18 root      20   0       0      0      0 S   0.0   0.0   0:00.00 rcu_exp_par_gp_kthread_worker/0
         19 root      20   0       0      0      0 S   0.0   0.0   0:00.00 rcu_exp_gp_kthread_worker
         20 root      rt   0       0      0      0 S   0.0   0.0   0:00.08 migration/0
         21 root     -51   0       0      0      0 S   0.0   0.0   0:00.00 idle_inject/0
         22 root      20   0       0      0      0 S   0.0   0.0   0:00.00 cpuhp/0
         23 root      20   0       0      0      0 S   0.0   0.0   0:00.00 cpuhp/1
         24 root     -51   0       0      0      0 S   0.0   0.0   0:00.00 idle_inject/1
         25 root      rt   0       0      0      0 S   0.0   0.0   0:00.21 migration/1

## Existing Services

11. **What services are you running or planning to run?**

    - [ ] GitLab (I see references in your docs)
    - [ ] Other CI/CD tools
    - [ ] Databases
    - [ ] Web applications
    - [x] Other: all of the above

12. **Current issues or pain points:**
    - Any specific problems with current setup?
    - Features you wish you had?
    - Things that don't work as expected?
    - no issues rn

---

## Optional: Arch Linux Specific

13. **Arch Linux package management for Kubernetes:**

    - Did you install kubeadm from AUR or official repos?
    - Any custom kernel parameters already set?
    - Using systemd for service management?

14. **Update frequency:**
    - How often do you run `pacman -Syu`?
    - Concerned about breaking changes from rolling updates?
    - Need help with update strategy?

---

Please answer whichever questions are relevant to your setup. This will help me provide specific recommendations tailored to your Arch Linux homeserver environment.

-> the main idea was that i just have a central deployment of prometheus and grafana, that i then use to scrape and visualize different data from different servies and applications, like linkding for example
-> another thing is that i want to use gitlab and argoCD, im not sure how to handle secrets tho
-> where applicaple Kustomize, Helm, kubectl, k9s, Flux, OpenLens, Krew, Alertmanager, Loki, Tempo, Jaeger, Kuma, Istio, Trivy, OPA, Kyverno, Vault, SOPS
[onion@archlinux ~]$ kubectl get pods -A
NAMESPACE NAME READY STATUS RESTARTS AGE
cert-manager cert-manager-5ff79b64d4-hrrbz 0/1 Unknown 14 6d11h
cert-manager cert-manager-cainjector-7ff6579955-dl4fz 0/1 Unknown 24 6d11h
cert-manager cert-manager-webhook-6677bc56dd-ng5vs 0/1 Unknown 10 6d11h
default nginx-66686b6766-fc6rr 0/1 Unknown 9 6d11h
default nginx-66686b6766-gqtcb 0/1 Unknown 9 6d11h
default nginx-66686b6766-qlxhb 0/1 Unknown 9 6d11h
default prometheus-operator-544984ffc5-44v5d 0/1 Unknown 3 2d12h
gitlab postgresql-0 0/1 Unknown 0 2d
homepage homepage-68657d7cf9-hqlxj 0/1 Unknown 3 2d14h
ingress-nginx ingress-nginx-controller-645b679d5c-2fk7h 0/1 Unknown 10 6d11h
kube-flannel kube-flannel-ds-6sfn4 0/1 Init:0/2 0 36h
kube-flannel kube-flannel-ds-9fjjj 1/1 Running 2 (17m ago) 40h
kube-system coredns-66bc5c9577-dj52c 0/1 Unknown 10 6d11h
kube-system coredns-66bc5c9577-msvnr 0/1 Unknown 10 6d11h
kube-system etcd-archlinux 1/1 Running 12 (17m ago) 6d11h
kube-system kube-apiserver-archlinux 1/1 Running 21 (17m ago) 6d11h
kube-system kube-controller-manager-archlinux 1/1 Running 28 (17m ago) 6d11h
kube-system kube-proxy-mk6z6 1/1 Running 0 36h
kube-system kube-proxy-q2dzv 1/1 Running 12 (17m ago) 6d11h
kube-system kube-scheduler-archlinux 1/1 Running 36 (17m ago) 6d11h
kube-system metrics-server-6c9cd95547-cpg92 0/1 Unknown 0 44h
linkding linkding-58457c77d6-mj558 0/1 Unknown 0 2d
linkding linkding-58457c77d6-zqfld 0/1 Unknown 0 2d
linkding postgres-0 0/2 Unknown 0 2d
linkding postgres-backup-29416020-9tnht 0/1 Completed 0 4d16h
linkding postgres-backup-29417460-djx9c 0/1 Completed 4 3d9h
linkding postgres-backup-29418900-6kthg 0/1 Completed 0 2d16h
linkding postgres-backup-29420340-r2mjr 0/1 Pending 0 40h
linkding postgres-backup-29421780-ln2q2 0/1 Pending 0 17m
local-path-storage local-path-provisioner-866d54d4c8-9hpq4 0/1 Unknown 3 2d19h
longhorn-system csi-attacher-79bffbd58f-4t5j2 0/1 Unknown 18 6d10h
longhorn-system csi-attacher-79bffbd58f-kpdnv 0/1 Unknown 22 6d10h
longhorn-system csi-attacher-79bffbd58f-pgzwp 0/1 Unknown 12 6d10h
longhorn-system csi-provisioner-6c7d4cd8d6-cprdc 0/1 Unknown 14 6d10h
longhorn-system csi-provisioner-6c7d4cd8d6-h5nsh 0/1 Unknown 16 6d10h
longhorn-system csi-provisioner-6c7d4cd8d6-rc7p8 0/1 Unknown 17 6d10h
longhorn-system csi-resizer-869f89c9c5-8xnw4 0/1 Unknown 14 6d10h
longhorn-system csi-resizer-869f89c9c5-gd9kh 0/1 Unknown 23 6d10h
longhorn-system csi-resizer-869f89c9c5-zz9pw 0/1 Unknown 12 6d10h
longhorn-system csi-snapshotter-74f57f68b5-57qlp 0/1 Unknown 13 6d10h
longhorn-system csi-snapshotter-74f57f68b5-fv6wb 0/1 Unknown 16 6d10h
longhorn-system csi-snapshotter-74f57f68b5-jpf8l 0/1 Unknown 20 6d10h
longhorn-system engine-image-ei-04c05bf8-hdjkh 0/1 ContainerCreating 0 36h
longhorn-system engine-image-ei-04c05bf8-ztxld 0/1 Unknown 10 6d10h
longhorn-system instance-manager-860482538434a9afc94574f28627d9ce 0/1 Unknown 0 2d
longhorn-system longhorn-csi-plugin-cwqbk 0/3 ContainerCreating 0 36h
longhorn-system longhorn-csi-plugin-qnlcj 0/3 Unknown 44 6d10h
longhorn-system longhorn-driver-deployer-6cb6fbb4f-8gccg 0/1 Unknown 9 6d10h
longhorn-system longhorn-manager-5gtzb 0/2 ContainerCreating 0 36h
longhorn-system longhorn-manager-kczw6 0/2 Unknown 6 2d19h
longhorn-system longhorn-ui-547558cb68-ggbv5 0/1 Unknown 11 6d10h
longhorn-system longhorn-ui-547558cb68-ptrd7 0/1 Unknown 13 6d10h
metallb-system controller-5995677bd5-7zp6c 0/1 Unknown 12 6d11h
metallb-system speaker-8t9cm 1/1 Running 39 (17m ago) 6d11h
metallb-system speaker-smvtz 0/1 Running 0 36h
monitoring grafana-6bbfbdf7dc-4kbcr 0/1 Unknown 5 2d19h
monitoring prometheus-5557c9b785-n2rgt 0/1 Unknown 3 2d19h
navidrome cm-acme-http-solver-ncmnn 0/1 Unknown 0 35h
obsidian-livesync couchdb-57d5d59dcd-gldlg 0/1 Unknown 0 37h
obsidian-livesync debug 0/1 Error 0 41h
[onion@archlinux ~]$ kubectl get nodes -A
NAME STATUS ROLES AGE VERSION
archlinux Ready control-plane 6d11h v1.34.2
