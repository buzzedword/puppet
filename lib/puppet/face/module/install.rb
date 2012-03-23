# encoding: UTF-8

Puppet::Face.define(:module, '1.0.0') do
  action(:install) do
    summary "Install a module from a repository or release archive."
    description <<-EOT
      Installs a module from the Puppet Forge, from a release archive file
      on-disk, or from a private Forge-like repository.

      The specified module will be installed into the directory
      specified with the --target-dir option, which defaults to
      #{Puppet.settings[:modulepath].split(File::PATH_SEPARATOR).first}.
    EOT

    returns "Pathname object representing the path to the installed module."

    examples <<-EOT
      Install a module:

      $ puppet module install puppetlabs-vcsrepo
      Preparing to install into /etc/puppet/modules ...
      Downloading from http://forge.puppetlabs.com ...
      Installing -- do not interrupt ...
      /etc/puppet/modules
      └── puppetlabs-vcsrepo (v0.0.4)

      Install a module to a specific environment:

      $ puppet module install puppetlabs-vcsrepo --environment development
      Preparing to install into /etc/puppet/environments/development/modules ...
      Downloading from http://forge.puppetlabs.com ...
      Installing -- do not interrupt ...
      /etc/puppet/environments/development/modules
      └── puppetlabs-vcsrepo (v0.0.4)

      Install a specific module version:

      $ puppet module install puppetlabs-vcsrepo -v 0.0.4
      Preparing to install into /etc/puppet/modules ...
      Downloading from http://forge.puppetlabs.com ...
      Installing -- do not interrupt ...
      /etc/puppet/modules
      └── puppetlabs-vcsrepo (v0.0.4)

      Install a module into a specific directory:

      $ puppet module install puppetlabs-vcsrepo --target-dir=/usr/share/puppet/modules
      Preparing to install into /usr/share/puppet/modules ...
      Downloading from http://forge.puppetlabs.com ...
      Installing -- do not interrupt ...
      /usr/share/puppet/modules
      └── puppetlabs-vcsrepo (v0.0.4)

      Install a module into a specific directory and check for dependencies in other directories:

      $ puppet module install puppetlabs-vcsrepo --target-dir=/usr/share/puppet/modules --modulepath /etc/puppet/modules
      Preparing to install into /usr/share/puppet/modules ...
      Downloading from http://forge.puppetlabs.com ...
      Installing -- do not interrupt ...
      /usr/share/puppet/modules
      └── puppetlabs-vcsrepo (v0.0.4)

      Install a module from a release archive:

      $ puppet module install puppetlabs-vcsrepo-0.0.4.tar.gz
      Preparing to install into /etc/puppet/modules ...
      Downloading from http://forge.puppetlabs.com ...
      Installing -- do not interrupt ...
      /etc/puppet/modules
      └── puppetlabs-vcsrepo (v0.0.4)

      Install a module from a release archive and ignore dependencies:

      $ puppet module install puppetlabs-vcsrepo-0.0.4.tar.gz --ignore-dependencies
      Preparing to install into /etc/puppet/modules ...
      Installing -- do not interrupt ...
      /etc/puppet/modules
      └── puppetlabs-vcsrepo (v0.0.4)

    EOT

    arguments "<name>"

    option "--force", "-f" do
      summary "Force overwrite of existing module, if any."
      description <<-EOT
        Force overwrite of existing module, if any.
      EOT
    end

    option "--target-dir DIR", "-i DIR" do
      summary "The directory into which modules are installed."
      description <<-EOT
        The directory into which modules are installed, defaults to the first
        directory in the modulepath.  Setting just the dir option sets the
        modulepath as well.  If you want install to check for dependencies in
        other paths, also give the modulepath option.
      EOT
    end

    option "--ignore-dependencies" do
      summary "Do not attempt to install dependencies"
      description <<-EOT
        Do not attempt to install dependencies
      EOT
    end

    option "--modulepath MODULEPATH" do
      default_to { Puppet.settings[:modulepath] }
      summary "Which directories to look for modules in"
      description <<-EOT
        The directory into which modules are installed; defaults to the first
        directory in the modulepath.  If the dir option is also given, it is
        prepended to the modulepath.
      EOT
    end

    option "--version VER", "-v VER" do
      summary "Module version to install."
      description <<-EOT
        Module version to install; can be an exact version or a requirement string,
        eg '>= 1.0.3'. Defaults to latest version.
      EOT
    end

    option "--environment NAME" do
      default_to { "production" }
      summary "The target environment to install modules into."
      description <<-EOT
        The target environment to install modules into.
      EOT
    end

    when_invoked do |name, options|
      sep = File::PATH_SEPARATOR
      if options[:target_dir]
        options[:modulepath] = "#{options[:target_dir]}#{sep}#{options[:modulepath]}"
      end

      Puppet.settings[:modulepath] = options[:modulepath]
      options[:target_dir] = Puppet.settings[:modulepath].split(sep).first

      Puppet.notice "Preparing to install into #{options[:target_dir]} ..."
      Puppet::Module::Tool::Applications::Installer.run(name, options)
    end

    when_rendering :console do |return_value, name, options|
      if return_value[:result] == :failure
        Puppet.err(return_value[:error][:multiline])
        exit 1
      else
        tree = format_tree(return_value[:installed_modules], return_value[:install_dir])
        return_value[:install_dir] + "\n" +
        Puppet::Module::Tool.build_tree(tree)
      end
    end
  end
end

def format_tree(mods, dir)
  mods.each do |mod|
    version_string = mod[:version][:vstring].sub(/^(?!v)/, 'v')

    if mod[:action] == :upgrade
      previous_version = mod[:previous_version].sub(/^(?!v)/, 'v')
      version_string = "#{previous_version} -> #{version_string}"
    end

    mod[:text] = "#{mod[:module]} (#{version_string})"
    mod[:text] += " [#{mod[:path]}]" unless mod[:path] == dir
    format_tree(mod[:dependencies], dir)
  end
end
