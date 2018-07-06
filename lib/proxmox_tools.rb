#!/usr/bin/env ruby

require 'optparse'
require 'httparty'
require 'json'
require 'ostruct'
require 'cgi'
require 'net/ping'
require 'net/ssh'

options = OpenStruct.new

outputlevel = 0;
quietRun = 0;
OptionParser.new do |opt|
  opt.banner = "Usage: #{$PROGRAM_NAME} node vmid [options]"
  opt.on('-m', '--vmid VMID', 'Virtual machine id to clone from.') { |o| options.vmid = o }
  opt.on('-e', '--node NODE', 'Proxmox deployment node.') { |o| options.node = o }
  opt.on('-n', '--name NAME', 'Name for new VM.') { |o| options.name = o }
  opt.on('-d', '--description DESCRIPTION', 'New VM description.') { |o| options.description = o }
  opt.on('-s', '--storage STORAGE', 'Target storage for new VM.') { |o| options.storage = o }
  opt.on('-u', '--username USERNAME', 'Username for proxmox API.') { |o| options.username = o }
  opt.on('-p', '--password PASSWORD', 'Password for proxmox API.') { |o| options.password = o }
  opt.on('-c', '--config CONFIG', 'Location of config (default config.json)') { |o| options.config = o }
  opt.on('-g', '--vgname NAME', 'Name of volume group.') { |o| options.vgname = o }
  opt.on('-v', '--verbose', 'Explains what is being done') { outputlevel = 1 }
  opt.on('-q', '--quiet', 'Silent all output except error, even if verbose') { quietRun = 1 }
  opt.on('--address ADDRESS', 'Proxmox api address (default 127.0.0.1)') { |o| options.address = o }
  opt.on('--port POST', 'Proxmox api port (default 8006)') { |o| options.port = o }
  opt.on('--version VERSION', 'Proxmox api version (default api2)') { |o| options.version = o }
  opt.on('--type TYPE', 'Proxmox api type (default json)') { |o| options.type = o }
  opt.on("-h", "--help", "Prints this help") do
    puts opt
    exit
  end
end.parse!

address = '127.0.0.1'
port = '8006'
version = 'api2'
type = 'json'
username = ''
password = ''

name = 'proxmox-tools'
description = ''
storage = ''
ips = []
vmid = ''
node = ''
format = 'qcow2'
full = true

local = true
sshHost = "127.0.0.1"
sshPassword = "password"
sshUsername = "username"
vgname = ""



configFilename = 'config.json'

if options.config.to_s != ''
  configFilename = options.config.to_s
end
configContents = ''
if File.file?(configFilename)
  configContents = JSON.parse(File.read(File.join(Dir.pwd,configFilename)))
  if configContents.include?("mount")
    if configContents["mount"].include?("local")
      local = configContents["mount"]["local"]
    end
    if configContents["mount"].include?("host")
      sshHost = configContents["mount"]["host"]
    end
    if configContents["mount"].include?("password")
      sshPassword = configContents["mount"]["password"]
    end
    if configContents["mount"].include?("username")
      sshUsername = configContents["mount"]["username"]
    end
  end
  if configContents.include?("proxmox_api")
    if configContents["proxmox_api"].include?("address")
      address = configContents["proxmox_api"]["address"]
    end
    if configContents["proxmox_api"].include?("port")
      port = configContents["proxmox_api"]["port"]
    end
    if configContents["proxmox_api"].include?("version")
      version = configContents["proxmox_api"]["version"]
    end
    if configContents["proxmox_api"].include?("type")
      type = configContents["proxmox_api"]["type"]
    end
    if configContents["proxmox_api"].include?("username")
      username = configContents["proxmox_api"]["username"]
    end
    if configContents["proxmox_api"].include?("password")
      password = configContents["proxmox_api"]["password"]
    end
  end
  if configContents.include?("instance")
    if configContents["instance"].include?("name")
      name = configContents["instance"]["name"]
    end
    if configContents["instance"].include?("description")
      description = configContents["instance"]["description"]
    end
    if configContents["instance"].include?("storage")
      storage = configContents["instance"]["storage"]
    end
    if configContents["instance"].include?("vmid")
      vmid = configContents["instance"]["vmid"]
    end
    if configContents["instance"].include?("node")
      node = configContents["instance"]["node"]
    end
    if configContents["instance"].include?("format")
      format = configContents["instance"]["format"]
    end
    if configContents["instance"].include?("vgname")
      vgname = configContents["instance"]["vgname"]
    end
    if configContents["instance"].include?("full")
      full = configContents["instance"]["full"]
    end
    if configContents["instance"].include?("ips")
      ips = configContents["instance"]["ips"]
      ips.each do |ip|
        check = Net::Ping::External.new(ip)
        if check.ping?
          puts "#{ip} is already in use. please try a different ip"
          exit(0)
        end
      end
    end
  end
