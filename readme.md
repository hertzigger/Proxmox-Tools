#Proxmox Tools

##Description

The main reason I developed this is because I wanted a way to automatically provision a new virtual machine with Ansible.

The main issue I was facing when using templates with Proxmox is they retain their ip address and there isn't a way (as far as I am aware) to change the ip address before creating a new vm from a template.

I did figure out that I was able to clone a template then mount the kvm image and change the network configuration on the host machine.

From this proxmox tools was born, not really a comprehensive tool set at the moment, but a big first step.

The script uses both the Proxmox API and ssh to achieve a quick and automated provisioning and you can use it to not only change the network configuration before lauching a new vm but also change any files on a system before starting for the first time.

For some reason when I started this project I though it was a good time to start learning ruby.....

So if you are a ruby expert you will probably find some very noob errors and unfortunately I haven't got time to refactor into something that looks nice. So pull requests to expand the functionality or coding standards are welcome.

##Installation

###Centos 7

Clone the repository to any server that is able to ssh to the host, the server could even be a virtual machine of the host.

    #yum update
    #yum install epel-release ruby 
    #gem install httparty net-ping net-ssh

###Optional Install

Install globally

    #cp lib/proxmox_tools.rb /usr/local/bin/clone

##Configuration

    #cp config.example.json config.json
    
###mount

To be able to change the ip address within the file system before starting the new virtual machine. The script needs to mount the filesystem on the hosting machine. So this section is the ssh details for the host machine. There will be the option to run it locally in the future by changing local to true. But this hasn't been implemented as I don't need it. 

Password login isn't supported at the moment so you need to make sure your user can ssh to the host with keys and it can mount, unmount and access the var/lib/vz/ directory on the host machine. 

    "mount": {
        "local": false,
        "host": "172.16.0.1",
        "username": "username"
    },

###proxmox api

These are the credentials and location of the Proxmox api the user will need permissions to clone existing templates/vms and start vms.


    "proxmox_api": {
        "address": "172.16.0.1",
        "port": "8006",
        "version": "api2",
        "type": "json",
        "username": "username",
        "password": "password"
    },
    
###instance

