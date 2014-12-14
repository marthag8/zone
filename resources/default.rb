actions :configure, :delete, :install, :start, :stop, :uninstall

attribute :name, :kind_of => String
attribute :clone, :kind_of => String, :default => nil
attribute :path, :kind_of => String, :required => true
attribute :autoboot, :kind_of => String, :equal_to => [ "true", "false" ], :default => "true"
attribute :limitpriv, :kind_of => String, :default => nil
attribute :iptype, :kind_of => String, :equal_to => [ "shared", "exclusive"], :default => "shared"
attribute :nets, :kind_of => Array, :default => []
attribute :datasets, :kind_of => Array, :default => []
attribute :loopbacks, :kind_of => Array, :default => []
attribute :inherits, :kind_of => Array, :default => [ "/lib", "/platform", "/sbin", "/usr" ]
attribute :password, :kind_of => String
attribute :use_sysidcfg, :kind_of => [TrueClass, FalseClass], :default => true
attribute :sysidcfg_template, :kind_of => String, :default => "sysidcfg.erb"
attribute :copy_sshd_config, :kind_of => [TrueClass, FalseClass], :default => true

attribute :status, :kind_of => Mixlib::ShellOut, :default => nil
attribute :state, :kind_of => String, :default => nil

attribute :info, :kind_of => Mixlib::ShellOut, :default => nil
attribute :current_props, :kind_of => Hash, :default => nil
attribute :desired_props, :kind_of => Hash, :default => nil

def initialize(*args)
  super
  @action = :start
end