else
  puts 'Configuration file not found. exiting'
  exit(1)
end

if options.address.to_s != ''
  address = options.address.to_s
end
if options.port.to_s != ''
  port = options.port.to_s
end
if options.version.to_s != ''
  version = options.version.to_s
end
if options.type.to_s != ''
  type = options.type.to_s
end
if options.username.to_s != ''
  username = options.username.to_s
end
if options.password.to_s != ''
  password = options.password.to_s
end
if options.name.to_s != ''
  name = options.name.to_s
end
if options.description.to_s != ''
  description = options.description.to_s
end
if options.storage.to_s != ''
  storage = options.storage.to_s
end
if options.vmid.to_s != ''
  vmid = options.vmid.to_s
end
if options.node.to_s != ''
  node = options.node.to_s
end
if options.vgname.to_s != ''
  node = options.vgname.to_s
end

proxmoxUrl = "https://#{address}:#{port}/#{version}/#{type}"

if node.to_s == '' || vmid.to_s == '' || username.to_s == '' || password.to_s == '' || vgname.to_s == ''
  puts 'Missing some or all of the required arguments (vmid, node, username, password, vgname)'
  puts 'These can be passed as options or placed in the configuration file.'
  exit(1)
end

#login to the api and get ticket and csrf token
response = HTTParty.post("#{proxmoxUrl}/access/ticket?username=#{username}@pam&password=#{password}", :verify => false )
if response.code == 401
  puts "Authenication Failed, please check username and password. exiting"
  exit(1)
end
if response.code != 200
  puts "Failed login to api. error code " + response.code
end
data = JSON.parse(response.response.body)["data"]
crsf = data['CSRFPreventionToken']
ticket = data['ticket']
response = JSON.parse HTTParty.get("#{proxmoxUrl}/cluster/nextid", :verify => false, :cookies => { PVEAuthCookie: ticket } ).response.body
nextVmid = response['data']
headers = {
    "CSRFPreventionToken" => crsf
}
# Create url for instance clone with optional parameters
url = "#{proxmoxUrl}/nodes/#{node}/qemu/#{vmid}/clone?newid=#{nextVmid}"
if name != ''
  url += "&name=" + CGI.escape(name)
end
if description != ''
  url += "&description=" + CGI.escape(description)
  url += CGI.escape("\nIP Addresses")
  ips.each do |ip|
    url += CGI.escape("\n" + ip)
  end
end
if storage != ''
  url += "&storage=" + CGI.escape(storage)
end
if format != ''
  url += "&format=" + CGI.escape(format)
end
if full
  url += "&full=1"
end
# Call the api to do the clone
response = HTTParty.post(url, :verify => false, :cookies => { PVEAuthCookie: ticket }, :headers => headers )
if response.code != 200
  puts 'Failed to clone VM, Response ' + response.code.to_s
  p response.body
  exit(2)
end
response = JSON.parse response.response.body
taskId = response['data']

