
pg_version = node['postgresql']['version'] || '9.2'

node.override['postgresql']['server']['packages'] = ["postgresql-#{ pg_version}", "postgresql-#{ pg_version }-plv8", "postgresql-server-dev-#{ pg_version }"]

include_recipe 'postgresql::server'
include_recipe 'nodejs'

package "libv8-dev"

if node['pgrest']['dev']
  include_recipe 'git'
  git "/opt/pgrest" do
    repository node['pgrest']['git-repo']
    reference node['pgrest']['git-reference']
    action :sync
  end
  execute "install pgrest" do
    cwd "/opt/pgrest"
    command "npm i && npm run prepublish && npm link"
    action :nothing
    subscribes :run, resources(:git => "/opt/pgrest"), :immediately
  end

else
  execute "install pgrest" do
    command "npm i -g pgrest"
    not_if "test -e /usr/bin/pgrest"
  end
end

execute "create plv8 extension" do
    command "createdb kuansim; psql kuansim -c 'create extension plv8'"
    user 'postgres'
    not_if 'psql -l|grep kuansim', :user => 'postgres'
end

if node['pgrest']['sql']
  execute "import sql" do
    cwd "/opt/pgrest"
    command "su postgres -c \"psql kuansim -f #{ node['pgrest']['sql'] } \""
  end
end

# XXX: split to another recipe

script "install pgextwlist" do
  interpreter "bash"
  user "root"
  cwd "/root"
  code <<-EOH
    git clone git://github.com/dimitri/pgextwlist.git
    cd pgextwlist
    make
    mkdir /usr/lib/postgresql/#{ node['postgresql']['version'] }/lib/plugins
    cp -f ./pgextwlist.so /usr/lib/postgresql/#{ node['postgresql']['version'] }/lib/plugins/
  EOH
  not_if "test -e /usr/share/postgresql/#{ node['postgresql']['version'] }/lib/plugins/pgextwlist.so"
end

# XXX these needs to be set after pgextwlist is installed
#node.override['postgresql']['config']['local_preload_libraries'] = 'pgextwlist.so'
#node.override['postgresql']['config']['extwlist.extensions'] = 'plv8'
