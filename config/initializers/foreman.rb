# stdlib dependencies
require 'English'

# Registries from app/registries/
# All are loaded and populated early but are loaded only once
require_dependency 'foreman/access_permissions'
require_dependency 'foreman/plugin'
require_dependency 'foreman/settings'

# Other internal dependencies, may be autoloaded
require 'net'
require 'foreman/provision'

Rails.application.config.before_initialize do
  # load topbar
  Menu::Loader.load
end

Foreman.settings.load_definitions

# We may be executing something like rake db:migrate:reset, which destroys this table
# only continue if the table exists
# TODO: remove this, and postpone loading values to to_prepare
if (Setting.table_exists? rescue(false))
  Setting.descendants.each(&:load_defaults)
  Foreman.settings.load_values
end

Foreman::Plugin.initialize_default_registries
Foreman::Plugin.medium_providers_registry.register MediumProviders::Default

Rails.application.config.after_initialize do
  Foreman::Plugin.registered_plugins.each do |_name, plugin|
    plugin.finalize_setup!
  end
end

Rails.application.config.to_prepare do
  # clear our users topbar cache
  # The users table may not be exist during initial migration of the database
  TopbarSweeper.expire_cache_all_users if (User.table_exists? rescue false)

  Foreman.settings.load if (Setting.table_exists? rescue(false)) && !Foreman.in_setup_db_rake?

  Facets.register(HostFacets::ReportedDataFacet, :reported_data) do
    api_view({ :list => 'api/v2/hosts/reported_data' })
    set_dependent_action :destroy
    template_compatibility_properties :cores, :virtual, :sockets, :ram, :uptime_seconds
  end
  Facets.register(HostFacets::InfrastructureFacet, :infrastructure_facet) do
    api_view({ :list => 'api/v2/hosts/infrastructure_facet' })
    set_dependent_action :destroy
  end

  Facets.register(ForemanRegister::RegistrationFacet, :registration_facet) do
    set_dependent_action :destroy
  end

  Foreman::Plugin.all.each do |plugin|
    plugin.to_prepare_callbacks.each(&:call)
  end

  Foreman::Plugin.graphql_types_registry.realise_extensions unless Foreman.in_setup_db_rake?

  Foreman.input_types_registry.register(InputType::UserInput)
  Foreman.input_types_registry.register(InputType::FactInput)
  Foreman.input_types_registry.register(InputType::VariableInput)

  ReportImporter.register_smart_proxy_feature("Puppet")
end