# Check the status of instance, print logs and export when complete
loop = true
currentLog = 0
imageLocation = "";
storageDirectory = "";
while loop
  response = JSON.parse HTTParty.get("#{proxmoxUrl}/nodes/#{node}/tasks/#{taskId}/log?start=#{currentLog}", :verify => false, :cookies => { PVEAuthCookie: ticket } ).response.body
  response["data"].each  do |log|
    if quietRun == 0 && outputlevel == 1
      puts log["t"]
    end
    currentLog = log["n"].to_i
    # noinspection RubyUnusedLocalVariable
    if currentLog == 2
      imageLocation = log["t"].split('\'')[1]
      storageDirectory = imageLocation.split('/')[0...-1].join('/')
    end
    if log["t"] == "TASK OK"
      if quietRun == 0
        puts "New VM successfully created, image stored at #{imageLocation}"
      end
      loop = false
    end
  end
  sleep(0.2)
end

#mount vm image and change ip address
if configContents.key?("replacements")
  Net::SSH.start(sshHost, sshUsername) do |session|
    if quietRun == 0
      puts "connected to host"
    end

    #Mount disc
    session.exec! "modprobe nbd max_part=8"
    session.exec! "qemu-nbd --connect=/dev/nbd0 #{imageLocation}"
    session.exec! "vgchange -ay centos"
    session.exec! "mkdir #{storageDirectory}/disk"
    session.exec! "mount /dev/mapper/centos-root #{storageDirectory}/disk"
    replacements = configContents["replacements"]
    replacements.each do |file, parts|
      parts.each do |field, value|
          session.exec! "sed -i s/^#{field}.*/#{field}=#{value}/ #{storageDirectory}/disk#{file}"
          if quietRun == 0 && outputlevel == 1
            puts "replacing #{field}=#{value} in file #{storageDirectory}/disk#{file}"
          end
      end
    end

    # unmount disc
    session.exec! "umount #{storageDirectory}/disk"
    session.exec! "vgchange -an #{vgname}"
    session.exec! "qemu-nbd -d /dev/nbd0"
    session.exec! "rm -r #{storageDirectory}/disk"
    if quietRun == 0
      puts "disk unmounted"
    end
  end
end

#Set the configs
if configContents.key?("config")
  if quietRun == 0
    puts "Sending configs"
  end
  request = HTTParty.post("#{proxmoxUrl}/nodes/#{node}/qemu/#{nextVmid}/config",
                           :verify => false,
                           :cookies => { PVEAuthCookie: ticket },
                           :headers => headers,
                           :query => configContents["config"]
  )
  if request.code != 200
    puts 'Failed to set configs, code ' + request.code.to_s + " returned. Error details " + request.response.body
    exit(2)
  end
end

#Start the machine
if quietRun == 0
  puts "Starting Virtual Machine"
end
response = HTTParty.post("#{proxmoxUrl}/nodes/#{node}/qemu/#{nextVmid}/status/start", :verify => false, :cookies => { PVEAuthCookie: ticket }, :headers => headers )
response = JSON.parse response.response.body
taskId = response['data']
loop = 0
currentLog = 0
while loop < 100
  loop += 1
  response = JSON.parse HTTParty.get("#{proxmoxUrl}/nodes/#{node}/tasks/#{taskId}/log?start=#{currentLog}", :verify => false, :cookies => { PVEAuthCookie: ticket } ).response.body
  response["data"].each  do |log|
    if quietRun == 0 && outputlevel == 1
      puts log["t"]
    end
    currentLog = log["n"].to_i
    if log["t"] == "TASK OK"
      if quietRun == 0
        puts "New VM successfully started."
      end
      loop = 100
    end
  end
  sleep(0.2)
end

#Validating new instance is responding to ip
if quietRun == 0
  puts 'Checking host is up and responding to pings'
end
loop = 0
while loop < 110
  if loop == 100
    puts 'Host not up after 100 seconds, something probably went wrong.'
    exit(1)
  end
  check = Net::Ping::External.new(ips[0])
  if check.ping?
    if quietRun == 0
      puts 'Host is responding to pings. Instance created successfully.'
    end
    exit(0)
  else
    if quietRun == 0 && outputlevel == 1
      puts 'Not up yet, retrying'
    end
  end
  sleep(1)
end




