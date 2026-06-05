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

Docs:

-   https://docs.ansible.com/projects/ansible/13/

### Inventory

```
TODO: Paste hosts file
```


## Problems

### Insecure Signatures

Ansible's repository signatures are considered insecure because they use SHA1.

```
$ sudo apt update
[...snip...]
Warning: OpenPGP signature verification failed: ... because: SHA1 is not considered secure since ...
Error: The repository ... is not signed.
```

Luckily there is a way to temporarily allow SHA1 again:

```
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

Links:

-   https://github.com/ansible-community/ppa/issues/114
-   https://wiki.debian.org/Teams/Apt/Sha1Removal
-   https://docs.rs/sequoia-policy-config/latest/sequoia_policy_config/#hash-functions
