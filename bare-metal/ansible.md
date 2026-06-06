# Ansible

## Objective

Configuration management for all hosts in the cluster.

Specific tasks:

-   ... TODO ...
-   Rewrite `preseed/late_command` scripts as Ansible playbooks.
-   Install Docker on all hosts.
-   Install Kubernetes packages on all hosts.
-   Install Kubernetes control plane on one host.
-   Configure a CNI (Flannel, Cilium, ...).

## Install

-----

```bash
wget -O- "https://keyserver.ubuntu.com/pks/lookup?fingerprint=on&op=get&search=0x6125E2A8C77F2818FB7BD15B93C4A3FD7BB9C367" | sudo gpg --dearmor -o /usr/share/keyrings/ansible-archive-keyring.gpg

UBUNTU_CODENAME=noble; echo "deb [signed-by=/usr/share/keyrings/ansible-archive-keyring.gpg] http://ppa.launchpad.net/ansible/ansible/ubuntu $UBUNTU_CODENAME main" | sudo tee /etc/apt/sources.list.d/ansible.list

# Note the older version Debian provides.
sudo apt show ansible

sudo apt update

# Make sure the version is now more recent than that.
sudo apt show ansible

sudo apt install ansible
```

Docs:

-   https://docs.ansible.com/projects/ansible/latest/installation_guide/installation_distros.html#installing-ansible-on-debian


## Configuration

Docs: https://docs.ansible.com/projects/ansible/13/

### Inventory

A host belongs to one or more groups. Here we have groups "nodes",
"controlplane", and "workers" in `./inventory.yml`:

```yaml
---
all:
  children:
    nodes:
      hosts:
        seesaw:
        slide:
        swings:
        zipline:
      vars:
        proxy_env:
          HTTP_PROXY: "http://192.168.125.94:3128"
          HTTPS_PROXY: "http://192.168.125.94:3128"
          NO_PROXY: "localhost,127.0.0.1"
          http_proxy: "http://192.168.125.94:3128"
          https_proxy: "http://192.168.125.94:3128"
          no_proxy: "localhost,127.0.0.1"
    controlplane:
      hosts:
        seesaw:
    workers:
      hosts:
        slide:
        swings:
        zipline:
```

### Playbooks

A list of tasks to be executed in order. An example:

```yaml
---
- name: Enable console display blanking and poweroff
  hosts: all

  tasks:
    - name: Install console-poweroff systemd unit file
      copy:
        src: console-poweroff.service
        dest: /etc/systemd/system/console-poweroff.service
        owner: root
        group: root
        mode: 0644
      become: yes
      register: service_file

    - name: Enable/restart console-poweroff service
      systemd_service:
        name: console-poweroff
        enabled: true
        daemon-reload: true
        state: "{{ 'restarted' if service_file.changed else omit }}"
      become: yes
```

A playbook and its templates and files can be grouped together in a "role".
These roles can be shared on [galaxy.ansible.com](https://galaxy.ansible.com/).
You can download them into `~/.ansible/roles` like so:

```bash
$ ansible-galaxy role install geerlingguy.docker
```

To use the role:

```yaml
- name: Install Docker
  hosts: nodes
  become: true
  vars:
    ansible_become_method: sudo
  environment: "{{ proxy_env }}"

  roles:
    - role: geerlingguy.docker
      vars:
        docker_users:
          - sysadm
```

## Problems

### Insecure Signatures

Ansible's repository signatures are considered insecure because they use SHA1.

```bash
$ sudo apt update
[...snip...]
Warning: OpenPGP signature verification failed: ... because: SHA1 is not considered secure since ...
Error: The repository ... is not signed.
```

Luckily there is a way to temporarily allow SHA1 again:

```bash
sudo mkdir -p /etc/crypto-policies/back-ends

sudo cp /usr/share/apt/default-sequoia.config /etc/crypto-policies/back-ends/apt-sequoia.config

# Extend the date for `sha1` or set it to "always" (with quotes)
# I set it to 3 months in the future, after which I'll revisit.
sudo vim /etc/crypto-policies/back-ends/apt-sequoia.config
```

Doing this enables a vulnerability that has been there for a long time. We've
been given enough time to phase out SHA1.

There are other solutions that make things much worse. Some people have
suggested putting `allow-insecure=yes` or `trusted=yes` beside or replacing
`signed-by` in `/etc/apt/sources.list.d/ansible.list`. This effectively
disables signature verification altogether.

See also:

-   https://github.com/ansible-community/ppa/issues/114
-   https://wiki.debian.org/Teams/Apt/Sha1Removal
-   https://docs.rs/sequoia-policy-config/latest/sequoia_policy_config/#hash-functions
