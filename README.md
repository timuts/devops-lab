# DevOps Lab

Notes from studying Kubernetes & other DevOps/SRE infrastructure and tools.

## Objective

To document all the steps required to build a complete stack of open source
infrastructure and tools in a home lab environment. Everything required to make
an application reliable, scalable, and maintainable while enabling rapid
development and minimizing toil.

Along the way exploring multiple competing options (where available) and
documenting each one separately.

Included should be:

-   Automated testing, builds, and releases
-   Automated backups
-   Automated OS installs
-   Automatic scaling
-   Central logging
-   Configuration management
-   DoS protection
-   Load balancing
-   Load testing
-   Monitoring & alerting
-   Safe rollouts & rollbacks
-   Security
    -   Minimal permissions
    -   Web Application Firewall (WAF)
    -   Encrypted & authenticated inter-node traffic (e.g: mTLS)
    -   TODO: More.

## Table of Contents

*   Bare Metal
    *   [My hardware](bare-metal/my-hardware.md)
    *   Host OS installation
        *   [Debian preseed](bare-metal/debian-preseed.md)
    *   Kubernetes
        *   Install
        *   CNI
            *   Flannel
            *   Cilium
