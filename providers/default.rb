include Chef::Mixin::ShellOut

# rubocop:disable Metrics/AbcSize
def load_current_resource
  @zone = Chef::Resource::Zone.new(new_resource.name)
  @zone.name(new_resource.name)
  @zone.clone(new_resource.clone)
  @managed_props = %w(path autoboot limitpriv iptype)
  @special_props = %w(dataset inherit-pkg-dir net fs)

  @zone.password(new_resource.password)
  @zone.use_sysidcfg(new_resource.use_sysidcfg)
  @zone.sysidcfg_template(new_resource.sysidcfg_template)
  @zone.copy_sshd_config(new_resource.copy_sshd_config)

  @zone.status(status?)
  @zone.state(state?)

  @zone.info(info?)
  @zone.current_props(current_props?)
  @zone.desired_props(desired_props?)
end
# rubocop:enable Metrics/AbcSize

action :configure do # ~FC017
  do_create unless created?
  do_configure
end

action :install do # ~FC017
  action_configure
  do_install unless installed?

  if @zone.use_sysidcfg
    zone = @zone
    template "#{@zone.desired_props['zonepath']}/root/etc/sysidcfg" do
      source zone.sysidcfg_template
      variables(zone: zone)
    end
  end
end

action :start do # ~FC017
  action_install
  do_boot unless running?
end

action :delete do # ~FC017
  action_stop
  do_delete if created?
end

action :stop do # ~FC017
  do_halt if running?
end

action :uninstall do # ~FC017
  action_stop
  do_uninstall if installed?
end

private

def created?
  @zone.status.exitstatus.zero?
end

def state?
  @zone.status.stdout.split(':')[2]
end

def status?
  shell_out("zoneadm -z #{@zone.name} list -p")
end

def installed?
  @zone.state == 'installed' || @zone.state == 'ready' || @zone.state == 'running'
end

def running?
  @zone.state == 'running'
end

def info?
  shell_out("zonecfg -z #{@zone.name} info")
end

# rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/AbcSize
def current_props?
  prop_hash = {}
  header = ''
  addr = ''
  @zone.info.stdout.split('\n').each do |line|
    settings = line.split(/: ?/)
    if @special_props.include?(settings[0])
      header = settings[0]
      prop_hash[header] ||= []
    else
      second_level = settings[0].split('\t')
      if second_level[0] == ''
        # special case for network settings.
        # build them into the format we use: address:physical(:defrouter)
        if header == 'net'
          case second_level[1]
          when 'address'
            addr = settings[1]
          when 'physical'
            addr += ":#{settings[1]}"
          when 'defrouter'
            addr += ":#{settings[1]}"
            prop_hash[header].push(addr)
          when 'defrouter not specified'
            prop_hash[header].push(addr)
          end
        # Special case for fs settings since we only care about mount point
        elsif header == 'fs'
          prop_hash[header].push(settings[1]) if second_level[1] == 'dir'
        else
          prop_hash[header].push(settings[1])
        end
      else
        prop_hash[second_level[0]] = settings[1]
      end
    end
  end

  # override nil to be an empty array
  @special_props.each do |prop|
    prop_hash[prop] = [] if prop_hash[prop].nil?
  end

  prop_hash
end
# rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/AbcSize

# rubocop:disable Metrics/AbcSize
def desired_props?
  prop_hash = {}

  @managed_props.each do |prop|
    prop_name = prop
    case prop
    when 'iptype'
      prop_name = 'ip-type'
    when 'path'
      prop_name = 'zonepath'
    end
    prop_hash[prop_name] = new_resource.send(prop)
  end

  prop_hash['dataset'] = new_resource.send('datasets').sort
  prop_hash['inherit-pkg-dir'] = new_resource.send('inherits').sort
  prop_hash['net'] = new_resource.send('nets').sort
  prop_hash['fs'] = new_resource.send('loopbacks').sort

  prop_hash
end
# rubocop:enable Metrics/AbcSize

# rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/AbcSize
def do_configure
  # check and set each of the properties we manage

  @managed_props.each do |prop|
    next if @zone.current_props[prop] == @zone.desired_props[prop]
    Chef::Log.info("Setting #{prop} to #{@zone.desired_props[prop]} for zone #{@zone.name}")
    shell_out!("zonecfg -z  #{@zone.name} \"set #{prop}=#{@zone.desired_props[prop]}\"")
    new_resource.updated_by_last_action(true)
  end

  name_string = ''
  # rubocop:disable Style/Next
  @special_props.each do |prop|
    case prop
    when 'inherit-pkg-dir'
      name_string = 'dir'
    when 'dataset'
      name_string = 'name'
    when 'net'
      name_string = 'address'
    when 'fs'
      name_string = 'dir'
    end
    unless @zone.current_props[prop].sort == @zone.desired_props[prop]
      # values to be removed
      (@zone.current_props[prop] - @zone.desired_props[prop]).each do |value|
        Chef::Log.info("Removing #{prop} #{value} from zone #{@zone.name}")
        if prop == 'net'
          net_array = value.split(':')
          shell_out!("zonecfg -z #{@zone.name} \"remove #{prop} #{name_string}=#{net_array[0]}\"")
        else
          shell_out!("zonecfg -z #{@zone.name} \"remove #{prop} #{name_string}=#{value}\"")
        end
        new_resource.updated_by_last_action(true)
      end
      # values to be added
      (@zone.desired_props[prop] - @zone.current_props[prop]).each do |value|
        Chef::Log.info("Adding #{prop} #{value} to zone #{@zone.name}")
        if prop == 'net'
          net_array = value.split(':')
          shell_out!("zonecfg -z  #{@zone.name} \"add #{prop}; set #{name_string}=#{net_array[0]};set physical=#{net_array[1]};#{net_array[2].nil? ? '' : 'set defrouter=' + net_array[2] + ';'}end\"")
        elsif prop == 'fs'
          shell_out!("zonecfg -z  #{@zone.name} \"add #{prop}; set #{name_string}=#{value}; set special=#{value}; set type=lofs; add options [ro,nodevices]; end\"")
        else
          shell_out!("zonecfg -z  #{@zone.name} \"add #{prop}; set #{name_string}=#{value};end\"")
        end
        new_resource.updated_by_last_action(true)
      end
    end
  end
  # rubocop:enable Style/Next
end
# rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/AbcSize

def do_create
  Chef::Log.info("Configuring zone #{@zone.name}")
  shell_out!("zonecfg -z #{@zone.name} \"create;set zonepath=#{@zone.desired_props['zonepath']};commit\"")
  new_resource.updated_by_last_action(true)

  # update properties for new zone
  @zone.info(info?)
  @zone.current_props(current_props?)
end

# rubocop:disable Metrics/AbcSize
def do_install
  if @zone.clone.nil?
    Chef::Log.info("Installing zone #{@zone.name}")
    shell_out!("zoneadm -z #{@zone.name} install")
    new_resource.updated_by_last_action(true)
  else
    Chef::Log.info("Cloning zone #{@zone.name} from #{@zone.clone}")
    shell_out!("zoneadm -z #{@zone.name} clone #{@zone.clone}")
    new_resource.updated_by_last_action(true)
  end

  execute "cp /etc/ssh/sshd_config #{@zone.desired_props['zonepath']}/root/etc/ssh/sshd_config" if @zone.copy_sshd_config
end
# rubocop:enable Metrics/AbcSize

def do_boot
  Chef::Log.info("Booting zone #{@zone.name}")
  shell_out!("zoneadm -z #{@zone.name} boot")
  new_resource.updated_by_last_action(true)
end

def do_delete
  Chef::Log.info("Deleting zone #{@zone.name}")
  shell_out!("zonecfg -z #{@zone.name} delete -F")
  new_resource.updated_by_last_action(true)
end

def do_halt
  Chef::Log.info("Halting zone #{@zone.name}")
  shell_out!("zoneadm -z #{@zone.name} halt")
  new_resource.updated_by_last_action(true)
end

def do_uninstall
  Chef::Log.info("Uninstalling zone #{@zone.name}")
  shell_out!("zoneadm -z #{@zone.name} uninstall -F")
  new_resource.updated_by_last_action(true)
end
