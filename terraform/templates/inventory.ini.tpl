[minecraft_servers]
minecraft_server ansible_host=${vm_public_ip} ansible_user=${admin_username} ansible_ssh_private_key_file=${ssh_key_path} ansible_ssh_common_args='-o StrictHostKeyChecking=no'

[minecraft_servers:vars]
ansible_python_interpreter=/usr/bin/python3
