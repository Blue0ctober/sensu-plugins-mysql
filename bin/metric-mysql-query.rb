#! /opt/sensu/embedded/bin/ruby
#
# metric-mysql-query
#
# DESCRIPTION:
#   This plugin collects metrics from the results of a mysql query. Can optionally
#   count the number of tuples (rows) returned by the query.
#
# OUTPUT:
#   metric data
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: mysql
#   gem: inifile
#
# USAGE:
#   metric-mysql-query.rb -u db_user -p db_pass -h db_host -d db -q 'select foo from bar'
#
# OPTIONAL:
#   metric-mysql-query.rb -i /path/to/my.cnf -h db_host -d db -q 'select foo from bar' 
#
#   MY.CNF INI FORMAT:
#   [client]
#   user=sensu
#   password="abcd1234"
#

require 'sensu-plugin/check/cli'
require 'mysql'
require 'inifile'


class CheckMySQL < Sensu::Plugin::Metric::CLI::Graphite
  option :user,
         description: 'MySQL User',
         short: '-u USER',
         long: '--user USER'

  option :password,
         description: 'MySQL Password',
         short: '-p PASS',
         long: '--password PASS'

  option :ini,
         description: 'My.cnf ini file',
         short: '-i',
         long: '--ini VALUE'

  option :hostname,
         description: 'Hostname to login to',
         short: '-h HOST',
         long: '--hostname HOST'
         defautl: 'localhost'

  option :database,
         description: 'Database schema to connect to',
         short: '-d DATABASE',
         long: '--database DATABASE',
         default: 'test'

  option :port,
         description: 'Port to connect to',
         short: '-P PORT',
         long: '--port PORT',
         default: '3306'

  option :socket,
         description: 'Socket to use',
         short: '-s SOCKET',
         long: '--socket SOCKET'

  option :query,
         description: 'query to run',
         short: '-q QUERY',
         long: '--query QUERY',
         required: true

  option :count_tuples,
         description: 'Count the number of tuples (rows) returned by the query',
         short: '-t',
         long: '--tuples',
         boolean: true,
         default: false

  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: 'mysql'


  def run
    if config[:ini]
      ini = IniFile.load(config[:ini])
      section = ini['client']
      db_user = section['user']
      db_pass = section['password']
    else
      db_user = config[:user]
      db_pass = config[:password]
    end

    begin
      con = Mysql.real_connect(config[:hostname], 
                              db_user, 
                              db_pass, 
                              config[:database],
                              config[:port].to_i,
                              config[:socket])
      res = con.exec(config[:query].to_s)
    rescue MySQL::Error => e
      return unknown "Unable to query. Database: #{:database}, Error:#{e.message}"
    end
    
    value = if config[:check_tuples]
              res.ntuples
            else
              res.first.values.first.to_f
            end

    output config[:schema], value
    ok
    end
  end
end
