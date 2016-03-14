#! /usr/bin/env ruby
#
#   metrics-mongodb.rb
#
# DESCRIPTION:
#
# OUTPUT:
#   metric data
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: mongo
#   gem: bson
#   gem: bson_ext
#
# USAGE:
#   #YELLOW
#
# NOTES:
#   Basics from github.com/mantree/mongodb-graphite-metrics
#
# LICENSE:
#   Copyright 2013 github.com/foomatty
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/metric/cli'
require 'mongo'
include Mongo

#
# Mongodb
#

class MongoDB < Sensu::Plugin::Metric::CLI::Graphite
  option :host,
         description: 'MongoDB host',
         long: '--host HOST',
         default: 'localhost'

  option :port,
         description: 'MongoDB port',
         long: '--port PORT',
         default: 27_017

  option :user,
         description: 'MongoDB user',
         long: '--user USER',
         default: nil

  option :password,
         description: 'MongoDB password',
         long: '--password PASSWORD',
         default: nil

  option :scheme,
         description: 'Metric naming scheme',
         long: '--scheme SCHEME',
         short: '-s SCHEME',
         default: "#{Socket.gethostname}.mongodb"

  option :password,
         description: 'MongoDB password',
         long: '--password PASSWORD',
         default: nil

  option :debug,
         description: 'Enable debug',
         long: '--debug',
         default: false

  def get_mongo_doc(command)
    rs = @db.command(command)
    unless rs.successful?
      return nil
    end
    rs.documents[0]
  end

  # connects to mongo and sets @db, works with MongoClient < 2.0.0
  def connect_mongo_db(host, port, db_name, db_user, db_password)
    if Gem.loaded_specs['mongo'].version < Gem::Version.new('2.0.0')
      mongo_client = MongoClient.new(host, port)
      @db = mongo_client.db(db_name)
      @db.authenticate(db_user, db_password) unless db_user.nil?
    else
      address_str = "#{host}:#{port}"
      client_opts = {}
      client_opts[:database] = db_name
      unless db_user.nil?
        client_opts[:user] = db_user
        client_opts[:password] = db_password
      end
      mongo_client = Mongo::Client.new([address_str], client_opts)
      @db = mongo_client.database
    end
  end

  def run
    Mongo::Logger.logger.level = Logger::FATAL
    @debug = config[:debug]
    if @debug
      Mongo::Logger.logger.level = Logger::DEBUG
      config_debug = config.clone
      config_debug[:password] = '***'
      puts 'arguments:' + config_debug.inspect
    end
    host = config[:host]
    port = config[:port]
    db_name = 'admin'
    db_user = config[:user]
    db_password = config[:password]

    connect_mongo_db(host, port, db_name, db_user, db_password)

    _result = false
    # check if master
    begin
      @is_master = get_mongo_doc('isMaster' => 1)
      unless @is_master.nil?
        _result = @is_master['ok'] == 1
      end
    rescue StandardError => e
      if @debug
        puts 'Error checking isMaster:' + e.message
        puts e.backtrace.inspect
      end
      exit(1)
    end

    # get the metrics
    begin
      metrics = {}
      server_status = get_mongo_doc('serverStatus' => 1)
      if !server_status.nil? && server_status['ok'] == 1
        metrics.update(gather_replication_metrics(server_status))
        timestamp = Time.now.to_i
        metrics.each do |k, v|
          output [config[:scheme], k].join('.'), v, timestamp
        end
      end
    rescue StandardError => e
      if @debug
        puts 'Error checking serverStatus:' + e.message
        puts e.backtrace.inspect
      end
      exit(2)
    end

    # done!
    ok
  end

  def gather_replication_metrics(server_status)
    mongo_version = server_status['version'].gsub(/[^0-9\.]/i, '') # Handle versions like "2.6.11-pre" etc
    server_metrics = {}

    server_metrics['lock.ratio'] = sprintf('%.5f', server_status['globalLock']['ratio']).to_s unless server_status['globalLock']['ratio'].nil?

    server_metrics['lock.queue.total'] = server_status['globalLock']['currentQueue']['total']
    server_metrics['lock.queue.readers'] = server_status['globalLock']['currentQueue']['readers']
    server_metrics['lock.queue.writers'] = server_status['globalLock']['currentQueue']['writers']

    server_metrics['connections.current'] = server_status['connections']['current']
    server_metrics['connections.available'] = server_status['connections']['available']

    if Gem::Version.new(mongo_version) < Gem::Version.new('3.0.0')
      if server_status['indexCounters']['btree'].nil?
        server_metrics['indexes.missRatio'] = sprintf('%.5f', server_status['indexCounters']['missRatio']).to_s
        server_metrics['indexes.hits'] = server_status['indexCounters']['hits']
        server_metrics['indexes.misses'] = server_status['indexCounters']['misses']
      else
        server_metrics['indexes.missRatio'] = sprintf('%.5f', server_status['indexCounters']['btree']['missRatio']).to_s
        server_metrics['indexes.hits'] = server_status['indexCounters']['btree']['hits']
        server_metrics['indexes.misses'] = server_status['indexCounters']['btree']['misses']
      end
    end

    server_metrics['cursors.open'] = server_status['metrics']['cursor']['open']['total']
    server_metrics['cursors.timedOut'] = server_status['metrics']['cursor']['timedOut']

    server_metrics['mem.residentMb'] = server_status['mem']['resident']
    server_metrics['mem.virtualMb'] = server_status['mem']['virtual']
    server_metrics['mem.mapped'] = server_status['mem']['mapped']
    server_metrics['mem.pageFaults'] = server_status['extra_info']['page_faults']

    server_metrics['asserts.warnings'] = server_status['asserts']['warning']
    server_metrics['asserts.errors'] = server_status['asserts']['msg']
    server_metrics
  end
end
