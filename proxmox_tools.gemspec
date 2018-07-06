Gem::Specification.new do |s|
  s.name        = 'proxmox_tools'
  s.version     = '0.0.1'
  s.date        = '2018-06-25'
  s.summary     = "Proxmox Tools"
  s.description = "Tools that externalis the configuration and clones virtual machine in Proxmox, allowing virtual machines to be cloned with one command. These tools are Idempotent allowing them to be intergrated in Conguration mangers such as Chef or Ansible"
  s.authors     = ["Jonahtan Weems", "The Server Guys Ltd"]
  s.email       = 'jweems@serverdevs.com'
  s.files       = ["lib/proxmox_tools.rb"]
  s.homepage    =
      'http://rubygems.org/gems/proxmox_tools'
  s.license       = 'MIT'
end