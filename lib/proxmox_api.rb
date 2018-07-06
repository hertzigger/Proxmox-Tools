#!/usr/bin/env ruby

require 'httparty'
require 'json'
require 'cgi'

class ProxmoxApi
  @base_address
  @username
  @password
  @verify
  @authenticated = false
  @ticket
  @headers

  def initialize(address, port, version, type, verify, username, password)
    @base_address = "https://#{address}:#{port}/#{version}/#{type}"
    @username = username
    @password = password
    @verify = verify
  end

  def do_authentication
    response = HTTParty.post("#{@base_address}/access/ticket?username=#{@username}@pam&password=#{@password}", :verify => @verify )
    if response.code == 401
      puts "Authenication Failed, please check username and password. exiting"
      exit(1)
      return false;
    end
    if response.code != 200
      puts "Failed login to api. error code " + response.code
      return false
    end
    data = JSON.parse(response.response.body)["data"]
    @headers = {
        "CSRFPreventionToken" => data['CSRFPreventionToken']
    }
    @ticket = data['ticket']
    @authenticated = true;
  end

  def authenticated
    unless @authenticated
      do_authentication
    end
  end

  def next_vmid
    authenticated
    response = JSON.parse HTTParty.get("#{@base_address}/cluster/nextid", :verify => @verify, :cookies => { PVEAuthCookie: @ticket } ).response.body
    response['data']
  end

  def clone_vm(node, vmid, name, description, storage, format, full, ips)
    authenticated
    nvmid = next_vmid
    url = "#{@base_address}/nodes/#{node}/qemu/#{vmid}/clone?newid=#{nvmid}"
    if name != ''
      url += '&name=' + CGI.escape(name)
    end
    if description != ''
      url += '&description=' + CGI.escape(description)
      url += CGI.escape("\nIP Addresses")
      ips.each do |ip|
        url += CGI.escape("\n" + ip)
      end
    end
    if storage != ''
      url += '&storage=' + CGI.escape(storage)
    end
    if format != ''
      url += '&format=' + CGI.escape(format)
    end
    if full
      url += '&full=1'
    end
    response = HTTParty.post(url, :verify => @verify, :cookies => { PVEAuthCookie: @ticket }, :headers => @headers )
    if response.code != 200
      puts 'Failed to clone VM, Response ' + response.code.to_s
      p response.body
      exit(2)
    end
    response = JSON.parse response.response.body
    clone_reponse = CloneResponse.new
    clone_reponse.vmid = nvmid
    clone_reponse.task_id = response['data']
    clone_reponse
  end

  def task_log (node, task_id, start)
    JSON.parse HTTParty.get("#{@base_address}/nodes/#{node}/tasks/#{task_id}/log?start=#{start}", :verify => @verify, :cookies => { PVEAuthCookie: @ticket } ).response.body
  end

  def update_vm_config (node, vmid, configs)
    request = HTTParty.post("#{@base_address}/nodes/#{node}/qemu/#{vmid}/config",
                            :verify => @verify,
                            :cookies => { PVEAuthCookie: @ticket },
                            :headers => @headers,
                            :query => configs
    )
    if request.code != 200
      puts 'Failed to set configs, code ' + request.code.to_s + " returned. Error details " + request.response.body
      exit(2)
    end
  end

  def start_vm (node, vmid)
    response = HTTParty.post("#{@base_address}/nodes/#{node}/qemu/#{vmid}/status/start", :verify => @verify, :cookies => { PVEAuthCookie: @ticket }, :headers => @headers )
    response = JSON.parse response.response.body
    response['data']
  end
end

class CloneResponse
  attr_accessor :task_id
  attr_accessor :vmid
end