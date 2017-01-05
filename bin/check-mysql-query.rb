#! /opt/sensu/embedded/bin/ruby
#
# check-mysql-query
#
# DESCRIPTION:
#   This plugin queries a MySQL database. It alerts when the numeric result hits
#   a threshold set by the warning or critical flag. Optionally, you can alert
#   on the number of tuples (rows) returned by the query.
#
# OUTPUT:
#   plain-text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: mysql
#   gem: inifile
#   gem: dentaku
#
# USAGE:
#   check-mysql-query.rb -u db_user -p db_pass -h db_host -d db -q 'select foo from bar' -w 'value > 5' -c 'value > 10'
#
# OPTIONAL:
#   check-mysql-query.rb -i /path/to/my.cnf -h db_host -d db -q 'select foo from bar' -w 'value > 5' -c 'value > 10' 
#
#   MY.CNF INI FORMAT:
#   [client]
#   user=sensu
#   password="abcd1234"
#

require 'sensu-plugin/check/cli'
require 'mysql'
require 'inifile'
require 'dentaku'


class CheckMySQL < Sensu::Plugin::Check::CLI
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
         default: 'localhost'

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

  option :check_tuples,
         description: 'Check against the number of tuples (rows) returned by the query',
         short: '-t',
         long: '--tuples',
         boolean: true,
         default: false

  option :warning,
         description: 'Warning threshold expression',
         short: '-w WARNING',
         long: '--warning WARNING',
         required: true

  option :critical,
         description: 'Critical threshold expression',
         short: '-c CRITICAL',
         long: '--critical CRITICAL',
         required: true


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
      unknown "Unable to query. Database: #{:database} Query: #{:query}, Error:#{e.message}"
    end
    
    value = if config[:check_tuples]
              res.ntuples
            else
              res.first.values.first.to_f
            end

    calc = Dentaku::Calculator.new
    if config[:critical] && calc.evaluate(config[:critical], value: value)
      critical "Results: #{res.values}"
    elsif config[:warning] && calc.evaluate(config[:warning], value: value)
      warning "Results: #{res.values}"
    else
      ok "Query OK, Results: #{res.values}"
    end
  end
end
