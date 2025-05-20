
# Install Ansible on Ubuntu

```sh
sudo apt update
sudo apt install software-properties-common
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt install ansible
```

[Ansible Community Documentation](https://docs.ansible.com/ansible/latest/installation_guide/installation_distros.html#installing-ansible-on-ubuntu)

# 測試ansible

編輯ansible hosts
```sh
sudo vim /etc/ansilble/hosts
```
新增主機
```sh
[local] #自訂名稱
server1 ansible_ssh_host=127.0.0.1  ansible_ssh_port=22
```
建立測試yml
```sh
vim hello.yml
```
測試yml內容
```sh
---
#測試yml
- name: say 'hello world'
  hosts: local
  tasks:

    - name: echo 'hello world'
      command: echo 'hello world'
      register: result

    - name: print stdout
      debug:
        msg: "{{ result.stdout }}"
```
測試ansible
```sh
ansible-playbook hello.yml
```

# Run Ansible-playbook
1. 建立專用用戶
```sh
sudo adduser --disabled-password --gecos "" ansible
sudo su - ansible
```
2. 配置權限
```sh
ansible ALL=(ALL) NOPASSWD: /usr/bin/ansible-playbook /opt/ansible/*
```
3. 金鑰配置
```sh
sudo -u ansible ssh-keygen -t ed25519 -f /home/ansible/.ssh/ansible_deploy_key
sudo -u ansible ssh-copy-id -i /home/ansible/.ssh/ansible_deploy_key.pub ansible@<remote_IP>
```
- 由於`ansible`帳號並無密碼，所以`ssh-copy-id`會出現無法輸入密碼狀況解法如下
```sh
#配置密碼
sudo passwd ansible
sudo -u ansible ssh-copy-id -i /home/ansible/.ssh/ansible_deploy_key.pub ansible@<remote_IP>
#移除密碼
sudo passwd -l ansible
```