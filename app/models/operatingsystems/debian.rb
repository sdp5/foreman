class Debian < Operatingsystem
  PXEFILES = {:kernel => "linux", :initrd => "initrd.gz"}

  def pxedir(medium_provider = nil)
    # support ubuntu focal(20), which moved pxe files to legacy_image
    if (guess_os == 'ubuntu' && major.to_i >= 20)
      'dists/$release/main/installer-$arch/current/legacy-images/netboot/' + guess_os + '-installer/$arch'
    else
      'dists/$release/main/installer-$arch/current/images/netboot/' + guess_os + '-installer/$arch'
    end
  end

  def preseed_server(medium_provider)
    medium_provider.medium_uri.select(:host, :port).compact.join(':')
  end

  def preseed_path(medium_provider)
    medium_provider.medium_uri.select(:path, :query).compact.join('?')
  end

  def boot_file_sources(medium_provider, &block)
    super do |vars|
      vars = yield(vars) if block_given?

      transform_vars(vars)
    end
  end

  def available_loaders
    self.class.all_loaders
  end

  def pxe_type
    "preseed"
  end

  # Does this OS family use release_name in its naming scheme
  def use_release_name?
    true
  end

  # Helper text shown next to release name (do not use i18n)
  def release_name_help
    'bullseye, focal, buster, bionic, stretch, xenial...'
  end

  def display_family
    "Debian"
  end

  def shorten_description(description)
    return "" if description.blank?
    s = description.dup
    s.gsub!('GNU/Linux', '')
    s.gsub!(/\(.+?\)/, '')
    s.squeeze! " "
    s.strip!
    s += '.' + minor unless minor.blank? || s.include?('.')
    s.presence || description
  end

  def pxe_file_names(medium_provider)
    if (guess_os == 'ubuntu' && (major.to_i > 20 || major.to_i == 20 && minor.to_i >= 3))
      {
        kernel: 'vmlinuz',
        initrd: 'initrd',
      }
    else
      super
    end
  end

  private

  # tries to guess if this an ubuntu or a debian os
  def guess_os
    (name =~ /ubuntu/i) ? "ubuntu" : "debian"
  end

  def transform_vars(vars)
    vars[:arch] = vars[:arch].sub('x86_64', 'amd64')
    vars[:arch] = vars[:arch].sub('aarch64', 'arm64')
  end
end