These are the details for the new vm

    "instance": {
        "name": "test",                             //vm name
        "description": "this is a test instance",   //New VM description.
        "storage": "",                              //Target storage for new VM.
        "vmid": "125",                              //Virtual machine id to clone from
        "node": "h2",                               //Proxmox deployment node
        "format": "qcow2",                          //Storage format
        "full": true,                               //Is this a full clone
        "ips": [                                    //New ip address. These are checked first to make sure we dont get conflicts
          "172.16.1.21",
          "192.168.1.21"
        ],
        
The next section is for file replacements, ie changing the ip address etc. This example shows for a centos 7 virtual machine, but could be changed to work for ubuntu etc

    "replacements": {
      "/etc/sysconfig/network-scripts/ifcfg-ens18": {
        "TYPE": "Ethernet",
        "BOOTPROTO": "static",
        "DEFROUTE": "yes",
        "IPV4_FAILURE_FATAL": "no",
        "IPV6INIT": "yes",
        "IPV6_AUTOCONF": "yes",
        "IPV6_DEFROUTE": "yes",
        "IPV6_FAILURE_FATAL": "no",
        "NAME": "ens18",
        "UUID": "",
        "DEVICE": "ens18",
        "ONBOOT": "yes",
        "IPADDR": "172.16.1.21",
        "PREFIX": "12",
        "BROADCAST": "172.31.255.255",
        "IPV6_PEERDNS": "yes",
        "IPV6_PEERROUTES": "yes",
        "IPV6_PRIVACY": "no",
        "IPADDR0": "91.0.0.1", //External IP address
        "PREFIX0": "28",
        "NETMASK0": "255.255.255.240",
        "GATEWAY0": "91.0.0.1"
      },
      "/etc/sysconfig/network-scripts/ifcfg-ens19": {
        "TYPE": "Ethernet",
        "BOOTPROTO": "static",
        "NAME": "ens19",
        "UUID": "",
        "DEVICE": "ens19",
        "ONBOOT": "yes",
        "IPADDR": "192.168.1.20",
        "NETMASK": "255.255.0.0",
        "BROADCAST": "192.168.255.255",
        "GATEWAY": "192.168.0.254"
      }
    }
    
##Config

By including this section additional configuration options can be set on the cloned vm. If this section isn't present no configuration changes will take place.
For further details on option please see https://pve.proxmox.com/pve-docs/api-viewer/index.html nodes >> {node} >> qemu >> {vmid} >> config >> POST

    "config" : {
      "autostart" : "yes",
      "cores" : "2",
      "balloon" : "256",
      "memory" : "512",
      "onboot" : "yes",
      "sockets" : "1"
    },    
##Running

    clone --help
    Usage: clone node vmid [options]
        -m, --vmid VMID                  Virtual machine id to clone from
        -e, --node NODE                  Proxmox deployment node
        -n, --name NAME                  Name for new VM.
        -d, --description DESCRIPTION    New VM description.
        -s, --storage STORAGE            Target storage for new VM.
        -u, --username USERNAME          Username for proxmox API
        -p, --password PASSWORD          Password for proxmox API
        -c, --config CONFIG              Location of config (default config.json)
            --address ADDRESS            Promox api address (default 127.0.0.1)
            --port POST                  Proxmox api port (default 8006)
            --version VERSION            Proxmox api version (default api2)
            --type TYPE                  Proxmox api type (default json)
        -h, --help                       Prints this help
        
Most of the configuration can be overwritten when running.

The default config name is config.json but you can pass in a configuration file with the -c option.

    clone -c config.json -v
    
    create full clone of drive ide0 (local:125/vm-125-disk-1.qcow2)
    Formatting '/var/lib/vz/images/137/vm-137-disk-1.qcow2', fmt=qcow2 size=10737418240 encryption=off cluster_size=65536 preallocation=metadata lazy_refcounts=off refcount_bits=16
    drive mirror is starting (scanning bitmap) : this step can take some minutes/hours, depend of disk size and storage speed
    transferred: 146800640 bytes remaining: 10590617600 bytes total: 10737418240 bytes progression: 1.37 % busy: true ready: false
    transferred: 618659840 bytes remaining: 10118758400 bytes total: 10737418240 bytes progression: 5.76 % busy: true ready: false
    transferred: 1142947840 bytes remaining: 9594470400 bytes total: 10737418240 bytes progression: 10.64 % busy: true ready: false
    transferred: 1331691520 bytes remaining: 9405726720 bytes total: 10737418240 bytes progression: 12.40 % busy: true ready: false
    transferred: 1520435200 bytes remaining: 9216983040 bytes total: 10737418240 bytes progression: 14.16 % busy: true ready: false
    transferred: 1698693120 bytes remaining: 9038725120 bytes total: 10737418240 bytes progression: 15.82 % busy: true ready: false
    transferred: 1887436800 bytes remaining: 8849981440 bytes total: 10737418240 bytes progression: 17.58 % busy: true ready: false
    transferred: 2065694720 bytes remaining: 8671723520 bytes total: 10737418240 bytes progression: 19.24 % busy: true ready: false
    transferred: 2254438400 bytes remaining: 8482979840 bytes total: 10737418240 bytes progression: 21.00 % busy: true ready: false
    transferred: 2443182080 bytes remaining: 8294236160 bytes total: 10737418240 bytes progression: 22.75 % busy: true ready: false
    transferred: 2631925760 bytes remaining: 8105492480 bytes total: 10737418240 bytes progression: 24.51 % busy: true ready: false
    transferred: 2820669440 bytes remaining: 7916748800 bytes total: 10737418240 bytes progression: 26.27 % busy: true ready: false
    transferred: 3009413120 bytes remaining: 7728005120 bytes total: 10737418240 bytes progression: 28.03 % busy: true ready: false
    transferred: 3187671040 bytes remaining: 7549747200 bytes total: 10737418240 bytes progression: 29.69 % busy: true ready: false
    transferred: 3386900480 bytes remaining: 7350517760 bytes total: 10737418240 bytes progression: 31.54 % busy: true ready: false
    transferred: 3565158400 bytes remaining: 7172259840 bytes total: 10737418240 bytes progression: 33.20 % busy: true ready: false
    transferred: 3743416320 bytes remaining: 6994001920 bytes total: 10737418240 bytes progression: 34.86 % busy: true ready: false
    transferred: 3932160000 bytes remaining: 6805258240 bytes total: 10737418240 bytes progression: 36.62 % busy: true ready: false
    transferred: 4099932160 bytes remaining: 6637486080 bytes total: 10737418240 bytes progression: 38.18 % busy: true ready: false
    transferred: 4288675840 bytes remaining: 6448742400 bytes total: 10737418240 bytes progression: 39.94 % busy: true ready: false
    transferred: 4466933760 bytes remaining: 6270484480 bytes total: 10737418240 bytes progression: 41.60 % busy: true ready: false
    transferred: 4634705920 bytes remaining: 6102712320 bytes total: 10737418240 bytes progression: 43.16 % busy: true ready: false
    transferred: 4812963840 bytes remaining: 5924454400 bytes total: 10737418240 bytes progression: 44.82 % busy: true ready: false
    transferred: 5001707520 bytes remaining: 5735710720 bytes total: 10737418240 bytes progression: 46.58 % busy: true ready: false
    transferred: 5169479680 bytes remaining: 5567938560 bytes total: 10737418240 bytes progression: 48.14 % busy: true ready: false
    transferred: 5337251840 bytes remaining: 5400166400 bytes total: 10737418240 bytes progression: 49.71 % busy: true ready: false
    transferred: 5525995520 bytes remaining: 5211422720 bytes total: 10737418240 bytes progression: 51.46 % busy: true ready: false
    transferred: 5693767680 bytes remaining: 5043650560 bytes total: 10737418240 bytes progression: 53.03 % busy: true ready: false
    transferred: 5872025600 bytes remaining: 4865392640 bytes total: 10737418240 bytes progression: 54.69 % busy: true ready: false
    transferred: 6417285120 bytes remaining: 4320133120 bytes total: 10737418240 bytes progression: 59.77 % busy: true ready: false
    transferred: 6585057280 bytes remaining: 4152360960 bytes total: 10737418240 bytes progression: 61.33 % busy: true ready: false
    transferred: 7455375360 bytes remaining: 3282042880 bytes total: 10737418240 bytes progression: 69.43 % busy: true ready: false
    transferred: 8053063680 bytes remaining: 2684354560 bytes total: 10737418240 bytes progression: 75.00 % busy: true ready: false
    transferred: 9122611200 bytes remaining: 1614807040 bytes total: 10737418240 bytes progression: 84.96 % busy: true ready: false
    transferred: 9688842240 bytes remaining: 1048576000 bytes total: 10737418240 bytes progression: 90.23 % busy: true ready: false
    transferred: 10643046400 bytes remaining: 94371840 bytes total: 10737418240 bytes progression: 99.12 % busy: true ready: false
    transferred: 10737418240 bytes remaining: 0 bytes total: 10737418240 bytes progression: 100.00 % busy: false ready: true
    TASK OK
    New VM successfully created, image stored at /var/lib/vz/images/137/vm-137-disk-1.qcow2
    attempting connection to host
    connected to host
    /var/lib/vz/images/137
    /var/lib/vz/images/137/vm-137-disk-1.qcow2
    replacing TYPE=Ethernet in file /var/lib/vz/images/137/disk/etc/sysconfig/network-scripts/ifcfg-ens18
    replacing BOOTPROTO=static in file /var/lib/vz/images/137/disk/etc/sysconfig/network-scripts/ifcfg-ens18
    replacing DEFROUTE=yes in file /var/lib/vz/images/137/disk/etc/sysconfig/network-scripts/ifcfg-ens18
    replacing IPV4_FAILURE_FATAL=no in file /var/lib/vz/images/137/disk/etc/sysconfig/network-scripts/ifcfg-ens18
    replacing IPV6INIT=yes in file /var/lib/vz/images/137/disk/etc/sysconfig/network-scripts/ifcfg-ens18
    replacing IPV6_AUTOCONF=yes in file /var/lib/vz/images/137/disk/etc/sysconfig/network-scripts/ifcfg-ens18
    replacing IPV6_DEFROUTE=yes in file /var/lib/vz/images/137/disk/etc/sysconfig/network-scripts/ifcfg-ens18
    replacing IPV6_FAILURE_FATAL=no in file /var/lib/vz/images/137/disk/etc/sysconfig/network-scripts/ifcfg-ens18
    replacing NAME=ens18 in file /var/lib/vz/images/137/disk/etc/sysconfig/network-scripts/ifcfg-ens18
    replacing UUID= in file /var/lib/vz/images/137/disk/etc/sysconfig/network-scripts/ifcfg-ens18
    replacing DEVICE=ens18 in file /var/lib/vz/images/137/disk/etc/sysconfig/network-scripts/ifcfg-ens18
    replacing ONBOOT=yes in file /var/lib/vz/images/137/disk/etc/sysconfig/network-scripts/ifcfg-ens18
    replacing IPADDR=172.16.1.12 in file /var/lib/vz/images/137/disk/etc/sysconfig/network-scripts/ifcfg-ens18
    replacing PREFIX=12 in file /var/lib/vz/images/137/disk/etc/sysconfig/network-scripts/ifcfg-ens18
    replacing BROADCAST=172.31.255.255 in file /var/lib/vz/images/137/disk/etc/sysconfig/network-scripts/ifcfg-ens18
    replacing IPV6_PEERDNS=yes in file /var/lib/vz/images/137/disk/etc/sysconfig/network-scripts/ifcfg-ens18
    replacing IPV6_PEERROUTES=yes in file /var/lib/vz/images/137/disk/etc/sysconfig/network-scripts/ifcfg-ens18
    replacing IPV6_PRIVACY=no in file /var/lib/vz/images/137/disk/etc/sysconfig/network-scripts/ifcfg-ens18
    replacing TYPE=Ethernet in file /var/lib/vz/images/137/disk/etc/sysconfig/network-scripts/ifcfg-ens19
    replacing BOOTPROTO=static in file /var/lib/vz/images/137/disk/etc/sysconfig/network-scripts/ifcfg-ens19
    replacing NAME=ens19 in file /var/lib/vz/images/137/disk/etc/sysconfig/network-scripts/ifcfg-ens19
    replacing UUID= in file /var/lib/vz/images/137/disk/etc/sysconfig/network-scripts/ifcfg-ens19
    replacing DEVICE=ens19 in file /var/lib/vz/images/137/disk/etc/sysconfig/network-scripts/ifcfg-ens19
    replacing ONBOOT=yes in file /var/lib/vz/images/137/disk/etc/sysconfig/network-scripts/ifcfg-ens19
    replacing IPADDR=192.168.1.12 in file /var/lib/vz/images/137/disk/etc/sysconfig/network-scripts/ifcfg-ens19
    replacing NETMASK=255.255.0.0 in file /var/lib/vz/images/137/disk/etc/sysconfig/network-scripts/ifcfg-ens19
    replacing BROADCAST=192.168.255.255 in file /var/lib/vz/images/137/disk/etc/sysconfig/network-scripts/ifcfg-ens19
    replacing GATEWAY=192.168.0.254 in file /var/lib/vz/images/137/disk/etc/sysconfig/network-scripts/ifcfg-ens19
    disk unmounted
    no content
    TASK OK
    New VM successfully started.
    Not up yet, retrying
    Not up yet, retrying
    Not up yet, retrying
    Not up yet, retrying
    Host is responding to pings. Instance created successfully.

##Notices

Please use this at your own risk, I'm not responsible for any damages that may arise from using this. You should read the code first and understand it.