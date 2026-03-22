# My Hardware

A mishmash of old machines (naming scheme: playground):

*   `seesaw` - Custom built tower [`192.168.125.51`]
    *   CPU: Intel Core i5-650 @ 3.2 GHz, 2 cores, 4 hyperthreads
    *   RAM: 16G @ 1333 MHz
    *   Storage: 256G SATA SSD
*   `slide` - Microsoft Surface Book laptop [`192.168.125.52`]
    *   CPU: Intel Core i5-6300U @ 2.4 GHz, 2 cores, 4 hyperthreads
    *   RAM: 8G @ 1866 MHz
    *   Storage: 128G NVMe SSD
*   `swings` - HP Laptop 15-dw3363st [`192.168.125.53`]
    *   CPU: 11th Gen Intel Core i3-1125G4 @ 2.00GHz, 4 cores, 8 hyperthreads
    *   RAM: 8G @ 3200 MHz
    *   Storage: 256G NVMe SSD
*   `zipline` - HP Laptop 14-dq0706tg [`192.168.125.54`]
    *   CPU: Intel Celeron N4120 @ 1.1 GHz, 4 cores, 4 hyperthreads
    *   RAM: 4G @ 2400 MHz
    *   Storage: 64G MMC SSD

Services that aren't related to running a Kubernetes node (such as those used
for PXE booting) will run on `seesaw`. It will also run the Kubernetes control
plane services. The rest will be generic Kubernetes nodes.
